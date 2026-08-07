#!/bin/bash

set -e

echo "=========================================================="
echo "🚀 Starting Build Script for Project Infinity-X - OnePlus 7T (hotdogb)"
echo "=========================================================="

MAIN_DIR=$(pwd)
export USE_CCACHE=0
export NOMINATIVE_CCACHE=1
export SKIP_VENDORSETUP=true

echo "🧹 Force cleaning corrupted directories..."
rm -rf .repo/local_manifests || true

echo "📥 Initializing repo for Project Infinity-X..."
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault --depth 1 || true
  
echo "📥 Cloning local manifest from GitHub..."
git clone https://github.com/jhaidh277/hotdogb_local_manifest -b infinity .repo/local_manifests || true
  
echo "🔄 Syncing sources via Crave resync..."
/opt/crave/resync.sh || echo "⚠️ Crave resync flagged an issue, but proceeding anyway..."

# ------------------------------------------------------------
# 🩹 FIX: Remove duplicate protobuf modules in hardware/lineage/compat/Android.bp
# ------------------------------------------------------------
BP1="hardware/lineage/compat/Android.bp"
if [ -f "$BP1" ]; then
    echo "🩹 Fixing duplicate protobuf modules in $BP1..."
    sed -i '/prebuilt_libprotobuf-cpp-full-3.9.1-vendorcompat/,/^}/d' "$BP1" || true
    sed -i '/prebuilt_libprotobuf-cpp-lite-3.9.1-vendorcompat/,/^}/d' "$BP1" || true
    sed -i '/prebuilt_libprotobuf-cpp-full-21.12-vendorcompat/,/^}/d' "$BP1" || true
    sed -i '/prebuilt_libprotobuf-cpp-lite-21.12-vendorcompat/,/^}/d' "$BP1" || true
fi

# KernelSU
if [ -d "kernel/oneplus/sm8150" ]; then
    echo "🧬 Applying KernelSU..."
    cd kernel/oneplus/sm8150
    find arch/arm64/configs/ -type f -name "*defconfig" | while read -r defconfig; do
        sed -i '/CONFIG_KERNELSU/d' "$defconfig" || true
        echo "CONFIG_KERNELSU=y" >> "$defconfig"
    done
    cd "$MAIN_DIR"
fi

echo "📦 Sourcing build/envsetup.sh..."
source build/envsetup.sh

if [ -f build/make/target/product/gsi/Android.bp ]; then
    sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp || true
fi

echo "🍽️ Lunching Project Infinity-X target..."
lunch infinity_hotdogb-userdebug || true

echo "🧹 Running installclean..."
make installclean || true

echo "🏗️ Building Project Infinity-X ROM (m bacon)..."
m bacon 

echo "=========================================================="
echo "✅ Project Infinity-X Build script finished successfully."
echo "=========================================================="
