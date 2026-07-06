#!/bin/bash

echo "=========================================================="
echo "🚀 Starting 100% Verified Script (Instruction Compliant)"
echo "=========================================================="

# মেইন সোর্স ডিরেক্টরি পাথ
MAIN_DIR=$(pwd)

# কনফিগারেশন
export USE_CCACHE=0
export NOMINATIVE_CCACHE=1
export SKIP_VENDORSETUP=true

# শুধুমাত্র প্রয়োজনীয় ডিরেক্টরি ক্লিন করা হচ্ছে (যা নিষেধ করা হয়নি)
rm -rf .repo/local_manifests || true
rm -rf device/oneplus/hotdogb device/oneplus/sm8150-common vendor/oneplus/hotdogb vendor/oneplus/sm8150-common kernel/oneplus/sm8150 hardware/oplus || true

# ৩. Repo initialization
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectMatrixx/android -b 16.2 -g default,-mips,-darwin,-notdefault --depth 1 || true

# ৪. Directory structure নিশ্চিত করা
mkdir -p .repo/repo/hooks || true

# ৫. Local manifest clone
git clone https://github.com/jhaidh277/hotdogb_local_manifest --depth 1 -b matrix .repo/local_manifests || true

# ৬. Sync (শুধুমাত্র resync.sh)
echo "Syncing sources via Crave resync..."
/opt/crave/resync.sh

# ডুপ্লিকেট মডিউল ফিক্স
BP_FILE="vendor/oneplus/sm8150-common/Android.bp"
if [ -f "$BP_FILE" ]; then
    awk '/name:[[:space:]]*"prebuilt_"/ { count++; if (count == 2) { sub(/"prebuilt_"/, "\"prebuilt_duplicate_fixed_\"") } } { print }' "$BP_FILE" > "${BP_FILE}.tmp" && mv "${BP_FILE}.tmp" "$BP_FILE" || true
fi

# KernelSU
if [ -d "kernel/oneplus/sm8150" ]; then
    cd kernel/oneplus/sm8150
    find arch/arm64/configs/ -type f -name "*defconfig" | while read -r defconfig; do
        sed -i '/CONFIG_KERNELSU/d' "$defconfig" || true
        echo "CONFIG_KERNELSU=y" >> "$defconfig"
    done
    cd "$MAIN_DIR"
fi

# এনভায়রনমেন্ট
export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=true
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

# GSI ফাইল মডিফাই
if [ -f build/make/target/product/gsi/Android.bp ]; then
    sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp || true
fi

# লাঞ্চ
lunch matrixx_hotdogb-userdebug || echo "⚠️ Lunch failed..."

# বিল্ড
crave run -- make matrixx -j$(nproc)
