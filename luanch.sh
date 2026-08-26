#!/bin/bash
set -e

echo "=========================================================="
echo "🚀 Complete Bootable Build Script with KernelSU - OnePlus 7T"
echo "=========================================================="

MAIN_DIR=$(pwd)

# 🕒 Local TimeZone Setup
sudo rm -f /etc/localtime
sudo ln -s /usr/share/zoneinfo/Asia/Dhaka /etc/localtime

export USE_CCACHE=0
export NOMINATIVE_CCACHE=1
export SKIP_VENDORSETUP=true

echo "🧹 Clearing previous build artifacts and directories..."
rm -rf out/
rm -rf .repo/local_manifests || true
rm -rf device/oneplus/hotdogb device/oneplus/sm8150-common vendor/oneplus/hotdogb vendor/oneplus/sm8150-common kernel/oneplus/sm8150 hardware/oplus hardware/dolby || true

echo "📥 Initializing repo for Project Infinity-X..."
repo init --depth=1 -u https://github.com/ProjectInfinity-X/manifest -b 16 --git-lfs || true

echo "📥 Creating local manifest..."
mkdir -p .repo/local_manifests
cat << 'EOF' > .repo/local_manifests/roomservice.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <project name="jhaidh277/android_device_oneplus_hotdogb" path="device/oneplus/hotdogb" remote="github" revision="infinity" />
  <project name="jhaidh277/android_device_oneplus_sm8150-common" path="device/oneplus/sm8150-common" remote="github" revision="lineage-23.2" />
  <project name="jhaidh277/android_kernel_oneplus_sm8150" path="kernel/oneplus/sm8150" remote="github" revision="16.0" />
  <project path="vendor/oneplus/hotdogb" name="TheMuppets/proprietary_vendor_oneplus_hotdogb" remote="github" revision="lineage-23.2" />
  <project path="vendor/oneplus/sm8150-common" name="TheMuppets/proprietary_vendor_oneplus_sm8150-common" remote="github" revision="lineage-23.2" />
  <project path="hardware/oplus" name="LineageOS/android_hardware_oplus" remote="github" revision="lineage-23.2" />
</manifest>
EOF

echo "🔄 Syncing sources via Crave resync..."
/opt/crave/resync.sh || echo "⚠️ Crave resync completed with warnings..."

# ============================================================
# 🧬 KernelSU Integration (Clean Setup)
# ============================================================
echo "🧬 Patching KernelSU into Kernel Source..."
if [ -d "kernel/oneplus/sm8150" ]; then
    cd kernel/oneplus/sm8150
    curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash - || true
    
    # Enable KernelSU configs in defconfig
    find arch/arm64/configs/ -type f -name "*defconfig" | while read -r defconfig; do
        sed -i '/CONFIG_KSU/d' "$defconfig" || true
        echo "CONFIG_KSU=y" >> "$defconfig"
        echo "CONFIG_KSU_OVERLAYFS_ON_KSU=y" >> "$defconfig"
    done
    cd "$MAIN_DIR"
fi

# ============================================================
# 📥 SAFE GIT CLONE: hardware/dolby
# ============================================================
echo "📥 Cloning hardware_dolby_lunaris..."
rm -rf hardware/dolby || true
git clone --depth=1 https://github.com/jhaidh277/hardware_dolby_lunaris.git -b 16 hardware/dolby

# ============================================================
# 🛡️ VENDOR NAMESPACE FIX
# ============================================================
echo "🛡️ Fixing vendor namespace conflicts..."
rm -f vendor/oneplus/hotdogb/Android.bp || true
rm -f vendor/oneplus/sm8150-common/Android.bp || true

VENDOR_MAKEFILE="vendor/oneplus/hotdogb/hotdogb-vendor.mk"
if [ ! -f "$VENDOR_MAKEFILE" ] && [ -d "vendor/oneplus/hotdogb" ]; then
    echo "⚠️ hotdogb-vendor.mk missing. Creating fallback."
    touch "$VENDOR_MAKEFILE"
fi

# ============================================================
# 🩹 SELINUX PERMISSIVE FIX (বুটলোপ ও ক্র্যাশ ঠেকানোর জন্য)
# ============================================================
BOARD_COMMON="device/oneplus/sm8150-common/BoardConfigCommon.mk"
if [ -f "$BOARD_COMMON" ]; then
    echo "🩹 Setting SELinux to Permissive..."
    grep -q "androidboot.selinux=permissive" "$BOARD_COMMON" || echo 'BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive' >> "$BOARD_COMMON"
fi

rm -f device/oneplus/hotdogb/vendorsetup.sh 2>/dev/null || true
rm -f device/oneplus/sm8150-common/vendorsetup.sh 2>/dev/null || true

export BUILD_USERNAME=Jihad
export BUILD_HOSTNAME=crave

echo "📦 Sourcing build/envsetup.sh..."
source build/envsetup.sh

echo "🍽️ Lunching target..."
if lunch infinity_hotdogb-userdebug; then
    echo "✅ Lunched infinity_hotdogb-userdebug"
elif lunch lineage_hotdogb-userdebug; then
    echo "✅ Lunched lineage_hotdogb-userdebug"
elif lunch hotdogb-userdebug; then
    echo "✅ Lunched hotdogb-userdebug"
else
    echo "❌ All lunch targets failed."
    exit 1
fi

echo "🧹 Running installclean..."
make installclean || true

echo "🏗️ Building ROM..."
m bacon
