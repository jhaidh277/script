#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "=========================================================="
echo "🚀 Starting Perfect & Safe Crave Build Script for OnePlus 7T"
echo "=========================================================="

# 🎯 FIX 3: ccache না থাকার ওয়ার্নিং/এরর পুরোপুরি স্কিপ করা
export USE_CCACHE=0
echo "⚠️ Skipping ccache configuration as it is not present in container..."

# 🎯 FIX 2: গিট হুকের জটলা পুরোপুরি সাফ করা
echo "Force cleaning corrupted directories and conflicting git hooks..."
rm -rf .repo/local_manifests
rm -rf .repo/projects/device/oneplus/sm8150-common.git
rm -rf .repo/projects/vendor/oneplus/sm8150-common.git
rm -rf .repo/project-objects/jhaidh277/android_device_oneplus_sm8150-common.git
rm -rf .repo/project-objects/jhaidh277/vendor_oneplus_sm8150-common.git

# সোর্স ডিরেক্টরি ক্লিন
rm -rf device/oneplus/hotdogb
rm -rf device/oneplus/sm8150-common
rm -rf vendor/oneplus/hotdogb
rm -rf vendor/oneplus/sm8150-common
rm -rf kernel/oneplus/sm8150

# 3. Repo initialization
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault

# 4. Fix hooks and ensure directory structure exists
echo "Ensuring repo directory structure..."
mkdir -p .repo/repo/hooks

# 5. Local manifest clone
git clone https://github.com/jhaidh277/hotdogb_local_manifest --depth 1 -b op .repo/local_manifests

# 🎯 FIX 1 & 2 (Double Protection): অফিশিয়াল ম্যানিফেস্টে ant-wireless এর যেকোনো এন্ট্রি মুছে দেওয়া
if [ -f .repo/manifests/default.xml ]; then
    echo "Bypassing ant-wireless from official manifest definition..."
    sed -i '/ant-wireless/d' .repo/manifests/default.xml || true
fi

# 6. Crave Official Source Sync
echo "Syncing sources via Crave resync..."
/opt/crave/resync.sh

# 7. Safety Check
echo "Checking and ensuring no troublesome vendorsetup.sh clone loops..."
rm -f device/oneplus/hotdogb/vendorsetup.sh || true
rm -f device/oneplus/sm8150-common/vendorsetup.sh || true

# 8. Environment configuration & Android 16 Trunk Staging Flags
export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=none
export TARGET_MULTISIM_CONFIG=dsds

# Android 16 specific release configs
export TARGET_RELEASE=trunk_staging
export ALLOW_MISSING_DEPENDENCIES=true
export ALLOW_RELEASE_CONFIG_MIXED_TYPES=true

source build/envsetup.sh

# 9. Modify the GSI Android.bp file to remove Calendar entry
sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp

# 🎯 FIX 4: (100% Corrected Syntax) 'sed: no input files' ওয়ার্নিং বন্ধ করা
echo "Cleaning up any potential git merge conflicts..."
for dir in device/oneplus/hotdogb device/oneplus/sm8150-common vendor/oneplus/sm8150-common kernel/oneplus/sm8150; do
    if [ -d "$dir" ]; then
        files=$(rg -l '<<<<<<<|=======|>>>>>>>' "$dir" 2>/dev/null || true)
        if [ ! -z "$files" ]; then
            echo "$files" | xargs sed -i '/^<<<<<<< /d;/^=======/d;/^>>>>>>> /d' || true
        fi
    fi
done

# 11. Build process
make installclean

# Android 16 এর জন্য লাঞ্চ কমান্ড
lunch infinity_hotdogb-trunk_staging-userdebug || lunch infinity_hotdogb-userdebug

m bacon -j$(nproc)
