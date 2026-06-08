#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. System setup and dependencies
echo "Installing system dependencies..."
sudo apt update -y
sudo apt install patchelf ccache aria2 python3-pip ripgrep -y
pip3 install telegram-upload --break-system-packages

# CCACHE configuration
mkdir -p /tmp/ccache
export CCACHE_DIR=/tmp/ccache
export USE_CCACHE=1
ccache -M 50G
ccache -s

# 2. Smart Clean: Remove old build outputs and conflicting directories
echo "Cleaning up build output and conflicting directories..."
rm -rf out/
rm -rf device/oneplus/hotdogb
rm -rf vendor/oneplus/hotdogb
rm -rf kernel/oneplus/sm8150
rm -rf .repo/local_manifests

# 3. Repo initialization (Based on official manifest)
if [ ! -d ".repo" ]; then
    echo "Initializing repository for the first time..."
    repo init --no-repo-verify -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault
fi

# 4. Fix hooks and ensure directory structure exists
echo "Ensuring repo directory structure..."
mkdir -p .repo/repo/hooks

# 5. Local manifest clone
echo "Cloning local manifest..."
git clone https://github.com/jhaidh277/hotdogb_local_manifest --depth 1 -b infi .repo/local_manifests

# =====================================================================
# 📸 OPLUS HARDWARE (ONEPLUS CAMERA DEPENDENCY) FORCE CLONE
# This fixes: vendor.oplus.hardware.cameraMDM@2.0 missing dependency error
# =====================================================================
echo "Cloning OnePlus Oplus Camera Hardware Repo for Android 16..."
rm -rf hardware/oplus
git clone https://github.com/ProjectInfinity-X/android_hardware_oplus -b 16 hardware/oplus --depth 1

# 6. Source sync (Devspace friendly method)
echo "Syncing source code..."
repo sync -c -j$(nproc --all) --fail-fast --force-sync --no-clone-bundle --no-tags --detach

# =====================================================================
# Remove vendorsetup.sh to avoid duplicate clone loops
# =====================================================================
echo "Removing troublesome vendorsetup.sh to avoid duplicate clone loops..."
rm -f device/oneplus/hotdogb/vendorsetup.sh

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

# Android 16 custom ROM standard release flags (v3.11 Trunk Stable compliant)
export TARGET_RELEASE=trunk_staging
export ALLOW_MISSING_DEPENDENCIES=true

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

# 11. Build process start
echo "Initializing fresh build target..."
make installclean

# Traditional lunch command for OnePlus 7T
echo "Running lunch command..."
lunch infinity_hotdogb-userdebug

echo "Starting compilation with m bacon..."
m bacon -j$(nproc)
