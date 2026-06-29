#!/bin/bash

echo "=========================================================="
echo "🚀 Starting Safe Build Script (No Clean, No Camera, Fixed)"
echo "=========================================================="

MAIN_DIR=$(pwd)

# ১. এনভায়রনমেন্ট সেটআপ (ccache ও vendorsetup বাইপাস)
export USE_CCACHE=0
export NOMINATIVE_CCACHE=1
export SKIP_VENDORSETUP=true

# ২. Repo initialization
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault || true

# ৩. Local manifest clone
if [ ! -d ".repo/local_manifests" ]; then
    git clone https://github.com/jhaidh277/hotdogb_local_manifest --depth 1 -b op .repo/local_manifests || true
fi

# ৪. Crave Official Source Sync
echo "Syncing sources via Crave resync..."
/opt/crave/resync.sh || true

# ৫. KernelSU ACTIVATION (কার্নেল সোর্সে)
if [ -d "kernel/oneplus/sm8150" ]; then
    cd kernel/oneplus/sm8150
    find arch/arm64/configs/ -type f -name "*defconfig" | while read -r defconfig; do
        sed -i '/CONFIG_KERNELSU/d' "$defconfig" || true
        echo "CONFIG_KERNELSU=y" >> "$defconfig"
    done
    cd "$MAIN_DIR"
fi

# ৬. Environment configuration
export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=none
export TARGET_MULTISIM_CONFIG=dsds

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

source build/envsetup.sh || true

# ৭. GSI Android.bp ফাইল মডিফাই
if [ -f build/make/target/product/gsi/Android.bp ]; then
    sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp || true
fi

# ৮. লাঞ্চ এবং বিল্ড কমান্ড
lunch infinity_hotdogb-userdebug || lunch lineage_hotdogb-userdebug || lunch hotdogb-userdebug || echo "⚠️ Lunch failed..."

# ফাইনাল কম্পাইলেশন কমান্ড
m bacon -j$(nproc)
