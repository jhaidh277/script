#!/bin/bash

# কোনো কমান্ড ফেইল করলে সাথে সাথে স্ক্রিপ্ট বন্ধ করার জন্য
set -e

# ১. সিস্টেম সেটআপ এবং ডিপেনডেন্সি ইনস্টল
sudo apt update -y
sudo apt install patchelf ccache aria2 python3-pip ripgrep -y
pip3 install telegram-upload --break-system-packages

# সিসিএশ (CCACHE) কনফিগারেশন
mkdir -p /tmp/ccache
export CCACHE_DIR=/tmp/ccache
export USE_CCACHE=1
ccache -M 50G
ccache -s

# ২. স্মার্ট ক্লিন (ডিরেক্টরি করাপশন এবং আটকে থাকা মেমোরি ফিক্স)
echo "Cleaning up build output and conflicting directories..."
rm -rf out/
rm -rf device/oneplus/hotdogb
rm -rf vendor/oneplus/hotdogb
rm -rf kernel/oneplus/sm8150
rm -rf .repo/local_manifests

# ৩. রেপো ইনিশিয়ালাইজেশন (অফিশিয়াল ম্যানিফেস্ট অনুযায়ী)
if [ ! -d ".repo" ]; then
    echo "Initializing repo for the first time..."
    repo init --no-repo-verify -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault
fi

# ৪. হুক এবং ডিরেক্টরি স্ট্রাকচার ঠিক করা
echo "Ensuring repo directory structure..."
mkdir -p .repo/repo/hooks

# ৫. লোকাল ম্যানিফেস্ট ক্লোন
git clone https://github.com/jhaidh277/hotdogb_local_manifest --depth 1 -b op .repo/local_manifests

# ৬. সোর্স সিঙ্ক (ডেভস্পেস ফ্রেন্ডলি মেথড)
echo "Syncing source code..."
repo sync -c -j$(nproc --all) --fail-fast --force-sync --no-clone-bundle --no-tags --detach

# =====================================================================
# ভেন্ডর সেটআপ ফাইল রিমুভ (লুপ এড়ানোর জন্য)
# =====================================================================
echo "Removing troublesome vendorsetup.sh to avoid duplicate clone loops..."
rm -f device/oneplus/hotdogb/vendorsetup.sh

# ৭. কার্নেল-এসইউ ইন্টিগ্রেশন স্কিপ করা হলো
echo "Skipping manual KernelSU integration to avoid conflicts..."

# ৮. এনভায়রনমেন্ট ভ্যারিয়েবল সেটআপ
echo "Flushing old build variants and setting up environment..."
unset TARGET_PRODUCT
unset TARGET_BUILD_VARIANT
unset TARGET_RELEASE

export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=none
export TARGET_MULTISIM_CONFIG=dsds
export KERNEL_SUPPORTS_KSU=true

# অ্যান্ড্রয়েড ১৬ কাস্টম রম স্ট্যান্ডার্ড রিলিজ ফ্ল্যাগস (v3.11 ট্রাঙ্ক স্টেবল কমপ্লায়েন্ট)
export TARGET_RELEASE=trunk_staging
export ALLOW_MISSING_DEPENDENCIES=true

source build/envsetup.sh

# Sign out form default target variables before lunch
choosecombo userdebug infinity_hotdogb trunk_staging || true

# ৯. জিএসআই অ্যান্ড্রয়েড ডট বিপি ফাইল মডিফাই
if [ -f build/make/target/product/gsi/Android.bp ]; then
    sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp
fi

# ১০. গิต কনফ্লিক্ট ক্লিন
if [ -d device/oneplus/hotdogb ]; then
    rg -l -0 '<<<<<<<|=======|>>>>>>>' device/oneplus/hotdogb | xargs -0 sed -i '/^<<<<<<< /d;/^=======/d;/^>>>>>>> /d' || true
fi

# =====================================================================
# ভেন্ডর মেকফাইল হার্ড ফিক্স (Kati এরর এবং missing LOGO.img বাইপাস)
# =====================================================================
echo "Fixing vendor Android.mk to bypass Kati error..."
if [ -f vendor/oneplus/hotdogb/Android.mk ]; then
    sed -i '/radio/d' vendor/oneplus/hotdogb/Android.mk
    sed -i '/LOGO/d' vendor/oneplus/hotdogb/Android.mk
    sed -i '/logo/d' vendor/oneplus/hotdogb/Android.mk
fi

# ১১. বিল্ড প্রসেস শুরু
echo "Initializing fresh build target..."
make installclean

# ওয়ানপ্লাসের জন্য ডেডিকেটেড লাঞ্চ কমান্ড
lunch infinity_hotdogb-userdebug

m bacon -j$(nproc)
