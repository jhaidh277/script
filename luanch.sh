#!/bin/bash
echo " =========================================================="
echo "🚀 Starting Full Clean Build Script (Error-Free)"
echo "=========================================================="

# ১. এনভায়রনমেন্ট সেটআপ
MAIN_DIR=$(pwd)
export USE_CCACHE=0
export SKIP_VENDORSETUP=true

# ২. কনফ্লিক্ট এবং হুক এরর দূর করতে সব পরিষ্কার করা
echo "Cleaning up all repo objects to fix hooks conflict..."
rm -rf .repo/projects*
rm -rf .repo/project-objects/*
rm -rf .repo/local_manifests
rm -rf device/oneplus/hotdogb
rm -rf device/oneplus/sm8150-common
rm -rf vendor/oneplus/sm8150-common

# ৩. রিপো ইনিশিয়ালাইজেশন
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectMatrixx/android -b 16.2 -g default,-mips,-darwin,-notdefault --depth 1

# ৪. লোকাল ম্যানিফেস্ট ডাউনলোড
mkdir -p .repo/local_manifests
git clone https://github.com/jhaidh277/hotdogb_local_manifest --depth 1 -b matrix .repo/local_manifests

# ৫. সিঙ্ক করা
/opt/crave/resync.sh

# ৬. ডুপ্লিকেট মডিউল ফিক্স
BP_FILE="vendor/oneplus/sm8150-common/Android.bp"
if [ -f "$BP_FILE" ]; then
    sed -i "s/\"prebuilt\"/\"prebuiltfixed\"/g" "$BP_FILE"
fi

# ৭. এনভায়রনমেন্ট কনফিগারেশন
export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export ALLOW_MISSING_DEPENDENCIES=true
export TARGET_RELEASE=trunk_staging
source build/envsetup.sh

# ৮. লাঞ্চ কমান্ড
lunch matrixx_hotdogb-userdebug

# ৯. বিল্ড শুরু (সংশোধিত: crave run বাদ দেওয়া হয়েছে)
make installclean
make matrixx -j$(nproc)
