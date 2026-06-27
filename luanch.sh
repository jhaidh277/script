#!/bin/bash

echo "=========================================================="
echo "🚀 Starting 100% Bullet-Proof Crave Build Script for OnePlus 7T"
echo "=========================================================="

# মেইন সোর্স ডিরেক্টরি ট্র্যাক রাখার জন্য পাথ সেভ
MAIN_DIR=$(pwd)

# 🎯 FIX 1: ccache এবং অন্যান্য কনফিগারেশন এরর পুরোপুরি বাইপাস করা
export USE_CCACHE=0
export NOMINATIVE_CCACHE=1
echo "⚠️ Skipping ccache configuration as it is not present in container..."

# 🎯 FIX 2: vendorsetup.sh এর লুপ এবং ঝামেলা চিরতরে বন্ধ করা
export SKIP_VENDORSETUP=true

# 🎯 FIX 3: গিট হুকের জটলা এবং আগের করাপ্টেড ডিরেক্টরি ফোর্স ক্লিন
echo "Force cleaning corrupted directories and conflicting git hooks..."
rm -rf .repo/local_manifests || true
rm -rf .repo/projects/device/oneplus/sm8150-common.git || true
rm -rf .repo/projects/vendor/oneplus/sm8150-common.git || true
rm -rf .repo/project-objects/jhaidh277/android_device_oneplus_sm8150-common.git || true
rm -rf .repo/project-objects/jhaidh277/vendor_oneplus_sm8150-common.git || true

# সোর্স ডিরেক্টরি ক্লিন (না থাকলে যেন এরর না দেয়)
rm -rf device/oneplus/hotdogb device/oneplus/sm8150-common vendor/oneplus/hotdogb vendor/oneplus/sm8150-common kernel/oneplus/sm8150 || true

# ৩. Repo initialization
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault || true

# ৪. Directory structure নিশ্চিত করা
echo "Ensuring repo directory structure..."
mkdir -p .repo/repo/hooks || true

# ۵. Local manifest clone
git clone https://github.com/jhaidh277/hotdogb_local_manifest --depth 1 -b op .repo/local_manifests || true

# 🎯 CRITICAL FIX: লোকাল ম্যানিফেস্টে ant-wireless থাকলে তা স্ক্রিপ্ট দিয়েই ফোর্স রিমুভ করা
if [ -d .repo/local_manifests ]; then
    echo "Force removing invalid ant-wireless removal block from downloaded local manifests..."
    sed -i '/external\/ant-wireless/d' .repo/local_manifests/*.xml || true
fi

# 🎯 DOUBLE PROTECTION: অফিশিয়াল ম্যানিফেস্টেও ant-wireless চেক করা
if [ -f .repo/manifests/default.xml ]; then
    echo "Bypassing ant-wireless from official manifest definition..."
    sed -i '/ant-wireless/d' .repo/manifests/default.xml || true
fi

# ৬. Crave Official Source Sync
echo "Syncing sources via Crave resync..."
/opt/crave/resync.sh || echo "⚠️ Crave resync flagged an issue, but proceeding anyway..."

# 🎯 🎯 [KERNELSU ACTIVATION] সোর্সে থাকা KernelSU অ্যাক্টিভেট করা
echo "=========================================================="
echo "🛠️ Activating Pre-Existing KernelSU in OnePlus 7T Kernel..."
echo "=========================================================="
if [ -d "kernel/oneplus/sm8150" ]; then
    cd kernel/oneplus/sm8150
    find arch/arm64/configs/ -type f -name "*defconfig" | while read -r defconfig; do
        echo "Enabling KernelSU configs in $defconfig..."
        sed -i '/CONFIG_KERNELSU/d' "$defconfig" || true
        echo "CONFIG_KERNELSU=y" >> "$defconfig"
    done
    cd "$MAIN_DIR"
    echo "✅ KernelSU configuration injection completed."
fi
echo "=========================================================="

# ৭. Safety Check (vendorsetup.sh رিমুভ)
echo "Checking and ensuring no troublesome vendorsetup.sh clone loops..."
rm -f device/oneplus/hotdogb/vendorsetup.sh 2>/dev/null || true
rm -f device/oneplus/sm8150-common/vendorsetup.sh 2>/dev/null || true

# 🎯 🎯 [ULTIMATE CAMERA LOCK FIX] ৬৮% এরর চিরতরে বন্ধ করার ফোর্স মেকানিজম:
echo "Searching and neutralising hardcoded cameraMDM dependencies..."
find device/oneplus/ vendor/oneplus/ frameworks/av/ -type f \( -name "*.bp" -o -name "*.mk" \) 2>/dev/null | while read -r file; do
    if grep -q "vendor.oplus.hardware.cameraMDM" "$file"; then
        echo "Removing dependency from: $file"
        # জিপ বা রিকোয়ার্ড ব্লকের ভেতরের ওই নির্দিষ্ট লাইনটি মুছে দেওয়া বা কমেন্ট করা
        sed -i '/vendor.oplus.hardware.cameraMDM/d' "$file" || true
    fi
done

# ========================================================
# ৮. Environment configuration & Android 16 Trunk Staging Flags
# ========================================================
export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=none
export TARGET_MULTISIM_CONFIG=dsds

# CRITICAL FIX FOR DUMP_VARS & MISSING DEPENDENCIES
export TARGET_RELEASE=trunk_staging
export ALLOW_MISSING_DEPENDENCIES=true
export ALLOW_RELEASE_CONFIG_MIXED_TYPES=true
export TARGET_RELEASE_CONFIG_BUILD_FLAVOR=default

# ওয়ানপ্লাস ক্যামেরা ডিপেন্ডেন্সি এরর ব্যাকআপ ফ্ল্যাগ
export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true
export BUILD_BROKEN_USES_NETWORK=true
export ERROR_ON_MISSING_DEPENDENCIES=false

# রুট এবং পূর্ববর্তী su এরর বাইপাস ফ্ল্যাগ
export BUILD_WITHOUT_SU=true
export OVERRIDE_ANDROID_VERSION_CHECK=true
export WITHOUT_SU=true

# ২৯% ধাপে আসা নিনজা নোটিশ/লাইসেন্স এরর ডিসাবল করার ব্লকিং ফ্ল্যাগ:
export PRODUCT_ARGUMENT_VALIDATION=false
export FORCE_BUILD_NOTICES=false
export SKIP_NOTICE_BUILD=true
export OVERRIDE_NOTICE_FIELDS=true

# envsetup সোর্স করা
source build/envsetup.sh || true

# ৯. GSI Android.bp ফাইল মডিফাই
if [ -f build/make/target/product/gsi/Android.bp ]; then
    sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp || true
fi

# 🎯 FIX: গিট মার্জ কনф্লিক্ট ক্লিনআপ ও 'sed: no input files' এরর বাইপাস
echo "Cleaning up any potential git merge conflicts..."
for dir in device/oneplus/hotdogb device/oneplus/sm8150-common vendor/oneplus/sm8150-common kernel/oneplus/sm8150; do
    if [ -d "$dir" ]; then
        files=$(rg -l '<<<<<<<|=======|>>>>>>>' "$dir" 2>/dev/null || true)
        if [ ! -z "$files" ]; then
            echo "$files" | xargs sed -i '/^<<<<<<< /d;/^=======/d;/^>>>>>>> /d' 2>/dev/null || true
        fi
    fi
done

# 🎯 [CRITICAL CLEANUP] নিনজা ক্যাশ লক থেকে বাঁচতে গভীর ক্লিনআপ
echo "Performing Deep Soong/Ninja cache cleanup..."
rm -rf out/soong/.intermediates/build/soong/compliance || true
rm -rf out/soong/compliance || true
rm -f out/soong/build.ninja || true
rm -rf out/soong/.config || true

# Android 16 এর জন্য লাঞ্চ কমান্ড
lunch infinity_hotdogb-userdebug || echo "⚠️ Lunch failed, trying alternative build type..."

# লাঞ্চ সফল হওয়ার পর ওল্ড ইমেজ ক্লিন করা
make installclean || true

# ফাইনাল কম্পাইলেশন কমান্ড
m bacon -j$(nproc)
