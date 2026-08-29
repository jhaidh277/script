#!/bin/bash
set -e

echo "=========================================================="
echo "🚀 Building Project Infinity-X for Xiaomi Redmi Note 14 5G (beryl)"
echo "=========================================================="

MAIN_DIR=$(pwd)

# Local TimeZone Setup
sudo rm -f /etc/localtime
sudo ln -s /usr/share/zoneinfo/Asia/Dhaka /etc/localtime

export USE_CCACHE=0
export NOMINATIVE_CCACHE=1
export SKIP_VENDORSETUP=true

echo "🧹 Cleaning previous build directories..."
rm -rf .repo/local_manifests || true
rm -rf device/xiaomi/beryl vendor/xiaomi/beryl device/xiaomi/beryl-kernel hardware/xiaomi hardware/mediatek device/mediatek/sepolicy_vndr vendor/mediatek/ims packages/apps/RevampedFMRadio || true

echo "📥 Initializing repo for Project Infinity-X (Android 16)..."
repo init --depth=1 -u https://github.com/ProjectInfinity-X/manifest -b 16 --git-lfs --no-clone-bundle || true

echo "🔄 Syncing sources via Crave resync..."
/opt/crave/resync.sh || echo "⚠️ Resync flagged an issue, proceeding anyway..."

echo "📥 Cloning device trees, vendor, and hardware components..."
git clone --depth 1 -b inf https://github.com/jhaidh277/device_xiaomi_beryl.git device/xiaomi/beryl
git clone --depth 1 -b lineage-23.2-6.12 https://github.com/TracenPlayground/vendor_xiaomi_beryl.git vendor/xiaomi/beryl
git clone --depth 1 -b lineage-23.2-6.12 https://github.com/TracenPlayground/device_xiaomi_beryl-kernel.git device/xiaomi/beryl-kernel
git clone --depth 1 -b 16.2-rebase https://github.com/TracenPlayground/hardware_xiaomi.git hardware/xiaomi
git clone --depth 1 -b 16.2-rebase https://github.com/TracenPlayground/hardware_mediatek.git hardware/mediatek
git clone --depth 1 -b 16.2-rebase https://github.com/TracenPlayground/device_mediatek_sepolicy_vndr.git device/mediatek/sepolicy_vndr
git clone --depth 1 -b android-16-qpr2 https://github.com/techyminati/android_vendor_mediatek_ims.git vendor/mediatek/ims
git clone --depth 1 https://github.com/LineageOS/android_vendor_qcom_opensource_libvmmem.git vendor/qcom/opensource/libvmmem
git clone --depth 1 -b mtk https://github.com/TracenPlayground/packages_apps_RevampedFMRadio.git packages/apps/RevampedFMRadio

echo "🛡️ Applying SEPolicy and VINTF patches..."
echo 'type mitee_client_device, dev_type
type mitee_data_file, file_type, data_file_type
type proc_mitee_log, fs_type, proc_type
' >> device/xiaomi/beryl/sepolicy/vendor/tee.te || true

sed -i 's|</compatibility-matrix>|<hal format="aidl" optional="true">\n    <name>vendor.xiaomi.hardware.mfidoca</name>\n    <interface>\n        <name>IFidoService</name>\n        <instance>default</instance>\n    </interface>\n</hal>\n</compatibility-matrix>|' device/xiaomi/beryl/configs/vintf/framework_compatibility_matrix.xml || true

sed -i '29i TARGET_SUPPORTS_BLUR := true' device/xiaomi/beryl/lineage_beryl.mk || true

# Export Build Info
export BUILD_USERNAME=Jihad
export BUILD_HOSTNAME=crave

echo "📦 Sourcing build/envsetup.sh..."
source build/envsetup.sh

echo "🍽️ Lunching Project Infinity-X target for beryl..."
if lunch infinity_beryl-userdebug; then
    echo "✅ Lunched infinity_beryl-userdebug"
elif lunch lineage_beryl-userdebug; then
    echo "✅ Lunched lineage_beryl-userdebug"
elif lunch beryl-userdebug; then
    echo "✅ Lunched beryl-userdebug"
else
    echo "ERROR: All lunch targets failed. Aborting."
    exit 1
fi

echo "🧹 Running installclean..."
make installclean || true

echo "🏗️ Building Project Infinity-X ROM (m bacon)..."
m bacon

echo "=========================================================="
echo "✅ Build script finished. Processing Telegram upload..."
echo "=========================================================="

# Telegram Auto-Upload Configuration
TG_BOT_TOKEN="8758021238:AAG84uv-kXDC3dyddeYKOwIjKG7siBNWd-k"
TG_CHAT_ID="2020073876"

ZIP_FILE=$(find out/target/product/beryl -name "*.zip" | head -n 1)

if [ -f "$ZIP_FILE" ]; then
    echo "Uploading build to Telegram..."
    curl -F chat_id="$TG_CHAT_ID" \
         -F document=@"$ZIP_FILE" \
         -F caption="✨ Project Infinity-X Build Completed Successfully! ✨
📱 Device: Xiaomi Redmi Note 14 5G (beryl)
📅 Date: $(date +%d.%m.%Y)" \
         https://api.telegram.org/bot$TG_BOT_TOKEN/sendDocument
    echo "Telegram upload finished!"
else
    echo "Error: Build zip file not found in out/target/product/beryl/"
fi
