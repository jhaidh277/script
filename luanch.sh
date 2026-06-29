#!/bin/bash

echo "=========================================================="
echo "🚀 Starting Clean Build Script (Camera-Free, Optimized)"
echo "=========================================================="

MAIN_DIR=$(pwd)

# ১. এনভায়রনমেন্ট সেটআপ
export USE_CCACHE=0
export SKIP_VENDORSETUP=true
export ALLOW_MISSING_DEPENDENCIES=true
export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=none

# ২. ডিরেক্টরি ক্লিনআপ (ক্যামেরা ইন্টারফেস বাদে)
echo "Cleaning working directories..."
rm -rf out/soong/.intermediates/build/soong/compliance || true
rm -rf out/soong/compliance || true
rm -f out/soong/build.ninja || true

# ৩. সোর্স সিনক্রোনাইজেশন
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault || true
git clone https://github.com/jhaidh277/hotdogb_local_manifest --depth 1 -b op .repo/local_manifests || true
/opt/crave/resync.sh || true

# ৪. কার্নেলসু (KernelSU) অ্যাক্টিভেশন
if [ -d "kernel/oneplus/sm8150" ]; then
    cd kernel/oneplus/sm8150
    find arch/arm64/configs/ -type f -name "*defconfig" | while read -r defconfig; do
        sed -i '/CONFIG_KERNELSU/d' "$defconfig" || true
        echo "CONFIG_KERNELSU=y" >> "$defconfig"
    done
    cd "$MAIN_DIR"
fi

# ৫. বিল্ড এনভায়রনমেন্ট লোড
source build/envsetup.sh || true

# ৬. লাঞ্চ এবং বিল্ড
lunch infinity_hotdogb-userdebug || lunch lineage_hotdogb-userdebug || lunch hotdogb-userdebug
make installclean
m bacon -j$(nproc)
