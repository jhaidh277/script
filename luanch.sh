#!/bin/bash
set -e

# 1. System setup and dependencies
sudo apt update
sudo apt install patchelf ccache aria2 python3-venv ripgrep -y

# Setup Virtual Environment
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install telegram-upload

mkdir -p tmp
export CCACHE_DIR=tmp
export USE_CCACHE=1
ccache -M 50G
ccache -s

# 2. Cleanup old directories before building
rm -rf .repo/local_manifests/
rm -rf device/oneplus/hotdogb
rm -rf vendor/oneplus/hotdogb
rm -rf kernel/oneplus/sm8150

# 3. Repo initialization
repo init -u https://github.com/PixelOS-AOSP/android_manifest.git -b sixteen-qpr2 --git-lfs --depth=1

# 4. Local manifest clone
git clone https://github.com/mdnoyon80123/hotdogb_local_manifest-j --depth 1 -b main .repo/local_manifests

# 5. Source sync
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
/opt/crave/resync.sh

# 6. KernelSU integration
echo "Integrating KernelSU into the kernel source..."
pushd kernel/oneplus/sm8150
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s v0.9.5
popd

# 7. Environment configuration
export TARGET_RELEASE=trunk_staging
export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=none
export TARGET_MULTISIM_CONFIG=dsds
export KERNEL_SUPPORTS_KSU=true

source build/envsetup.sh

# 8. Clean up conflicts & Obsolete commands
echo "Checking for git conflicts..."
set +e # Temporarily disable 'set -e' so the script doesn't crash if no files are found

# Check and fix merge conflicts safely
CONF_FILES=$(rg -l '<<<<<<<|=======|>>>>>>>' device/oneplus/hotdogb 2>/dev/null || true)
if [ -n "$CONF_FILES" ]; then
    echo "$CONF_FILES" | xargs sed -i '/^<<<<<<< /d;/^=======/d;/^>>>>>>> /d'
    echo "Conflicts cleaned up successfully."
else
    echo "No conflicts found."
fi

# Fix obsolete lunch combo warning/error in Android 16+
if [ -f "device/oneplus/hotdogb/vendorsetup.sh" ]; then
    echo "Fixing obsolete add_lunch_combo in vendorsetup.sh..."
    sed -i 's/^add_lunch_combo/# add_lunch_combo/g' device/oneplus/hotdogb/vendorsetup.sh
fi

set -e # Re-enable strict error checking

# 9. Build process
make installclean
lunch aosp_hotdogb-trunk_staging-userdebug
m pixelos -j$(nproc --all)

# 10. Telegram Upload
set +e # Safely handle upload logic without crashing if compilation fails

# Re-activate virtual environment in case Crave sub-shell drops it
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
fi

ZIP_FILE=$(ls out/target/product/hotdogb/PixelOS_*.zip 2>/dev/null | head -n 1)

if [ -n "$ZIP_FILE" ] && [ -f "$ZIP_FILE" ]; then
    echo "Uploading build file to Telegram..."
    telegram-upload --to "me" --caption "PixelOS Build Completed for hotdogb! $(date)" "$ZIP_FILE"
    echo "Upload finished successfully!"
else
    echo "Error: Build failed or ZIP file not found in out/target/product/hotdogb/"
    ccache -s
    exit 1
fi

ccache -s
