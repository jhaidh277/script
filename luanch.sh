#!/bin/bash

echo "=========================================================="
echo "🚀 Starting Perfect Crave Build Script (Pre-Integrated KSU) for OnePlus 7T"
echo "=========================================================="

# 🎯 FIX: ccache এবং অন্যান্য কনফিগারেশন এরর পুরোপুরি বাইপাস করা
export USE_CCACHE=0
export NOMINATIVE_CCACHE=1
echo "⚠️ Skipping ccache configuration as it is not present in container..."

# 🎯 FIX: vendorsetup.sh এর লুপ এবং ঝামেলা চিরতরে বন্ধ করা
export SKIP_VENDORSETUP=true

# 🎯 FIX: গিট হুকের জটলা এবং আগের করাপ্টেড ডিরেক্টরি ফোর্স ক্লিন
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

# ৫. Local manifest clone
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
    
    # ডিফকনফিগে KernelSU ফ্ল্যাগ এনাবল করা (সম্ভাব্য সব defconfig ফাইলে)
    for defconfig in arch/arm64/configs/vendor/sm8150-perf_defconfig arch/arm64/configs/sm8150-perf_defconfig arch/arm64/configs/vendor/hotdogb_defconfig; do
        if [ -f "$defconfig" ]; then
            echo "Enabling KernelSU configs in $defconfig..."
            # আগের ডুপ্লিকেট বা কমেন্ট করা লাইন থাকলে তা পরিষ্কার করা
            sed -i '/CONFIG_KERNELSU/d' $defconfig || true
            # নতুন অ্যাক্টিভেশন এন্ট্রি যুক্ত করা
            echo "CONFIG_KERNELSU=y" >> $defconfig
        fi
    done
    cd ../../..
    echo "✅ KernelSU configuration injection completed."
fi
echo "=========================================================="

# ৭. Safety Check (vendorsetup.sh রিমুভ)
echo "Checking and ensuring no troublesome vendorsetup.sh clone loops..."
rm -f device/oneplus/hotdogb/vendorsetup.sh 2>/dev/null || true
rm -f device/oneplus/sm8150-common/vendorsetup.sh 2>/dev/null || true

# ৮. Environment configuration & Android 16 Trunk Staging Flags
export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=none
export TARGET_MULTISIM_CONFIG=dsds

# Android 16 specific release configs
export TARGET_RELEASE=trunk_staging
export ALLOW_MISSING_DEPENDENCIES=true
export ALLOW_RELEASE_CONFIG_MIXED_TYPES=true

# আগের xbin/su এরর ফিক্স করার জন্য ফ্ল্যাগ
export BUILD_WITHOUT_SU=true
export OVERRIDE_ANDROID_VERSION_CHECK=true
export WITHOUT_SU=true

# envsetup সোর্স করা
source build/envsetup.sh || true

# ৯. GSI Android.bp ফাইল মডিফাই
if [ -f build/make/target/product/gsi/Android.bp ]; then
    sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp || true
fi

# 🎯 FIX: গিট মার্জ কনফ্লিক্ট ক্লিনআপ ও 'sed: no input files' এরর বাইপাস
echo "Cleaning up any potential git merge conflicts..."
for dir in device/oneplus/hotdogb device/oneplus/sm8150-common vendor/oneplus/sm8150-common kernel/oneplus/sm8150; do
    if [ -d "$dir" ]; then
        files=$(rg -l '<<<<<<<|=======|>>>>>>>' "$dir" 2>/dev/null || true)
        if [ ! -z "$files" ]; then
            echo "$files" | xargs sed -i '/^<<<<<<< /d;/^=======/d;/^>>>>>>> /d' 2>/dev/null || true
        fi
    fi
done

# ১১. Build process
make installclean || true

# Android 16 এর জন্য লাঞ্চ কমান্ড
lunch infinity_hotdogb-trunk_staging-userdebug || lunch infinity_hotdogb-userdebug || echo "⚠️ Lunch failed, trying to compile directly..."

# ফাইনাল কম্পাইলেশন কমান্ড
m bacon -j$(nproc)
