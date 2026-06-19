#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. System setup and dependencies
echo "Installing system dependencies..."
sudo apt update -y
sudo apt install patchelf ccache aria2 python3-pip ripgrep pipx -y

# Install telegram-upload cleanly
pip3 install telegram-upload --break-system-packages || pipx install telegram-upload

# CCACHE configuration
mkdir -p /tmp/ccache
export CCACHE_DIR=/tmp/ccache
export USE_CCACHE=1
ccache -M 50G
ccache -s

# 2. Smart Clean: Remove old build conflicting directories
echo "Cleaning up conflicting directories..."
rm -rf device/oneplus/hotdogb
rm -rf device/oneplus/sm8150-common
rm -rf vendor/oneplus/sm8150-common
rm -rf vendor/oneplus/hotdogb
rm -rf kernel/oneplus/sm8150
rm -rf hardware/oplus
rm -rf .repo/local_manifests

# 3. Repo initialization (Based on official manifest)
if [ ! -d ".repo" ]; then
    echo "Initializing ProjectInfinity-X repository..."
    repo init --no-repo-verify -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault
fi

# 4. Source sync (Only core ROM source sync)
echo "Syncing core source code..."
repo sync -c -j$(nproc --all) --fail-fast --force-sync --no-clone-bundle --no-tags --detach

# =====================================================================
# 🚀 DIRECT GIT CLONE METHOD (লোকাল ম্যানিফেস্ট ছাড়া সরাসরি গিট ক্লোন)
# =====================================================================
echo "Cloning device, kernel, and vendor trees directly..."

# Device Tree
git clone https://github.com/jhaidh277/device_oneplus_hotdogb -b 16 device/oneplus/hotdogb --depth 1

# Common Device Tree
git clone https://github.com/jhaidh277/android_device_oneplus_sm8150-common -b 16 device/oneplus/sm8150-common --depth 1

# Kernel Source
git clone https://github.com/jhaidh277/android_kernel_oneplus_sm8150 -b 16.0 kernel/oneplus/sm8150 --depth 1

# Vendor Common Source
git clone https://github.com/jhaidh277/vendor_oneplus_sm8150-common -b 16 vendor/oneplus/sm8150-common --depth 1

# Vendor Specific Tree
git clone https://github.com/TheMuppets/proprietary_vendor_oneplus_hotdogb -b lineage-22.1 vendor/oneplus/hotdogb --depth 1

# Oplus Hardware Dependency (Public)
git clone https://github.com/ProjectInfinity-X/android_hardware_oplus -b 15 hardware/oplus --depth 1 || git clone https://github.com/LineageOS/android_hardware_oplus -b lineage-22.1 hardware/oplus --depth 1

# =====================================================================
# 🛠️ CRITICAL FIXES (মেকফাইল এবং সোর্স কোড এরর অটো-ফিক্স)
# =====================================================================

# ১. common_full_phone.mk missing error ফিক্স (আপনার স্ক্রিনশটের এরর)
echo "Fixing common_full_phone.mk inheritance error..."
if [ -f device/oneplus/hotdogb/lineage_hotdogb.mk ]; then
    # যদি ফাইলটি থাকে, তবে ইনফিনিটি রমের আসল পাথের সাথে এটি রিপ্লেস করবে
    sed -i 's|vendor/infinity/config/common_full_phone.mk|vendor/infinity/config/common.mk|g' device/oneplus/hotdogb/lineage_hotdogb.mk
fi

# ২. vendorsetup.sh রিমুভ করা লুপ এড়াতে
rm -f device/oneplus/hotdogb/vendorsetup.sh || true

# ৩. Vendor Makefile Hard Fix (Bypass Kati error)
echo "Fixing vendor Android.mk to bypass Kati error..."
if [ -f vendor/oneplus/hotdogb/Android.mk ]; then
    sed -i '/radio/d' vendor/oneplus/hotdogb/Android.mk
    sed -i '/LOGO/d' vendor/oneplus/hotdogb/Android.mk
    sed -i '/logo/d' vendor/oneplus/hotdogb/Android.mk
fi

# 5. Environment configuration & OnePlus Camera Build Flags
echo "Setting up build environment..."
export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=none
export TARGET_MULTISIM_CONFIG=dsds
export KERNEL_SUPPORTS_KSU=true
export TARGET_USES_OPLUS_CAMERA=true
export BOREALIS_CAMERA_BRAND=oneplus
export TARGET_EXCLUDE_AOSP_CAMERA=true
export TARGET_EXCLUDE_APERTURE_CAMERA=true
export TARGET_RELEASE=trunk_staging
export ALLOW_MISSING_DEPENDENCIES=true

# Load environment
source build/envsetup.sh

# 6. GSI Android.bp cleanup
if [ -f build/make/target/product/gsi/Android.bp ]; then
    sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp
fi

# 7. Lunch and Build Start
echo "Running lunch command for Infinity-X..."
lunch infinity_hotdogb-trunk_staging-userdebug || lunch infinity_hotdogb-userdebug

echo "Initializing fresh build target..."
make installclean

echo "Starting compilation with m bacon..."
m bacon -j$(nproc)
