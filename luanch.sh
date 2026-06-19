#!/bin/bash

# কোনো কম্যান্ড ফেইল করলে স্ক্রিপ্ট যেন সাথে সাথে বন্ধ হয়ে যায়
set -e

# ১. সিস্টেম সেটআপ এবং ডিপেন্ডেন্সি ইনস্টল
echo "Installing system dependencies..."
sudo apt update -y
sudo apt install patchelf ccache aria2 python3-pip ripgrep pipx -y

# telegram-upload ক্লিন ইনস্টল
pip3 install telegram-upload --break-system-packages || pipx install telegram-upload

# CCACHE কনফিগারেশন
mkdir -p /tmp/ccache
export CCACHE_DIR=/tmp/ccache
export USE_CCACHE=1
ccache -M 50G
ccache -s

# ২. স্মার্ট ক্লিন: আগের কনফ্লিক্ট হওয়া ফোল্ডারগুলো মুছে ফেলা
echo "Cleaning up conflicting directories..."
rm -rf device/oneplus/hotdogb
rm -rf device/oneplus/sm8150-common
rm -rf vendor/oneplus/sm8150-common
rm -rf vendor/oneplus/hotdogb
rm -rf kernel/oneplus/sm8150
rm -rf hardware/oplus
rm -rf .repo/local_manifests

# ৩. রেপো ইনিশিয়ালাইজেশন (ProjectInfinity-X Android 16)
if [ ! -d ".repo" ]; then
    echo "Initializing ProjectInfinity-X repository..."
    repo init --no-repo-verify -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault
fi

# ৪. সোর্স কোড সিঙ্ক
echo "Syncing core source code..."
repo sync -c -j$(nproc --all) --fail-fast --force-sync --no-clone-bundle --no-tags --detach

# =====================================================================
# 🚀 সরাসরি গিট ক্লোন (Device, Kernel, and Vendor Trees)
# =====================================================================
echo "Cloning device, kernel, and vendor trees directly..."

# Device Tree ক্লোন
git clone https://github.com/jhaidh277/device_oneplus_hotdogb -b 16 device/oneplus/hotdogb --depth 1

# Common Device Tree ক্লোন
git clone https://github.com/jhaidh277/android_device_oneplus_sm8150-common -b 16 device/oneplus/sm8150-common --depth 1

# Kernel Source ক্লোন
git clone https://github.com/jhaidh277/android_kernel_oneplus_sm8150 -b 16.0 kernel/oneplus/sm8150 --depth 1

# Vendor Common Source ক্লোন
git clone https://github.com/jhaidh277/vendor_oneplus_sm8150-common -b 16 vendor/oneplus/sm8150-common --depth 1

# Vendor Specific Tree (OnePlus 7T এর প্রোপ্রাইটারি ফাইল)
git clone https://github.com/TheMuppets/proprietary_vendor_oneplus_hotdogb -b lineage-22.1 vendor/oneplus/hotdogb --depth 1

# Oplus Hardware Dependency (Android 16 বা সর্বসাম্প্রতিক সাপোর্ট পেতে)
git clone https://github.com/ProjectInfinity-X/android_hardware_oplus -b 16 hardware/oplus --depth 1 || git clone https://github.com/LineageOS/android_hardware_oplus -b lineage-22.1 hardware/oplus --depth 1

# =====================================================================
# 🛠️ মেকফাইল অটো-ফিক্স ও নাম পরিবর্তন (CRITICAL FIXES)
# =====================================================================
echo "Applying critical makefile fixes for Infinity-X..."

# ডিভাইস ট্রির ভেতর যদি lineage_hotdogb.mk থাকে, তবে সেটাকে infinity_hotdogb.mk তে রূপান্তর করা
cd device/oneplus/hotdogb
if [ -f lineage_hotdogb.mk ]; then
    echo "Renaming lineage_hotdogb.mk to infinity_hotdogb.mk..."
    mv lineage_hotdogb.mk infinity_hotdogb.mk
fi

# infinity_hotdogb.mk এর ভেতরের টেক্সট এবং ভুল পাথ ফিক্স করা
if [ -f infinity_hotdogb.mk ]; then
    # ১. আপনার স্ক্রিনশটের এরর ফিক্স (common_full_phone.mk কে common.mk তে পরিবর্তন)
    sed -i 's|vendor/infinity/config/common_full_phone.mk|vendor/infinity/config/common.mk|g' infinity_hotdogb.mk
    sed -i 's|vendor/lineage/config/common_full_phone.mk|vendor/infinity/config/common.mk|g' infinity_hotdogb.mk
    
    # ২. প্রোডাক্ট নাম পরিবর্তন করা যেন লাঞ্চ কম্যান্ড একে চিনতে পারে
    sed -i 's/lineage_hotdogb/infinity_hotdogb/g' infinity_hotdogb.mk
fi

# অ্যান্ড্রয়েড ১৬ এর জন্য AndroidProducts.mk আপডেট করা যেন লাঞ্চ কম্যান্ডের লিস্টে আসে
if [ -f AndroidProducts.mk ]; then
    sed -i 's/lineage_hotdogb/infinity_hotdogb/g' AndroidProducts.mk
fi
cd ../../..

# লাঞ্চ লুপ এড়াতে অপ্রয়োজনীয় vendorsetup.sh রিমুভ করা
rm -f device/oneplus/hotdogb/vendorsetup.sh || true
rm -f device/oneplus/sm8150-common/vendorsetup.sh || true

# ভেন্ডর ফোল্ডারের Android.mk এর Kati এরর বাইপাস করা
echo "Fixing vendor Android.mk to bypass Kati error..."
if [ -f vendor/oneplus/hotdogb/Android.mk ]; then
    sed -i '/radio/d' vendor/oneplus/hotdogb/Android.mk
    sed -i '/LOGO/d' vendor/oneplus/hotdogb/Android.mk
    sed -i '/logo/d' vendor/oneplus/hotdogb/Android.mk
fi

# =====================================================================
# ⚙️ এনভায়রনমেন্ট ফ্ল্যাগ এবং বিল্ড সেটআপ
# =====================================================================
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
export ALLOW_MISSING_DEPENDENCIES=true

# Android 16 নির্দিষ্ট বিল্ড রিলিজ ফ্ল্যাগ
export TARGET_RELEASE=trunk_staging

# পরিবেশের ভেরিয়েবল লোড করা
source build/envsetup.sh

# GSI Android.bp ক্লিনআপ করা
if [ -f build/make/target/product/gsi/Android.bp ]; then
    sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp
fi

# লাঞ্চ ও কমপাইল শুরু করা
echo "Running lunch command for Infinity-X..."
lunch infinity_hotdogb-trunk_staging-userdebug || lunch infinity_hotdogb-userdebug

echo "Initializing fresh build target..."
make installclean

echo "Starting compilation with m bacon..."
m bacon -j$(nproc)
