#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e


# CCACHE configuration
mkdir -p /tmp/ccache
export CCACHE_DIR=/tmp/ccache
export USE_CCACHE=1
ccache -M 50G
ccache -s

# 2. Hard Clean: Remove everything to fix corrupted directories
echo "Performing a deep clean..."
rm -rf .repo/
rm -rf device/oneplus/hotdogb
rm -rf vendor/oneplus/hotdogb
rm -rf kernel/oneplus/sm8150

# 3. Repo initialization (Fresh start)
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault

# 4. Fix hooks and ensure directory structure exists
echo "Ensuring repo directory structure..."
mkdir -p .repo/repo/hooks

# 5. Local manifest clone (আপনার সঠিক রেপো এবং 'op' ব্রাঞ্চ এড করা হয়েছে)
git clone https://github.com/jhaidh277/hotdogb_local_manifest --depth 1 -b op .repo/local_manifests

# 6. Source sync
/opt/crave/resync.sh
repo sync -c -j$(nproc) --force-sync --no-clone-bundle --no-tags --detach

# 7. KernelSU integration (সমস্যা সমাধান করতে এটিকে কমেন্ট আউট করা হলো)
echo "Skipping manual KernelSU integration to avoid conflicts..."
# pushd kernel/oneplus/sm8150
# curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s v0.9.5
# popd

# 8. Environment configuration
export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=none
export TARGET_MULTISIM_CONFIG=dsds
export KERNEL_SUPPORTS_KSU=true
source build/envsetup.sh

# 9. Modify the GSI Android.bp file to remove Calendar entry
sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp

# 10. Clean up conflicts
rg -l -0 '<<<<<<<|=======|>>>>>>>' device/oneplus/hotdogb | xargs -0 sed -i '/^<<<<<<< /d;/^=======/d;/^>>>>>>> /d' || true

# 11. Build process
make installclean
lunch infinity_hotdogb-userdebug
m bacon -j$(nproc)
