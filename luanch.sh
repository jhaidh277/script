#!/bin/bash

echo "=========================================================="
echo "🚀 Starting Ultimate Build Script (Optimized & Fixed)"
echo "=========================================================="

MAIN_DIR=$(pwd)

# ১. প্রয়োজনীয় ফোল্ডার রিমুভ করা (কোনো ক্লিন কমান্ড নয়)
rm -rf device/oneplus/hotdogb
rm -rf device/oneplus/sm8150-common
rm -rf kernel/oneplus/sm8150
rm -rf vendor/oneplus/hotdogb
rm -rf vendor/oneplus/sm8150-common
rm -rf hardware/oplus
rm -rf .repo/local_manifests
find .repo/ -name "hooks" -type d -exec rm -rf {} + || true

# ২. এনভায়রনমেন্ট সেটআপ
export USE_CCACHE=0
export NOMINATIVE_CCACHE=1
export SKIP_VENDORSETUP=true

# ৩. Repo initialization (Android 16 -b 16)
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault --depth 1 || true

# ৪. Local manifest clone (আপনার তৈরি করা ম্যানিফেস্ট ব্যবহার হবে)
if [ ! -d ".repo/local_manifests" ]; then
    git clone https://github.com/jhaidh277/hotdogb_local_manifest --depth 1 -b op .repo/local_manifests || true
fi

# ৫. ফোর্স সিঙ্ক (যাতে vendor এবং অন্যান্য রিপোজিটরি সঠিকভাবে ডাউনলোড হয়)
echo "Syncing sources with force..."
repo sync -c -j$(nproc) --force-sync --no-clone-bundle --no-tags || true
/opt/crave/resync.sh || true

# ৬. KernelSU ACTIVATION
if [ -d "kernel/oneplus/sm8150" ]; then
    cd kernel/oneplus/sm8150
    find arch/arm64/configs/ -type f -name "*defconfig" | while read -r defconfig; do
        sed -i '/CONFIG_KERNELSU/d' "$defconfig" || true
        echo "CONFIG_KERNELSU=y" >> "$defconfig"
    done
    cd "$MAIN_DIR"
fi

# ৭. Environment configuration
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

# ৮. GSI Android.bp ফাইল মডিফাই
if [ -f build/make/target/product/gsi/Android.bp ]; then
    sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp || true
fi

# ৯. লাঞ্চ এবং বিল্ড কমান্ড
lunch infinity_hotdogb-userdebug || lunch lineage_hotdogb-userdebug || lunch hotdogb-userdebug || echo "⚠️ Lunch failed..."

# ফাইনাল কম্পাইলেশন কমান্ড
m bacon -j$(nproc)
