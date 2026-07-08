#!/bin/bash

echo "=========================================================="
echo "🚀 Starting Fixed Build Script for Evolution-X (hotdogb)"
echo "=========================================================="

MAIN_DIR=$(pwd)

# ====================== BASIC SETUP ======================
export USE_CCACHE=0
export SKIP_VENDORSETUP=true
export ALLOW_MISSING_DEPENDENCIES=true
export SELINUX_IGNORE_NEVERALLOWS=true
export WITH_ADB_INSECURE=true
export TARGET_MULTISIM_CONFIG=dsds
export OVERRIDE_ANDROID_VERSION_CHECK=true

echo "🧹 Aggressive Cleanup..."

# লগ অনুসারে সমস্যাগুলো ক্লিন
rm -rf .repo/local_manifests
rm -rf device/oneplus/hotdogb device/oneplus/sm8150-common
rm -rf vendor/oneplus/hotdogb vendor/oneplus/sm8150-common
rm -rf vendor/extras/themes 2>/dev/null || true

# ====================== REPO INIT ======================
echo "📥 Repo Initialization..."
repo init --no-repo-verify --git-lfs \
    -u https://github.com/Evolution-X/manifest \
    -b cnb \
    --depth=1 || { echo "Repo init failed"; exit 1; }

# ====================== LOCAL MANIFEST ======================
echo "📂 Cloning Local Manifest..."
git clone https://github.com/jhaidh277/hotdogb_local_manifest \
    --depth 1 -b evo .repo/local_manifests || { echo "Local manifest failed"; exit 1; }

# ====================== SYNC ======================
echo "🔄 Syncing Sources..."
/opt/crave/resync.sh || echo "⚠️ Crave sync issue, continuing..."

# ====================== CRITICAL FIXES FROM LOG ======================

# 1. Themes Duplicate Fix
echo "🛠️ Fixing Duplicate Theme Modules..."
if [ -d "vendor/extras" ]; then
    mv vendor/extras/themes vendor/extras/themes_backup_$(date +%s) 2>/dev/null || true
fi

# 2. Common Android.bp duplicate fix
echo "🛠️ Fixing other duplicate modules..."
find . -name "Android.bp" | xargs sed -i 's/IconPack.*Overlay/IconPackFixed_/g' 2>/dev/null || true
find . -name "Android.bp" | xargs sed -i 's/ClockFont.*Overlay/ClockFontFixed_/g' 2>/dev/null || true

# 3. Hardware qcom duplicate fix
sed -i '/libOmxVdec/d' hardware/qcom-caf/sdm845/media/mm-video-v4l2/vidc/vdec/Android.bp 2>/dev/null || true

# ====================== KERNELSU ======================
if [ -d "kernel/oneplus/sm8150" ]; then
    echo "🔧 Enabling KernelSU..."
    cd kernel/oneplus/sm8150
    find arch/arm64/configs/ -name "*defconfig" | while read config; do
        sed -i '/CONFIG_KERNELSU/d' "$config"
        echo "CONFIG_KERNELSU=y" >> "$config"
    done
    cd "$MAIN_DIR"
fi

# ====================== SOURCE BUILD ENV ======================
echo "🌍 Sourcing build/envsetup.sh..."
source build/envsetup.sh || { echo "Envsetup failed"; exit 1; }

# ====================== LUNCH (সংশোধিত) ======================
echo "🍱 Lunching device..."
if ! lunch evolution_hotdogb-userdebug && ! lunch hotdogb-userdebug; then
    echo "❌ Lunch failed. Check if device tree is correct."
    exit 1
fi

# ====================== FINAL BUILD ======================
echo "🔨 Starting compilation..."
make installclean -j$(nproc) || true

# সঠিক বিল্ড কমান্ড
m evolution -j$(nproc) 2>&1 | tee build.log

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "🎉 BUILD SUCCESSFUL!"
else
    echo "❌ Build failed. Check build.log"
    echo "সাজেশন: যদি আবার duplicate error আসে তাহলে vendor/extras/themes_backup ফোল্ডার ডিলিট করুন।"
fi
