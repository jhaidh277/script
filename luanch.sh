#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "=========================================================="
echo "🚀 Starting Perfect & Safe Crave Build Script for OnePlus 7T"
echo "=========================================================="

# ১. CCACHE configuration (কমান্ড না থাকলে অটো স্কিপ করবে বা এনভায়রনমেন্ট সেট করবে)
mkdir -p /tmp/ccache
export CCACHE_DIR=/tmp/ccache
export USE_CCACHE=1

if command -v ccache &> /dev/null; then
    ccache -M 50G
    ccache -s
else
    echo "⚠️ ccache not found in container, proceeding with default Android ccache..."
fi

# ২. Smart Clean: Remove old build outputs and conflicting directories
echo "Cleaning up build output and conflicting directories..."
rm -rf out/
rm -rf device/oneplus/hotdogb
rm -rf vendor/oneplus/hotdogb
rm -rf kernel/oneplus/sm8150
rm -rf .repo/local_manifests

# ৩. Repo initialization (Based on official manifest)
if [ ! -d ".repo" ]; then
    echo "Initializing repository for the first time..."
    repo init --no-repo-verify -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault
fi

# ৪. Fix hooks and ensure directory structure exists
echo "Ensuring repo directory structure..."
mkdir -p .repo/repo/hooks

# ৫. Local manifest clone (আপনার দেওয়া লিঙ্কের সঠিক ওয়ান-লাইনার)
echo "Cloning local manifest from your GitHub repository..."
git clone https://github.com/jhaidh277/hotdogb_local_manifest --depth 1 -b op .repo/local_manifests

# =====================================================================
# 📸 OPLUS HARDWARE (ONEPLUS CAMERA DEPENDENCY) FORCE CLONE
# =====================================================================
echo "Cloning OnePlus Oplus Camera Hardware Repo for Android 16..."
rm -rf hardware/oplus
git clone https://github.com/ProjectInfinity-X/android_hardware_oplus -b 16 hardware/oplus --depth 1

# ৬. Source sync (Devspace friendly method)
echo "Syncing source code..."
repo sync -c -j$(nproc --all) --fail-fast --force-sync --no-clone-bundle --no-tags --detach

# =====================================================================
# 🛠️ CRITICAL FIX: PURGE TEXTPROTO CONFLICTS BEFORE ENV SETUP
# =====================================================================
echo "Purging old textproto files to fix Android 16 Release Config mixture error..."
find build/make/release/ -name '*.textproto' -delete 2>/dev/null || true
find vendor/ -name '*.textproto' -delete 2>/dev/null || true

# =====================================================================
# Remove vendorsetup.sh to avoid duplicate clone loops
# =====================================================================
echo "Removing troublesome vendorsetup.sh to avoid duplicate clone loops..."
rm -f device/oneplus/hotdogb/vendorsetup.sh
rm -f device/oneplus/sm8150-common/vendorsetup.sh

# 7. KernelSU integration skipped to avoid conflicts
echo "Skipping manual KernelSU integration to avoid conflicts..."

# 8. Environment configuration & OnePlus Camera Build Flags
echo "Flushing old build variants and setting up environment..."
unset TARGET_PRODUCT
unset TARGET_BUILD_VARIANT
unset TARGET_RELEASE

export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=none
export TARGET_MULTISIM_CONFIG=dsds
export KERNEL_SUPPORTS_KSU=true

# Android 16 custom ROM standard release flags
export TARGET_RELEASE=trunk_staging
export ALLOW_MISSING_DEPENDENCIES=true
export ALLOW_RELEASE_CONFIG_MIXED_TYPES=true

echo "Loading Build Environment..."
source build/envsetup.sh

# Sign out from default target variables before lunch
choosecombo userdebug infinity_hotdogb trunk_staging || true

# 9. Modify the GSI Android.bp file to remove Calendar entry
if [ -f build/make/target/product/gsi/Android.bp ]; then
    echo "Modifying GSI Android.bp file..."
    sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp
fi

# 10. Clean up git merge conflicts if any
if [ -d device/oneplus/hotdogb ]; then
    echo "Cleaning up potential git conflicts..."
    rg -l -0 '<<<<<<<|=======|>>>>>>>' device/oneplus/hotdogb | xargs -0 sed -i '/^<<<<<<< /d;/^=======/d;/^>>>>>>> /d' || true
fi

# =====================================================================
# Vendor Makefile Hard Fix (Bypass Kati error and missing LOGO.img)
# =====================================================================
echo "Fixing vendor Android.mk to bypass Kati error..."
if [ -f vendor/oneplus/hotdogb/Android.mk ]; then
    sed -i '/radio/d' vendor/oneplus/hotdogb/Android.mk
    sed -i '/LOGO/d' vendor/oneplus/hotdogb/Android.mk
    sed -i '/logo/d' vendor/oneplus/hotdogb/Android.mk
fi

# ১১. Build process start
echo "Initializing fresh build target..."
make installclean

# Corrected lunch command for Android 16 Trunk Staging
echo "Running lunch command..."
lunch infinity_hotdogb-trunk_staging-userdebug

echo "🚀 Starting compilation with m bacon..."
m bacon -j$(nproc --all)
