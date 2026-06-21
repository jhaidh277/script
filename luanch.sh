#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "=========================================================="
echo "🚀 Starting Perfect & Safe Crave Build Script for OnePlus 7T"
echo "=========================================================="

# 1. CCACHE configuration
mkdir -p /tmp/ccache
export CCACHE_DIR=/tmp/ccache
export USE_CCACHE=1

if command -v ccache &> /dev/null; then
    ccache -M 50G
    ccache -s
else
    echo "⚠️ ccache not found in container, proceeding..."
fi

# 2. Smart Clean: পুরনো বা কনফ্লিক্ট হওয়া ডিরেক্টরিগুলো পরিষ্কার করা (স্মার্ট ও সেফ উপায়)
echo "Performing a targeted clean to fix corrupted directories..."
rm -rf device/oneplus/hotdogb
rm -rf device/oneplus/sm8150-common
rm -rf vendor/oneplus/hotdogb
rm -rf vendor/oneplus/sm8150-common
rm -rf kernel/oneplus/sm8150
rm -rf .repo/local_manifests

# 3. Repo initialization
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault

# 4. Fix hooks and ensure directory structure exists
echo "Ensuring repo directory structure..."
mkdir -p .repo/repo/hooks

# 5. Local manifest clone (আপনার আপডেট করা নতুন লোকাল ম্যানিফেস্টটি আসবে)
git clone https://github.com/jhaidh277/hotdogb_local_manifest --depth 1 -b op .repo/local_manifests

# 6. Crave Official Source Sync
echo "Syncing sources via Crave resync..."
/opt/crave/resync.sh

# 7. Safety Check: vendorsetup.sh ক্লোন লুপ প্রতিরোধ করা
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

# 10. Clean up git conflicts across all your forked directories
echo "Cleaning up any potential git merge conflicts..."
for dir in device/oneplus/hotdogb device/oneplus/sm8150-common vendor/oneplus/sm8150-common kernel/oneplus/sm8150; do
    if [ -d "$dir" ]; then
        rg -l -0 '<<<<<<<|=======|>>>>>>>' "$dir" | xargs -0 sed -i '/^<<<<<<< /d;/^=======/d;/^>>>>>>> /d' || true
    fi
done

# 11. Build process
make installclean

# Android 16 এর জন্য লাঞ্চ কমান্ড
lunch infinity_hotdogb-trunk_staging-userdebug || lunch infinity_hotdogb-userdebug

m bacon -j$(nproc)
