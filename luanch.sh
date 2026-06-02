#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. System setup and dependencies
sudo apt update
sudo apt install patchelf ccache aria2 python3-pip ripgrep bc bison build-essential curl flex g++-multilib gcc-multilib git gnupg gperf imagemagick lib32ncurses5-dev lib32readline-dev lib32z1-dev libelf-dev liblz4-tool libncurses5 libncurses5-dev libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev -y
pip3 install telegram-upload --break-system-packages

# CCACHE configuration
mkdir -p /tmp/ccache
export CCACHE_DIR=/tmp/ccache
export USE_CCACHE=1
ccache -M 50G
ccache -s

# 2. Hard Clean
echo "Performing a deep clean..."
rm -rf .repo/local_manifests
rm -rf device/oneplus/hotdogb
rm -rf vendor/oneplus/hotdogb
rm -rf kernel/oneplus/sm8150

# 3. Repo initialization
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault

# 4. Local manifest clone (image_20.png অনুযায়ী op ব্রাঞ্চ)
git clone https://github.com/jhaidh277/hotdogb_local_manifest --depth 1 -b op .repo/local_manifests

# 5. Source sync with retry mechanism
echo "Starting Source Sync..."
until repo sync -c -j$(nproc) --force-sync --no-clone-bundle --no-tags --detach; do
  echo "Sync failed, retrying in 5 seconds..."
  sleep 5
done

# 6. KernelSU integration
echo "Integrating KernelSU..."
pushd kernel/oneplus/sm8150
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s v0.9.5
popd

# 7. Configure OnePlus features, Dual SIM, and Dolby
echo "Configuring OnePlus features, Dual SIM support, and Dolby..."
DEVICE_MK="device/oneplus/hotdogb/device.mk"
{
    echo ""
    echo "# OnePlus Features (Added by script)"
    echo "\$(call inherit-product-if-exists, vendor/oneplus/camera/config.mk)"
    echo "PRODUCT_PACKAGES += GameSpace"
    echo ""
    echo "# Dolby Sound Support"
    echo "\$(call inherit-product-if-exists, vendor/dolby/config.mk)"
    echo ""
    echo "# Dual SIM Support"
    echo "TARGET_MULTISIM_CONFIG := dsds"
    echo "PRODUCT_PROPERTY_OVERRIDES += persist.radio.multisim.config=dsds"
} >> $DEVICE_MK

# 8. Environment configuration
export BUILD_USERNAME=Jihad
export BUILD_HOSTNAME=Crave-Server
export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=none
export TARGET_MULTISIM_CONFIG=dsds
export KERNEL_SUPPORTS_KSU=true
export ALLOW_MISSING_DEPENDENCIES=true
source build/envsetup.sh

# 9. Clean up conflicts
rg -l -0 '<<<<<<<|=======|>>>>>>>' device/oneplus/hotdogb | xargs -0 sed -i '/^<<<<<<< /d;/^=======/d;/^>>>>>>> /d' || true

# 10. Build process
lunch infinity_hotdogb-userdebug
make installclean
m bacon -j$(nproc)

echo "Build Finished Successfully!"
