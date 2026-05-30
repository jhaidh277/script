#!/bin/bash
set -e

# Start timer
start=$(date +%s)

# Update system and install dependencies
sudo apt update
sudo apt install patchelf ccache aria2 -y # Added aria2 for faster sync
mkdir -p tmp
export CCACHE_DIR=tmp
export USE_CCACHE=1
ccache -M 50G
ccache -s

# Clean old directories
rm -rf .repo/local_manifests/
rm -rf device/oneplus/hotdogb
rm -rf vendor/oneplus/hotdogb
rm -rf kernel/oneplus/sm8150

# Repo initialization
repo init -u https://github.com/PixelOS-AOSP/android_manifest.git -b sixteen-qpr2 --git-lfs --depth=1

# Clone local manifest
git clone https://github.com/mdnoyon80123/hotdogb_local_manifest-j --depth 1 -b main .repo/local_manifests

# Source sync (Using --jobs for faster sync)
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
/opt/crave/resync.sh

# Automate KernelSU integration
echo "Integrating KernelSU into the kernel source..."
cd kernel/oneplus/sm8150
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s v0.9.5
cd ../../

# Add Dolby support (Example: Clone if not in manifest)
# git clone https://github.com/your-dolby-repo hardware/dolby

# Environment configuration
export TARGET_RELEASE=trunk_staging
export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=none
export TARGET_MULTISIM_CONFIG=dsds
export KERNEL_SUPPORTS_KSU=true

source build/envsetup.sh

# Remove merge conflicts
rg -l -0 '<<<<<<<|=======|>>>>>>>' device/oneplus/hotdogb | xargs -0 sed -i '/^<<<<<<< /d;/^=======/d;/^>>>>>>> /d'

# Clean and Build
make installclean
lunch aosp_hotdogb-trunk_staging-userdebug

# Build with progress indicator
m pixelos -j$(nproc --all)

# Build Time End
end=$(date +%s)
echo "Build completed in $(( (end - start) / 60 )) minutes."

# Ccache status and upload
ccache -s
curl -sf https://raw.githubusercontent.com/jayz1212/build/refs/heads/main/tar.sh | bash
