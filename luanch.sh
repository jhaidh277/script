#!/bin/bash

set -e

echo "=========================================================="
echo "🚀 AxionOS hotdogb Auto-Build (with Wi-Fi auto-fix)"
echo "=========================================================="

MAIN_DIR=$(pwd)

# ---------------------------------------------------------
# 1. Environment basics
# ---------------------------------------------------------

export USE_CCACHE=0
export NOMINATIVE_CCACHE=1
export SKIP_VENDORSETUP=true

export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=true
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
        echo "⚠️ Found $COUNT occurrences of name: "prebuilt_". Applying safe rename on 2nd occurrence."
        awk '
            /name:[[:space:]]*"prebuilt_"/ {
                count++;
                if (count == 2) {
                    sub(/"prebuilt_"/, ""prebuilt_duplicate_fixed_"")
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
# 8. Small GSI cleanup
# ---------------------------------------------------------

if [ -f build/make/target/product/gsi/Android.bp ]; then
    echo "🧹 Cleaning known problematic entries from GSI Android.bp (Calendar, if present)..."
    sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp || true
fi

# ---------------------------------------------------------
# 9. Wi-Fi HAL auto-fix logic (minimal, board-aware)
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

# Only try to auto-fix if BOARD_WLAN_DEVICE is qcwcn (qcom path)
if [ "$BOARD_WLAN_DEVICE_VALUE" = "qcwcn" ]; then
    echo "ℹ️ Detected qcwcn (Qualcomm) Wi-Fi device, checking libwifi-hal-qcom..."

    # 1) Check if libwifi-hal-qcom is referenced in Wi-Fi HAL Android.bp
    if [ -f "$WIFI_BP" ] && grep -q 'libwifi-hal-qcom' "$WIFI_BP"; then
        echo "✅ libwifi-hal-qcom is referenced in libwifi_hal/Android.bp"
    else
        echo "⚠️ libwifi-hal-qcom not referenced in libwifi_hal/Android.bp."
        echo "   [Auto-fix] Adding libwifi-hal-qcom to vendor impl defaults (if applicable)..."

        if [ -f "$WIFI_BP" ]; then
            # খুব টার্গেটেড patch: vendor_impl_defaults ব্লকে qcom HAL add করা
            python3 - << 'EOF'
import re, pathlib

bp = pathlib.Path("frameworks/opt/net/wifi/libwifi_hal/Android.bp")
text = bp.read_text()

pattern = r'(cc_defaults(
s*name:s*"libwifi_hal_vendor_impl_defaults",[sS]*?shared_libs:s*[[sS]*?])'
m = re.search(pattern, text)
if m:
    block = m.group(0)
    if 'libwifi-hal-qcom' not in block:
        new_block = block.replace('shared_libs: [', 'shared_libs: [
        "libwifi-hal-qcom",')
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

    # 2) Check for libwifi-hal-qcom module existence in hardware wlan dirs
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
# 10. Build commands
# ---------------------------------------------------------

echo "🔑 Generating keys..."
gk -s || true

echo "🍽️ Lunch: axion hotdogb userdebug gms"
axion hotdogb userdebug gms

echo "🧼 Running installclean..."
make installclean || true

echo "🏗️ Starting AxionOS build..."
ax -br -j$(nproc)

echo "=========================================================="
echo "✅ Auto-build script finished (check above for any errors)."
echo "=========================================================="
