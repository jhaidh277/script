#!/bin/bash

echo "=========================================================="
echo "🚀 Starting All-Fixed Build Script for Evolution-X hotdogb"
echo "=========================================================="

MAIN_DIR=$(pwd)

# ====================== ULTRA CLEAN ======================
echo "🧹 Cleanup..."
# আপনি যে ডিলিট কমান্ডগুলো নির্দেশ করেছিলেন:
rm -rf vendor/extras/themes* 2>/dev/null || true
rm -rf device/oneplus/hotdogb* vendor/oneplus/hotdogb* 2>/dev/null || true
rm -rf .repo/local_manifests

# ====================== REPO INIT ======================
echo "📥 Repo Initialization..."
repo init --no-repo-verify --git-lfs \
    -u https://github.com/Evolution-X/manifest -b cnb --depth=1 || { echo "❌ Init failed"; exit 1; }

# ====================== LOCAL MANIFEST ======================
echo "📂 Local Manifest..."
git clone https://github.com/jhaidh277/hotdogb_local_manifest \
    --depth 1 -b evo .repo/local_manifests || true

# ====================== SYNC ======================
echo "🔄 Force Sync..."
/opt/crave/resync.sh || echo "⚠️ Crave warning..."

# ====================== FIXES ======================
echo "🛠 Applying All Fixes..."

# Themes Duplicate Fix
rm -rf vendor/extras/themes 2>/dev/null || true

# Create missing Evolution config
mkdir -p vendor/evolution/config
echo "# Common Evolution config" > vendor/evolution/config/common_full_phone.mk 2>/dev/null || true

# Source env
source build/envsetup.sh || { echo "❌ Envsetup failed"; exit 1; }

# Lunch (আপনার দেওয়া নির্দিষ্ট কমান্ড)
echo "🍱 Lunching..."
lunch lineage_hotdogb-bp4a-userdebug || { echo "❌ Lunch failed"; exit 1; }

# Build
echo "🔨 Starting Build..."
make installclean -j$(nproc) || true
m evolution -j$(nproc) 2>&1 | tee build.log

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "🎉 BUILD SUCCESSFUL!"
else
    echo "❌ Build failed. Send last 100 lines of build.log"
fi
