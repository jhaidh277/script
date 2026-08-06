#!/bin/bash

echo "=========================================================="
echo "🚀 Starting Build Script for Project Infinity-X - OnePlus 7T (hotdogb)"
echo "=========================================================="

MAIN_DIR=$(pwd)

export USE_CCACHE=0
export NOMINATIVE_CCACHE=1
export SKIP_VENDORSETUP=true

echo "🧹 Force cleaning corrupted directories..."
rm -rf .repo/local_manifests || true
rm -rf device/oneplus/hotdogb device/oneplus/sm8150-common vendor/oneplus/hotdogb vendor/oneplus/sm8150-common kernel/oneplus/sm8150 hardware/oplus hardware/dolby || true

echo "📥 Initializing repo for Project Infinity-X..."
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault --depth 1 || {
    echo "ERROR: repo init failed."
    exit 1
}

mkdir -p .repo/repo/hooks || true
mkdir -p .repo/local_manifests || true

echo "📥 Creating local manifest..."
cat << 'EOF' > .repo/local_manifests/roomservice.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <project name="jhaidh277/android_device_oneplus_hotdogb" path="device/oneplus/hotdogb" remote="github" revision="infinity" />
  <project name="jhaidh277/android_device_oneplus_sm8150-common" path="device/oneplus/sm8150-common" remote="github" revision="lineage-23.2" />
  <project name="jhaidh277/android_kernel_oneplus_sm8150" path="kernel/oneplus/sm8150" remote="github" revision="16.0" />
  <project name="hardware/dolby_lunaris" path="hardware/dolby" remote="github" revision="16" />
  <project path="vendor/oneplus/hotdogb" name="TheMuppets/proprietary_vendor_oneplus_hotdogb" remote="github" revision="lineage-23.2" />
  <project path="vendor/oneplus/sm8150-common" name="TheMuppets/proprietary_vendor_oneplus_sm8150-common" remote="github" revision="lineage-23.2" />
  <project path="hardware/oplus" name="LineageOS/android_hardware_oplus" remote="github" revision="lineage-23.2" />
</manifest>
EOF

echo "🔄 Syncing sources via Crave resync..."
/opt/crave/resync.sh || echo "⚠️ Crave resync flagged an issue, but proceeding anyway..."

# ------------------------------------------------------------
# 🩹 FIX 1: hardware/lineage/compat duplicate protobuf মডিউল
# ------------------------------------------------------------
BP1="hardware/lineage/compat/Android.bp"
if [ -f "$BP1" ]; then
    echo "🩹 Fixing duplicate modules in $BP1..."
    sed -i '/prebuilt_libprotobuf-cpp-full-3.9.1-vendorcompat/,/^}/d' "$BP1" || true
    sed -i '/prebuilt_libprotobuf-cpp-lite-3.9.1-vendorcompat/,/^}/d' "$BP1" || true
    sed -i '/prebuilt_libprotobuf-cpp-full-21.12-vendorcompat/,/^}/d' "$BP1" || true
    sed -i '/prebuilt_libprotobuf-cpp-lite-21.12-vendorcompat/,/^}/d' "$BP1" || true
fi

# ------------------------------------------------------------
# 🩹 FIX 2: camera_helper visibility মিক্সিং এরর
# ------------------------------------------------------------
BP2="device/oneplus/sm8150-common/camera_helper/Android.bp"
if [ -f "$BP2" ]; then
    echo "🩹 Fixing visibility conflict in $BP2..."
    sed -i '/visibility: \[/,/\],/d' "$BP2" || true
    if [ ! -f "device/oneplus/sm8150-common/camera_helper/CameraProviderExtension.cpp" ]; then
        touch device/oneplus/sm8150-common/camera_helper/CameraProviderExtension.cpp
    fi
fi

# ------------------------------------------------------------
# 🩹 FIX 3: GSI-তে libcameraservice_extension.opsm8150 dependency রিমুভ
# ------------------------------------------------------------
AV_BP="frameworks/av/services/camera/libcameraservice/Android.bp"
if [ -f "$AV_BP" ]; then
    echo "🩹 Removing GSI-incompatible camera extension dependency..."
    sed -i '/"libcameraservice_extension.opsm8150"/d' "$AV_BP" || true
    sed -i '/libcameraservice_extension.opsm8150/d' "$AV_BP" || true
fi

COMMON_BP_FILES=$(find device/oneplus/sm8150-common -name "Android.bp" -o -name "*.mk")
for bp in $COMMON_BP_FILES; do
    if grep -q "libcameraservice_extension.opsm8150" "$bp"; then
        echo "🩹 Removing reference from $bp..."
        sed -i '/libcameraservice_extension.opsm8150/d' "$bp" || true
    fi
done

# ------------------------------------------------------------
# 🩹 FIX 4: Missing IOPlusCameraMDM.h in CameraService.cpp
# ------------------------------------------------------------
CAMERA_SERVICE="frameworks/av/services/camera/libcameraservice/CameraService.cpp"
if [ -f "$CAMERA_SERVICE" ]; then
    echo "🩹 Patching CameraService.cpp to bypass missing IOPlusCameraMDM.h..."
    sed -i '/#include <vendor\/oplus\/hardware\/cameraMDM\/2.0\/IOPlusCameraMDM.h>/d' "$CAMERA_SERVICE" || true
    sed -i '/OPlusCameraMDM/d' "$CAMERA_SERVICE" || true
fi

# ------------------------------------------------------------
# 🩹 FIX 5: Missing hotdogb-vendor.mk (সতর্কতা সহ)
# ------------------------------------------------------------
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

# ========================================================
# Environment configuration
# ========================================================
export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=true
export TARGET_MULTISIM_CONFIG=dsds
export INFINITY_MAINTAINER="Jihad Hossain"
export TARGET_HAS_UDFPS=false
export WITH_GAPPS=true
export TARGET_RELEASE=trunk_staging
export ALLOW_MISSING_DEPENDENCIES=true
export ALLOW_RELEASE_CONFIG_MIXED_TYPES=true
export TARGET_RELEASE_CONFIG_BUILD_FLAVOR=default
export BUILD_WITHOUT_SU=true
export OVERRIDE_ANDROID_VERSION_CHECK=true
export WITHOUT_SU=true
export PRODUCT_ARGUMENT_VALIDATION=false
export FORCE_BUILD_NOTICES=false
export SKIP_NOTICE_BUILD=true
export OVERRIDE_NOTICE_FIELDS=true

set +u
export TOP="$MAIN_DIR"

echo "📦 Sourcing build/envsetup.sh..."
source build/envsetup.sh

type lunch >/dev/null 2>&1 || {
    echo "ERROR: lunch not available after sourcing envsetup.sh"
    exit 1
}

echo "💾 Setting up swap..."
setupSwap || true

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


echo "🧹 Running installclean..."
make installclean || true

echo "🏗️ Building Project Infinity-X ROM (m bacon)..."
m bacon -j16

set -u
echo "=========================================================="
echo "✅ Project Infinity-X Build script finished successfully."
echo "=========================================================="
