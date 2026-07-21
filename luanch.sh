#!/bin/bash

set -e

echo "=========================================================="
echo "🚀 AxionOS hotdogb Auto-Build (with Wi-Fi auto-fix)"
echo "=========================================================="

MAIN_DIR="$(pwd)"

# ---------------------------------------------------------
# 1. Environment basics
# ---------------------------------------------------------

export USE_CCACHE=0
export NOMINATIVE_CCACHE=1
export SKIP_VENDORSETUP=true

export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=false
export TARGET_MULTISIM_CONFIG=dsds

echo "⚙️  Basic environment configured."

# ---------------------------------------------------------
# 2. Basic cleanup (lightweight)
# ---------------------------------------------------------

echo "🧹 Light cleanup (local_manifests only)..."
rm -rf .repo/local_manifests || true

# ---------------------------------------------------------
# 3. Repo init + local manifest + sync
# ---------------------------------------------------------

echo "📥 Running repo init for AxionOS..."
repo init -u https://github.com/AxionAOSP/android.git \
          -b lineage-23.2 \
          --git-lfs \
          --depth 1 || true

mkdir -p .repo/repo/hooks || true

echo "📥 Cloning local manifest for hotdogb..."
git clone https://github.com/jhaidh277/hotdogb_local_manifest \
          --depth 1 \
          -b axion \
          .repo/local_manifests || true

if [ -x /opt/crave/resync.sh ]; then
    echo "🔄 Syncing sources via Crave resync..."
    /opt/crave/resync.sh || echo "⚠️ Crave resync flagged an issue..."
fi

# ---------------------------------------------------------
# 4. Optional: fix duplicate prebuilt_ (safe)
# ---------------------------------------------------------

BP_FILE="vendor/oneplus/sm8150-common/Android.bp"
if [ -f "$BP_FILE" ]; then
    echo "🔍 Checking for duplicate prebuilt_ module definitions..."
    COUNT=$(grep -c 'name:[[:space:]]*"prebuilt_"' "$BP_FILE" || true)
    if [ "$COUNT" -gt 1 ]; then
        echo "⚠️ Found $COUNT occurrences of name: \"prebuilt_\". Applying safe rename on 2nd occurrence."
        awk '
            /name:[[:space:]]*"prebuilt_"/ {
                count++;
                if (count == 2) {
                    sub(/"prebuilt_"/, "\"prebuilt_duplicate_fixed_\"")
                }
            }
            { print }
        ' "$BP_FILE" > "${BP_FILE}.tmp" && mv "${BP_FILE}.tmp" "$BP_FILE"
    else
        echo "✅ No duplicate prebuilt_ modules detected."
    fi
fi

# ---------------------------------------------------------
# 5. Optional: KernelSU enable
# ---------------------------------------------------------

if [ -d "kernel/oneplus/sm8150" ]; then
    echo "🧬 Enabling KernelSU in all arm64 defconfigs..."
    cd kernel/oneplus/sm8150
    find arch/arm64/configs/ -type f -name "*defconfig" | while read -r defconfig; do
        sed -i '/CONFIG_KERNELSU/d' "$defconfig" || true
        echo "CONFIG_KERNELSU=y" >> "$defconfig"
    done
    cd "$MAIN_DIR"
fi

# ---------------------------------------------------------
# 6. Remove legacy vendorsetup.sh (if any)
# ---------------------------------------------------------

rm -f device/oneplus/hotdogb/vendorsetup.sh 2>/dev/null || true
rm -f device/oneplus/sm8150-common/vendorsetup.sh 2>/dev/null || true

# ---------------------------------------------------------
# 7. Source envsetup
# ---------------------------------------------------------

echo "📦 Sourcing build/envsetup.sh ..."
if ! source build/envsetup.sh; then
    echo "❌ Failed to source build/envsetup.sh"
    exit 1
fi

# ---------------------------------------------------------
# 8. GSI cleanup + Dolby privapp fix
# ---------------------------------------------------------

echo "🧹 Cleaning known problematic entries from GSI Android.bp (Calendar, if present)..."
if [ -f build/make/target/product/gsi/Android.bp ]; then
    sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp || true
fi

echo "🧼 Removing duplicate privapp-permissions-dolby.xml references..."
for f in \
    "device/oneplus/hotdogb/Android.mk" \
    "device/oneplus/hotdogb/device.mk" \
    "vendor/oneplus/hotdogb/hotdogb-vendor.mk" \
    "vendor/oneplus/sm8150-common/sm8150-common-vendor.mk"
do
    if [ -f "$f" ]; then
        sed -i '/privapp-permissions-dolby.xml/d' "$f" || true
        echo "Cleaned: $f"
    fi
done

# ---------------------------------------------------------
# 9. AccessibilityMenu proguard patch (Fixed)
# ---------------------------------------------------------

echo "🧩 Patching AccessibilityMenu proguard rules..."
AM_DIR="frameworks/base/packages/SystemUI/accessibility/accessibilitymenu"
if [ -d "$AM_DIR" ] && [ -f "$AM_DIR/Android.bp" ]; then
    python3 - <<'PY'
from pathlib import Path
bp = Path("frameworks/base/packages/SystemUI/accessibility/accessibilitymenu/Android.bp")
text = bp.read_text()

# Remove incorrect property if it was added previously
text = text.replace('    proguard_flags_files: ["proguard.flags"],\n', '')

# Correct way to add inline or file-based proguard flags in Soong Android.bp
target_str = '    optimize: {\n        enabled: true,\n        optimize: true,\n        shrink: true,\n        shrink_resources: true,\n        proguard_compatibility: false,\n    },'

replacement = target_str + '\n    proguard_flags: [\n        "-keep class com.android.systemui.accessibility.accessibilitymenu.** { *; }",\n        "-dontwarn com.android.systemui.accessibility.accessibilitymenu.**",\n    ],'

if target_str in text and 'proguard_flags' not in text:
    text = text.replace(target_str, replacement)
    bp.write_text(text)
    print("Successfully patched AccessibilityMenu Android.bp with proguard_flags.")
else:
    print("Proguard flags already present or target block not found.")
PY
fi
# ---------------------------------------------------------
# 10. Wi-Fi HAL auto-fix logic (minimal, board-aware)
# ---------------------------------------------------------

echo "📡 Running Wi-Fi HAL auto-check..."

BOARD_CONFIG="device/oneplus/sm8150-common/BoardConfigCommon.mk"
WIFI_BP="frameworks/opt/net/wifi/libwifi_hal/Android.bp"
HARDWARE_WLAN_DIRS=(
    "hardware/qcom-caf/wlan"
    "hardware/qcom/wlan"
    "hardware/qcom/wlan/legacy"
    "hardware/qcom/wlan/wcn6740"
    "hardware/qcom/wlan/wcn7760"
)

BOARD_WLAN_DEVICE_VALUE=""
if [ -f "$BOARD_CONFIG" ]; then
    BOARD_WLAN_DEVICE_VALUE=$(grep -E '^[[:space:]]*BOARD_WLAN_DEVICE[[:space:]]*:=' "$BOARD_CONFIG" | awk '{print $3}' || true)
fi

echo "ℹ️ BOARD_WLAN_DEVICE from BoardConfig: ${BOARD_WLAN_DEVICE_VALUE}"

if [ "$BOARD_WLAN_DEVICE_VALUE" = "qcwcn" ]; then
    echo "ℹ️ Detected qcwcn (Qualcomm) Wi-Fi device, checking libwifi-hal-qcom..."

    if [ -f "$WIFI_BP" ] && grep -q 'libwifi-hal-qcom' "$WIFI_BP"; then
        echo "✅ libwifi-hal-qcom is referenced in libwifi_hal/Android.bp"
    else
        echo "⚠️ libwifi-hal-qcom not referenced in libwifi_hal/Android.bp."
        echo "   [Auto-fix] Adding libwifi-hal-qcom to vendor impl defaults (if applicable)..."

        if [ -f "$WIFI_BP" ]; then
            python3 - << 'EOF'
import pathlib, re

bp = pathlib.Path("frameworks/opt/net/wifi/libwifi_hal/Android.bp")
text = bp.read_text()

pattern = r'(cc_defaults\s*\{\s*name:\s*"libwifi_hal_vendor_impl_defaults",[\s\S]*?shared_libs:\s*\[[\s\S]*?\])'
m = re.search(pattern, text)
if m:
    block = m.group(0)
    if 'libwifi-hal-qcom' not in block:
        new_block = block.replace('shared_libs: [', 'shared_libs: [\n        "libwifi-hal-qcom",')
        text = text.replace(block, new_block)
        bp.write_text(text)
        print("Added libwifi-hal-qcom to libwifi_hal_vendor_impl_defaults shared_libs.")
    else:
        print("libwifi-hal-qcom already present in vendor_impl_defaults.")
else:
    print("Could not find libwifi_hal_vendor_impl_defaults block; skipping.")
EOF
        fi
    fi

    FOUND_MODULE=0
    for d in "${HARDWARE_WLAN_DIRS[@]}"; do
        if [ -d "$d" ]; then
            if grep -Rqs 'name: "libwifi-hal-qcom"' "$d"; then
                echo "✅ Found libwifi-hal-qcom module definition in $d"
                FOUND_MODULE=1
                break
            fi
        fi
    done

    if [ "$FOUND_MODULE" -eq 0 ]; then
        echo "⚠️ Could NOT find any libwifi-hal-qcom module definition in hardware/qcom(-caf)/wlan dirs."
        echo "   👉 Build may still fail; please verify your hardware/qcom-caf/wlan repos and branches."
    fi
else
    echo "ℹ️ BOARD_WLAN_DEVICE is not qcwcn; skipping qcom-specific Wi-Fi auto-fix."
fi

# ---------------------------------------------------------
# 11. Build commands
# ---------------------------------------------------------

echo "🔑 Generating keys..."
gk -s || true

echo "🍽️ Lunch: axion hotdogb userdebug va"
axion hotdogb userdebug va

echo "🧼 Running installclean..."
make installclean || true

echo "🏗️ Starting AxionOS build..."
ax -br -j"$(nproc)"

echo "=========================================================="
echo "✅ Auto-build script finished (check above for any errors)."
echo "=========================================================="

# ---------------------------------------------------------
# 12. Telegram auto-upload
# ---------------------------------------------------------

TELEGRAM_BIN="/home/admin/.local/bin/telegram-upload"
CHAT_ID="@jihad099012"

OUT_DIR="out/target/product/hotdogb"
ZIP_FILE=$(ls -t ${OUT_DIR}/*.zip 2>/dev/null | head -n 1)

if [ -f "$ZIP_FILE" ]; then
    echo "ROM build successful! Starting automatic Telegram upload..."
    $TELEGRAM_BIN --to "$CHAT_ID" --caption "ROM Build Successful for OnePlus 7T! 🎉" "$ZIP_FILE"
    if [ $? -eq 0 ]; then
        echo "✅ Successfully uploaded to Telegram!"
    else
        echo "⚠️ Telegram upload failed!"
    fi
else
    echo "⚠️ Error: ROM zip file not found in $OUT_DIR!"
fi
