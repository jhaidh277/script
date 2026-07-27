#!/bin/bash

set -e

echo "=========================================================="
echo "🚀 AxionOS hotdogb Auto-Build (GMS)"
echo "=========================================================="

MAIN_DIR="$(pwd)"
KEY_DIR="$HOME/.android-certs"

echo "Cleaning workspace for hotdogb..."
rm -rf device/oneplus/hotdogb
rm -rf device/oneplus/sm8150-common
rm -rf vendor/oneplus/hotdogb
rm -rf vendor/oneplus/sm8150-common
rm -rf kernel/oneplus/sm8150
rm -rf hardware/dolby
rm -rf out/target/product/hotdogb

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

echo "⚙️ Basic environment configured."

# ---------------------------------------------------------
# 2. Basic cleanup
# ---------------------------------------------------------

echo "🧹 Cleaning local_manifests..."
rm -rf .repo/local_manifests || true

# ---------------------------------------------------------
# 3. Repo init + local manifest
# ---------------------------------------------------------

echo "📥 Initializing repo..."
repo init -u https://github.com/AxionAOSP/android.git \
    -b lineage-23.2 \
    --git-lfs \
    --depth 1 || true

mkdir -p .repo/repo/hooks || true

echo "📥 Cloning local manifest..."
git clone https://github.com/jhaidh277/hotdogb_local_manifest \
    --depth 1 \
    -b axion \
    .repo/local_manifests || true

if [ -x /opt/crave/resync.sh ]; then
    echo "🔄 Running Crave resync..."
    /opt/crave/resync.sh || echo "⚠️ Crave resync had an issue..."
fi

# ---------------------------------------------------------
# 4. Safe optional fix: duplicate prebuilt_
# ---------------------------------------------------------

BP_FILE="vendor/oneplus/sm8150-common/Android.bp"
if [ -f "$BP_FILE" ]; then
    COUNT=$(grep -c 'name:[[:space:]]*"prebuilt_"' "$BP_FILE" || true)
    if [ "$COUNT" -gt 1 ]; then
        echo "⚠️ Duplicate prebuilt_ found, applying safe rename..."
        awk '
            /name:[[:space:]]*"prebuilt_"/ {
                c++
                if (c == 2) sub(/"prebuilt_"/, "\"prebuilt_duplicate_fixed_\"")
            }
            { print }
        ' "$BP_FILE" > "${BP_FILE}.tmp" && mv "${BP_FILE}.tmp" "$BP_FILE"
    fi
fi

# ---------------------------------------------------------
# 5. Optional: KernelSU enable
# ---------------------------------------------------------

if [ -d "kernel/oneplus/sm8150" ]; then
    echo "🧬 Applying KernelSU to arm64 defconfigs..."
    cd kernel/oneplus/sm8150
    find arch/arm64/configs/ -type f -name "*defconfig" | while read -r defconfig; do
        sed -i '/CONFIG_KERNELSU/d' "$defconfig" || true
        echo "CONFIG_KERNELSU=y" >> "$defconfig"
    done
    cd "$MAIN_DIR"
fi

# ---------------------------------------------------------
# 6. Remove legacy vendorsetup
# ---------------------------------------------------------

rm -f device/oneplus/hotdogb/vendorsetup.sh 2>/dev/null || true
rm -f device/oneplus/sm8150-common/vendorsetup.sh 2>/dev/null || true

# ---------------------------------------------------------
# 7. Source envsetup
# ---------------------------------------------------------

echo "📦 Sourcing build/envsetup.sh..."
source build/envsetup.sh

# ---------------------------------------------------------
# 8. Small safe cleanups
# ---------------------------------------------------------

echo "🧹 Cleaning GSI Android.bp Calendar line if present..."
if [ -f build/make/target/product/gsi/Android.bp ]; then
    sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp || true
fi

echo "🧼 Cleaning privapp-permissions-dolby.xml references..."
for f in \
    "device/oneplus/hotdogb/Android.mk" \
    "device/oneplus/hotdogb/device.mk" \
    "vendor/oneplus/hotdogb/hotdogb-vendor.mk" \
    "vendor/oneplus/sm8150-common/sm8150-common-vendor.mk"
do
    [ -f "$f" ] && sed -i '/privapp-permissions-dolby.xml/d' "$f" || true
done

# ---------------------------------------------------------
# 9. Wi-Fi HAL auto-check
# ---------------------------------------------------------

echo "📡 Running Wi-Fi HAL auto-check..."

BOARD_CONFIG="device/oneplus/sm8150-common/BoardConfigCommon.mk"
WIFI_BP="frameworks/opt/net/wifi/libwifi_hal/Android.bp"

BOARD_WLAN_DEVICE_VALUE=""
if [ -f "$BOARD_CONFIG" ]; then
    BOARD_WLAN_DEVICE_VALUE=$(grep -E '^[[:space:]]*BOARD_WLAN_DEVICE[[:space:]]*:=' "$BOARD_CONFIG" | awk '{print $3}' || true)
fi

echo "ℹ️ BOARD_WLAN_DEVICE: ${BOARD_WLAN_DEVICE_VALUE}"

if [ "$BOARD_WLAN_DEVICE_VALUE" = "qcwcn" ]; then
    if [ -f "$WIFI_BP" ] && grep -q 'libwifi-hal-qcom' "$WIFI_BP"; then
        echo "✅ libwifi-hal-qcom already referenced."
    else
        echo "⚠️ libwifi-hal-qcom not referenced."
    fi
fi

# ---------------------------------------------------------
# 10. Key generation
# ---------------------------------------------------------

echo "🔑 Preparing key directory..."
mkdir -p "$KEY_DIR"
export ANDROID_CERTS="$KEY_DIR"

echo "🔑 Generating keys..."
subject='/C=US/ST=California/L=Los Angeles/O=AxionOS/OU=AxionOS/CN=AxionOS'

for x in releasekey platform shared media networkstack testkey bluetooth sdk_sandbox verifiedboot; do
    if [ ! -f "$KEY_DIR/$x.pk8" ] || [ ! -f "$KEY_DIR/$x.x509.pem" ]; then
        ./development/tools/make_key "$KEY_DIR/$x" "$subject"
    fi
done

# ---------------------------------------------------------
# 11. Build
# ---------------------------------------------------------

echo "🍽️ Configuring with axion helper..."
axion hotdogb userdebug gms

echo "🧼 installclean..."
make installclean || true

echo "🏗️ Building..."
m -j"$(nproc)"

echo "=========================================================="
echo "✅ Build script finished."
echo "=========================================================="

# ---------------------------------------------------------
# 12. Telegram upload
# ---------------------------------------------------------

TELEGRAM_BIN="/home/admin/.local/bin/telegram-upload"
CHAT_ID="@jihad099012"
OUT_DIR="out/target/product/hotdogb"
ZIP_FILE=$(ls -t ${OUT_DIR}/*.zip 2>/dev/null | head -n 1)

if [ -f "$ZIP_FILE" ]; then
    echo "📤 Uploading ROM..."
    "$TELEGRAM_BIN" --to "$CHAT_ID" --caption "ROM Build Successful for OnePlus 7T GMS! 🎉" "$ZIP_FILE" || true
else
    echo "⚠️ ROM zip not found in $OUT_DIR"
fi
