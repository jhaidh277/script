#!/bin/bash

# কোনো কম্যান্ড ফেইল করলে স্ক্রিপ্ট যেন সাথে সাথে বন্ধ হয়ে যায়
set -e

# =====================================================================
# ১. সিস্টেম সেটআপ এবং ডিপেন্ডেন্সি ইনস্টল
# =====================================================================
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

# =====================================================================
# ২. রেপো ইনিশিয়ালাইজেশন (ProjectInfinity-X Android 16)
# =====================================================================
if [ ! -d ".repo" ]; then
    echo "Initializing ProjectInfinity-X repository..."
    repo init --no-repo-verify -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault
fi

# =====================================================================
# ৩. রেপো ট্র্যাক থেকে কনফ্লিক্ট ফোল্ডারগুলো মুছে ফেলা (CRITICAL FIX)
# =====================================================================
echo "Removing conflicting projects from repo tracking to prevent checkout error..."
rm -rf .repo/local_manifests
rm -rf .repo/projects/device/oneplus/hotdogb.git || true
rm -rf .repo/projects/device/oneplus/sm8150-common.git || true
rm -rf .repo/projects/hardware/oplus.git || true

# মূল সোর্স ডিরেক্টরিগুলো সম্পূর্ণ ক্লিন করা
rm -rf device/oneplus/hotdogb
rm -rf device/oneplus/sm8150-common
rm -rf vendor/oneplus/sm8150-common
rm -rf vendor/oneplus/hotdogb
rm -rf kernel/oneplus/sm8150
rm -rf hardware/oplus

# =====================================================================
# ৪. কোর সোর্স কোড সিঙ্ক
# =====================================================================
echo "Syncing core source code..."
# গিট চ্যাকাউট এরর এড়াতে এবং ফোর্স সিঙ্ক করতে ফ্ল্যাগ মডিফাই করা হয়েছে
repo sync -c -j$(nproc --all) --fail-fast --force-sync --no-clone-bundle --no-tags --detach || true

# সেফটি মেজার: সিঙ্কের পর যদি কোনো ফোল্ডার আবার চলে আসে, সেগুলোকে পুনরায় ক্লিন করা
rm -rf device/oneplus/hotdogb
rm -rf device/oneplus/sm8150-common
rm -rf hardware/oplus

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

# Oplus Hardware Dependency
git clone https://github.com/ProjectInfinity-X/android_hardware_oplus -b 16 hardware/oplus --depth 1 || git clone https://github.com/LineageOS/android_hardware_oplus -b lineage-22.1 hardware/oplus --depth 1

# =====================================================================
# 🛠️ মেকফাইল অটো-ফিক্স ও নাম পরিবর্তন (CRITICAL FIXES)
# =====================================================================
echo "Applying deep fixes for device tree and vendor configs..."

# গিট লক বা করাপ্টেড স্টেট পুরোপুরি ক্লিন করা
rm -rf device/oneplus/hotdogb/.git

# ফুল পাথ ভেরিয়েবল সেট করা
DEV_TREE="device/oneplus/hotdogb"

if [ -f "$DEV_TREE/lineage_hotdogb.mk" ]; then
    echo "Renaming lineage_hotdogb.mk to infinity_hotdogb.mk..."
    mv "$DEV_TREE/lineage_hotdogb.mk" "$DEV_TREE/infinity_hotdogb.mk"
fi

if [ -f "$DEV_TREE/infinity_hotdogb.mk" ]; then
    # প্রোডাক্ট নাম পরিবর্তন করা
    sed -i 's/lineage_hotdogb/infinity_hotdogb/g' "$DEV_TREE/infinity_hotdogb.mk"
    
    # রমের আসল কনফিগারেশন ফাইলটি খুঁজে বের করা
    echo "Checking core Infinity config file location..."
    
    if [ -f "vendor/infinity/config/common.mk" ]; then
        CONF_PATH="vendor/infinity/config/common.mk"
    elif [ -f "vendor/infinity/config/common_full_phone.mk" ]; then
        CONF_PATH="vendor/infinity/config/common_full_phone.mk"
    elif [ -f "vendor/infinity/config/infinity.mk" ]; then
        CONF_PATH="vendor/infinity/config/infinity.mk"
    else
        DETECTED_MK=$(ls vendor/infinity/config/*.mk 2>/dev/null | head -n 1)
        if [ ! -z "$DETECTED_MK" ]; then
            CONF_PATH="$DETECTED_MK"
        else
            CONF_PATH="vendor/infinity/config/common.mk"
        fi
    fi
    
    # সঠিক পাথটি মেকফাইলে পুশ করা
    echo "Setting config path to: $CONF_PATH"
    sed -i "s|vendor/infinity/config/common_full_phone.mk|$CONF_PATH|g" "$DEV_TREE/infinity_hotdogb.mk"
    sed -i "s|vendor/lineage/config/common_full_phone.mk|$CONF_PATH|g" "$DEV_TREE/infinity_hotdogb.mk"
    sed -i "s|vendor/infinity/config/common.mk|$CONF_PATH|g" "$DEV_TREE/infinity_hotdogb.mk"
fi

# ২. AndroidProducts.mk আপডেট
if [ -f "$DEV_TREE/AndroidProducts.mk" ]; then
    sed -i 's/lineage_hotdogb/infinity_hotdogb/g' "$DEV_TREE/AndroidProducts.mk"
fi

# লাঞ্চ লুপ এড়াতে অপ্রয়োজনীয় vendorsetup.sh রিমুভ করা
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
# ⚙️ এনভায়রনমেন্ট ফ্ল্যাগ এবং বিল্ড সেটআপ
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

# পরিবেশের ভেরিয়েবল লোড করা
source build/envsetup.sh

# GSI Android.bp ক্লিনআপ করা
if [ -f build/make/target/product/gsi/Android.bp ]; then
    sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp
fi

# =====================================================================
# ⚡ লাঞ্চ এবং কম্পাইলেশন শুরু
# =====================================================================
echo "Running lunch command for Infinity-X..."

# সঠিক লাঞ্চ সিকোয়েন্স ট্রাই করা
lunch infinity_hotdogb-trunk_staging-userdebug || lunch infinity_hotdogb-userdebug

echo "Initializing fresh build target..."
make installclean

echo "Starting compilation with m bacon..."
m bacon -j$(nproc --all)
