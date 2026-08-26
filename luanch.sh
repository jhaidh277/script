#!/bin/bash
set -e

echo "=========================================================="
echo "🚀 Ultimate Permanent Fix Build Script for Project Infinity-X - OnePlus 7T (hotdogb)"
echo "=========================================================="

MAIN_DIR=$(pwd)

# 🕒 Local TimeZone Setup (Resetting existing symlink safely)
sudo rm -f /etc/localtime
sudo ln -s /usr/share/zoneinfo/Asia/Dhaka /etc/localtime

export USE_CCACHE=0
export NOMINATIVE_CCACHE=1
export SKIP_VENDORSETUP=true

echo "🧹 Force cleaning corrupted directories..."
rm -rf .repo/local_manifests || true
rm -rf device/oneplus/hotdogb device/oneplus/sm8150-common vendor/oneplus/hotdogb vendor/oneplus/sm8150-common kernel/oneplus/sm8150 hardware/oplus hardware/dolby || true

echo "📥 Initializing repo for Project Infinity-X..."
repo init --depth=1 -u https://github.com/ProjectInfinity-X/manifest -b 16 --git-lfs || true

echo "📥 Creating local manifest..."
mkdir -p .repo/local_manifests
cat << 'EOF' > .repo/local_manifests/roomservice.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <project name="jhaidh277/android_device_oneplus_hotdogb" path="device/oneplus/hotdogb" remote="github" revision="infinity" />
 <project name="jhaidh277/android_device_oneplus_sm8150-common" path="device/oneplus/sm8150-common" remote="github" revision="lineage-23.2" />
  <project name="jhaidh277/android_kernel_oneplus_sm8150" path="kernel/oneplus/sm8150" remote="github" revision="16.0" />
  <project path="vendor/oneplus/hotdogb" name="TheMuppets/proprietary_vendor_oneplus_hotdogb" remote="github" revision="lineage-23.2" />
  <project path="vendor/oneplus/sm8150-common" name="TheMuppets/proprietary_vendor_oneplus_sm8150-common" remote="github" revision="lineage-23.2" />
  <project path="hardware/oplus" name="LineageOS/android_hardware_oplus" remote="github" revision="lineage-23.2" />
</manifest>
EOF

echo "🔄 Syncing sources via Crave resync..."
/opt/crave/resync.sh || echo "⚠️ Crave resync flagged an issue, but proceeding anyway..."

# ============================================================
# 📥 SAFE DIRECT GIT CLONE: hardware/dolby (Must be after Crave Resync)
# ============================================================
echo "📥 Ensuring hardware_dolby_lunaris exists via Git clone..."
rm -rf hardware/dolby || true
git clone --depth=1 https://github.com/jhaidh277/hardware_dolby_lunaris.git -b 16 hardware/dolby

# ============================================================
# 🛡️ PERMANENT FIX: Remove conflicting Android.bp from vendor blobs
# ============================================================
echo "🛡️ Applying permanent fix for vendor soong_namespace errors..."
rm -f vendor/oneplus/hotdogb/Android.bp || true
rm -f vendor/oneplus/sm8150-common/Android.bp || true

# ============================================================
# 🩹 PERMANENT FIX: Remove cameraMDM from frameworks/av
# ============================================================
echo "🩹 Permanently clearing cameraMDM dependencies across frameworks/av..."
python3 -c "
import os
for root, dirs, files in os.walk('frameworks/av'):
    for file in files:
        if file == 'Android.bp':
            bp_path = os.path.join(root, file)
            try:
                with open(bp_path, 'r') as f:
                    content = f.read()
                if 'cameraMDM' in content or 'vendor.oplus.hardware' in content:
                    lines = content.split('\n')
                    new_lines = [line for line in lines if 'cameraMDM' not in line and 'vendor.oplus.hardware' not in line and 'opsm8150' not in line]
                    with open(bp_path, 'w') as f:
                        f.write('\n'.join(new_lines))
            except Exception:
                pass
" || true

# --------------------------------other fixes--------------------------------

# hardware/lineage/compat duplicate protobuf মডিউল ফিক্স
BP1="hardware/lineage/compat/Android.bp"
if [ -f "$BP1" ]; then
    echo "🩹 Fixing duplicate modules in $BP1..."
    sed -i '/prebuilt_libprotobuf-cpp-full-3.9.1-vendorcompat/,/^}/d' "$BP1" || true
    sed -i '/prebuilt_libprotobuf-cpp-lite-3.9.1-vendorcompat/,/^}/d' "$BP1" || true
    sed -i '/prebuilt_libprotobuf-cpp-full-21.12-vendorcompat/,/^}/d' "$BP1" || true
    sed -i '/prebuilt_libprotobuf-cpp-lite-21.12-vendorcompat/,/^}/d' "$BP1" || true
fi

# camera_helper visibility মিক্সিং এরর ফিক্স
BP2="device/oneplus/sm8150-common/camera_helper/Android.bp"
if [ -f "$BP2" ]; then
    echo "🩹 Fixing visibility conflict in $BP2..."
    sed -i '/visibility: \[/,/\],/d' "$BP2" || true
    if [ ! -f "device/oneplus/sm8150-common/camera_helper/CameraProviderExtension.cpp" ]; then
        touch device/oneplus/sm8150-common/camera_helper/CameraProviderExtension.cpp
    fi
fi

# GSI-তে libcameraservice_extension dependency রিমুভ
AV_BP="frameworks/av/services/camera/libcameraservice/Android.bp"
if [ -f "$AV_BP" ]; then
    echo "🩹 Removing GSI-incompatible camera extension dependency..."
    sed -i '/"libcameraservice_extension.opsm8150"/d' "$AV_BP" || true
    sed -i '/libcameraservice_extension.opsm8150/d' "$AV_BP" || true
fi

COMMON_BP_FILES=$(find device/oneplus/sm8150-common -name "Android.bp" -o -name "*.mk" 2>/dev/null || true)
for bp in $COMMON_BP_FILES; do
    if grep -q "libcameraservice_extension.opsm8150" "$bp"; then
        echo "🩹 Removing reference from $bp..."
        sed -i '/libcameraservice_extension.opsm8150/d' "$bp" || true
    fi
done

# ============================================================
# 🩹 CRITICAL FIX: Safe C++ Patch for CameraService.cpp
# ============================================================
CAMERA_SERVICE="frameworks/av/services/camera/libcameraservice/CameraService.cpp"
if [ -f "$CAMERA_SERVICE" ]; then
    echo "🩹 Safely patching CameraService.cpp to bypass OPlus/Vendor extension calls..."
    sed -i '/#include <vendor\/oplus\/hardware\/cameraMDM\/2.0\/IOPlusCameraMDM.h>/d' "$CAMERA_SERVICE" || true
    sed -i 's/.*gVendorCameraProviderService.*/\/\/ &/g' "$CAMERA_SERVICE" || true
    sed -i 's/.*OPlusCameraMDM.*/\/\/ &/g' "$CAMERA_SERVICE" || true
fi

# Missing hotdogb-vendor.mk ফিক্স
VENDOR_MAKEFILE="vendor/oneplus/hotdogb/hotdogb-vendor.mk"
if [ ! -f "$VENDOR_MAKEFILE" ] && [ -d "vendor/oneplus/hotdogb" ]; then
    echo "⚠️ WARNING: hotdogb-vendor.mk missing. Creating empty fallback."
    touch "$VENDOR_MAKEFILE"
fi

# system.prop injection
PROP_FILE="device/oneplus/hotdogb/system.prop"
if [ -f "$PROP_FILE" ]; then
    grep -q "ro.product.marketname" "$PROP_FILE" || echo "ro.product.marketname=OnePlus 7T" >> "$PROP_FILE"
    grep -q "ro.infinity.soc" "$PROP_FILE" || echo "ro.infinity.soc=Qualcomm Snapdragon 855+" >> "$PROP_FILE"
    grep -q "ro.infinity.camera" "$PROP_FILE" || echo "ro.infinity.camera=48 MP + 12 MP + 16 MP" >> "$PROP_FILE"
fi

# KernelSU
if [ -d "kernel/oneplus/sm8150" ]; then
    echo "🧬 Applying KernelSU..."
    cd kernel/oneplus/sm8150
    find arch/arm64/configs/ -type f -name "*defconfig" | while read -r defconfig; do
        sed -i '/CONFIG_KERNELSU/d' "$defconfig" || true
        echo "CONFIG_KERNELSU=y" >> "$defconfig"
    done
    cd "$MAIN_DIR"
fi

rm -f device/oneplus/hotdogb/vendorsetup.sh 2>/dev/null || true
rm -f device/oneplus/sm8150-common/vendorsetup.sh 2>/dev/null || true

# Export Build Info
export BUILD_USERNAME=Jihad
export BUILD_HOSTNAME=crave
echo "======= Export Done ======="

echo "📦 Sourcing build/envsetup.sh..."
source build/envsetup.sh

if [ -f build/make/target/product/gsi/Android.bp ]; then
    sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp || true
fi

echo "🍽️ Lunching Project Infinity-X target..."
if lunch infinity_hotdogb-userdebug; then
    echo "✅ Lunched infinity_hotdogb-userdebug"
elif lunch lineage_hotdogb-userdebug; then
    echo "✅ Lunched lineage_hotdogb-userdebug"
elif lunch hotdogb-userdebug; then
    echo "✅ Lunched hotdogb-userdebug"
else
    echo "ERROR: All lunch targets failed. Aborting."
    exit 1
fi

# ============================================================
# 🩹 FINAL CRITICAL PURGE: Post-Lunch Regex Clean for WfdCommon
# ============================================================
echo "🧹 Executing final regex purge of WfdCommon right before build..."
python3 -c "
import os, re
for root, dirs, files in os.walk('.'):
    for file in files:
        if file == 'Android.bp':
            bp_path = os.path.join(root, file)
            try:
                with open(bp_path, 'r') as f:
                    content = f.read()
                if 'WfdCommon' in content:
                    cleaned = re.sub(r'\"WfdCommon\",?\s*', '', content)
                    with open(bp_path, 'w') as f:
                        f.write(cleaned)
                    print(f'Purged WfdCommon from: {bp_path}')
            except Exception:
                pass
" || true

# Make/Vendor-level cleanup for WfdCommon
find vendor/ -type f \( -name "*.mk" -o -name "*.bp" \) -exec sed -i '/WfdCommon/d' {} + 2>/dev/null || true
find device/ -type f \( -name "*.mk" -o -name "*.bp" \) -exec sed -i '/WfdCommon/d' {} + 2>/dev/null || true

echo "🧹 Running installclean..."
make installclean || true

echo "🏗️ Building Project Infinity-X ROM (m bacon)..."
m bacon

echo "=========================================================="
echo "✅ Project Infinity-X Build script finished successfully."
echo "=========================================================="
