#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "=========================================================="
echo "🚀 Starting Perfect & Safe Crave Build Script for OnePlus 7T"
echo "=========================================================="

# 1. CCACHE configuration (ccache না থাকলে অটো স্কিপ করবে)
mkdir -p /tmp/ccache
export CCACHE_DIR=/tmp/ccache
export USE_CCACHE=1

if command -v ccache &> /dev/null; then
    ccache -M 50G
    ccache -s
else
    echo "⚠️ ccache not found in container, proceeding..."
fi

# 2. Hard Clean: Remove everything to fix corrupted directories
echo "Performing a deep clean..."
rm -rf .repo/
rm -rf device/oneplus/hotdogb
rm -rf vendor/oneplus/hotdogb
rm -rf kernel/oneplus/sm8150

# 3. Repo initialization (Fresh start)
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault

# 4. Fix hooks and ensure directory structure exists
echo "Ensuring repo directory structure..."
mkdir -p .repo/repo/hooks

# 5. Local manifest clone (আপনার সঠিক লিঙ্ক ও ব্রাঞ্চ)
git clone https://github.com/jhaidh277/hotdogb_local_manifest --depth 1 -b op .repo/local_manifests

# 6. Source sync
/opt/crave/resync.sh
repo sync -c -j$(nproc) --force-sync --no-clone-bundle --no-tags --detach

# 7. KernelSU integration
echo "Integrating KernelSU..."
pushd kernel/oneplus/sm8150
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s v0.9.5
popd

# 8. Environment configuration & Android 16 Trunk Staging Flags
export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=none
export TARGET_MULTISIM_CONFIG=dsds
export KERNEL_SUPPORTS_KSU=true

# Android 16 specific release configs
export TARGET_RELEASE=trunk_staging
export ALLOW_MISSING_DEPENDENCIES=true
export ALLOW_RELEASE_CONFIG_MIXED_TYPES=true

source build/envsetup.sh

# 9. Modify the GSI Android.bp file to remove Calendar entry
sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp

# 10. Clean up conflicts
rg -l -0 '<<<<<<<|=======|>>>>>>>' device/oneplus/hotdogb | xargs -0 sed -i '/^<<<<<<< /d;/^=======/d;/^>>>>>>> /d' || true

# 11. Build process
make installclean

# Android 16 এর জন্য লাঞ্চ কমান্ড ফিক্স করা হয়েছে
lunch infinity_hotdogb-trunk_staging-userdebug || lunch infinity_hotdogb-userdebug

m bacon -j$(nproc)
