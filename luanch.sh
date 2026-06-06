#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. System setup and dependencies
sudo apt update -y
sudo apt install patchelf ccache aria2 python3-pip ripgrep -y
pip3 install telegram-upload --break-system-packages

# CCACHE configuration
mkdir -p /tmp/ccache
export CCACHE_DIR=/tmp/ccache
export USE_CCACHE=1
ccache -M 50G
ccache -s

# 2. Hard Clean: Remove everything to fix corrupted directories and stuck cache
echo "Performing a deep clean..."
rm -rf .repo/
rm -rf device/oneplus/hotdogb
rm -rf vendor/oneplus/hotdogb
rm -rf kernel/oneplus/sm8150
rm -rf out/
rm -rf .repo/local_manifests

# 3. Repo initialization (Fresh start based on official manifest)
repo init --no-repo-verify -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault

# 4. Fix hooks and ensure directory structure exists
echo "Ensuring repo directory structure..."
mkdir -p .repo/repo/hooks

# 5. Local manifest clone
git clone https://github.com/jhaidh277/hotdogb_local_manifest --depth 1 -b op .repo/local_manifests

# 6. Source sync
/opt/crave/resync.sh
repo sync -c -j2 --fail-fast --force-sync --no-clone-bundle --no-tags --detach

# =====================================================================
# 🛑 ভেন্ডর সেটআপ ফাইলটি ডিলিট করা হলো
# =====================================================================
echo "Removing troublesome vendorsetup.sh to avoid duplicate clone loops..."
rm -f device/oneplus/hotdogb/vendorsetup.sh

# 7. KernelSU integration (সমস্যা সমাধান করতে এটিকে কমেন্ট আউট করা হলো)
echo "Skipping manual KernelSU integration to avoid conflicts..."
# pushd kernel/oneplus/sm8150
# curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s v0.9.5
# popd

# 8. Environment configuration & Stuck Cache Flush
echo "Flushing old build variants and setting up environment..."
unset TARGET_PRODUCT
unset TARGET_BUILD_VARIANT
unset TARGET_RELEASE

export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=none
export TARGET_MULTISIM_CONFIG=dsds
export KERNEL_SUPPORTS_KSU=true

# 🛑 অ্যান্ড্রয়েড ১৬ কাস্টม রম স্ট্যান্ডার্ড রিলিজ ফ্ল্যাগস (v3.11 ট্রাঙ্ক স্টেবল কমপ্লায়েন্ট)
export TARGET_RELEASE=trunk_staging
export ALLOW_MISSING_DEPENDENCIES=true

source build/envsetup.sh

# 9. Modify the GSI Android.bp file to remove Calendar entry
sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp

# 10. Clean up conflicts
rg -l -0 '<<<<<<<|=======|>>>>>>>' device/oneplus/hotdogb | xargs -0 sed -i '/^<<<<<<< /d;/^=======/d;/^>>>>>>> /d' || true

# =====================================================================
# 🛑 ভেন্ডর মেকফাইল হার্ড ফিক্স (LOGO.img এবং radio Kati এরর বাইপাস)
# =====================================================================
echo "Clearing troublesome vendor Android.mk lines to bypass Kati error..."
if [ -f vendor/oneplus/hotdogb/Android.mk ]; then
    sed -i '/radio/d' vendor/oneplus/hotdogb/Android.mk
    sed -i '/LOGO/d' vendor/oneplus/hotdogb/Android.mk
    sed -i '/logo/d' vendor/oneplus/hotdogb/Android.mk
fi

# 11. Build process
echo "Initializing fresh build target..."
make clobber || true
make installclean

# 🛑 ওয়ানপ্লাসের জন্য স্ট্যান্ডার্ড লাঞ্চ কমান্ড
lunch infinity_hotdogb-userdebug

m bacon -j$(nproc)
