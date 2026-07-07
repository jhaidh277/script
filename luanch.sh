#!/bin/bash

echo "=========================================================="
echo "🚀 Starting Infinity-X Build for Beryl"
echo "=========================================================="

# ১. মেইন পাথ সেটআপ
MAIN_DIR=$(pwd)

# ২. পরিবেশ কনফিগারেশন
export USE_CCACHE=0
export SKIP_VENDORSETUP=true

# ৩. আগের ফাইল ক্লিনআপ
echo "Cleaning up directories..."
rm -rf .repo/local_manifests || true
rm -rf device/xiaomi/beryl device/xiaomi/beryl-kernel vendor/xiaomi/beryl || true

# ৪. সোর্স ইনিশিয়ালাইজেশন (Infinity-X অনুযায়ী)
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault --depth 1 || true

# ৫. আপনার লোকাল ম্যানিফেস্ট ক্লোন
mkdir -p .repo/local_manifests
git clone https://github.com/jhaidh277/local_manifests --depth 1 -b main .repo/local_manifests || true

# ৬. সোর্স সিঙ্ক করা
echo "Syncing sources..."
/opt/crave/resync.sh || echo "⚠️ Crave resync issue, proceeding..."

# ৭. এনভায়রনমেন্ট সেটআপ
source build/envsetup.sh || true

# ৮. লঞ্চ কমান্ড (আপনার AndroidProducts.mk অনুযায়ী আপডেট করা হয়েছে)
lunch infinity_beryl-bp2s-userdebug || echo "⚠️ Lunch failed..."

# ৯. বিল্ড শুরু
make installclean || true
m bacon -j$(nproc)
