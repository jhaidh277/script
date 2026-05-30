#!/bin/bash
set -e

# 1. System setup and dependencies
sudo apt update
sudo apt install patchelf ccache aria2 python3-pip -y
pip3 install telegram-upload
mkdir -p tmp
export CCACHE_DIR=tmp
export USE_CCACHE=1
ccache -M 50G
ccache -s

# 2. Cleanup
rm -rf .repo/local_manifests/
rm -rf device/oneplus/hotdogb
rm -rf vendor/oneplus/hotdogb
rm -rf kernel/oneplus/sm8150

# 3. Repo initialization
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault

# 4. Local manifest clone
git clone https://github.com/mdnoyon80123/hotdogb_local_manifest-j --depth 1 -b main .repo/local_manifests

# 5. Source sync
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
/opt/crave/resync.sh

# 6. KernelSU integration
echo "Integrating KernelSU into the kernel source..."
cd kernel/oneplus/sm8150
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s v0.9.5
cd ../../

# 7. Environment configuration
export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=none
export TARGET_MULTISIM_CONFIG=dsds
export KERNEL_SUPPORTS_KSU=true

source build/envsetup.sh

# 8. Clean up conflicts
rg -l -0 '<<<<<<<|=======|>>>>>>>' device/oneplus/hotdogb | xargs -0 sed -i '/^<<<<<<< /d;/^=======/d;/^>>>>>>> /d'

# 9. Build process
make installclean
lunch infinity_hotdogb-userdebug
m bacon -j$(nproc --all)

# 10. Telegram Upload
ZIP_FILE=$(ls out/target/product/hotdogb/*.zip | head -n 1)

if [ -f "$ZIP_FILE" ]; then
    echo "Uploading build file to Telegram..."
    telegram-upload --to "me" --caption "Infinity X Build Completed for hotdogb! $(date)" "$ZIP_FILE"
    echo "Upload finished successfully!"
else
    echo "Error: Build file not found."
    exit 1
fi

ccache -s
