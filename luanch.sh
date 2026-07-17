#!/bin/bash

set -e

echo "=========================================================="
echo "🚀 Infinity‑X Build for Beryl (redmi note 14 5g)"
echo "=========================================================="

MAIN_DIR=$(pwd)

# ---------------------------------------------------------
# 1. Environment basics
# ---------------------------------------------------------

export USE_CCACHE=0
export NOMINATIVE_CCACHE=1
export SKIP_VENDORSETUP=true

export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=false
export TARGET_MULTISIM_CONFIG=dsds

echo "⚙️  Basic environment configured."

echo "🧹 Cleaning local manifests..."
rm -rf .repo/local_manifests .repo/local_manifest.xml || true

echo "🧹 Cleaning up output directories..."
rm -rf out/soong out/.module_paths out/target out/obj out/build.ninja || true

echo "📥 Running repo init for Infinity-X (branch 16)..."
repo init --no-repo-verify --git-lfs \
          -u https://github.com/ProjectInfinity-X/manifest \
          -b 16 \
          -g default,-mips,-darwin,-notdefault \
          --depth 1

mkdir -p .repo/repo/hooks || true

echo "📥 Cloning local manifest for beryl..."
rm -rf .repo/local_manifests
git clone https://github.com/jhaidh277/hotdogb_local_manifest \
          --depth 1 \
          -b beryl \
          .repo/local_manifests

if [ -x /opt/crave/resync.sh ]; then
    echo "🔄 Syncing sources via Crave resync..."
    /opt/crave/resync.sh
fi

echo "📦 Sourcing build/envsetup.sh ..."
export TOP="$MAIN_DIR"
if [ -f build/envsetup.sh ]; then
    # shellcheck disable=SC1091
    source build/envsetup.sh
else
    echo "❌ Failed to find build/envsetup.sh"
    exit 1
fi

echo "🧩 Fixing AndroidProducts.mk for infinity_beryl..."
fix_android_products_mk "device/xiaomi/beryl/AndroidProducts.mk" "infinity_beryl"

echo "🧩 Creating missing kernel module list files..."
mkdir -p device/xiaomi/beryl-kernel
: > device/xiaomi/beryl-kernel/modules.load
: > device/xiaomi/beryl-kernel/modules.load.vendor_ramdisk
: > device/xiaomi/beryl-kernel/modules.load.recovery

echo "🧼 Removing GSI Calendar entry..."
if [ -f build/make/target/product/gsi/Android.bp ]; then
    remove_line_contains "build/make/target/product/gsi/Android.bp" "Calendar"
fi

echo "🧼 Removing duplicate protobuf vendorcompat modules..."
safe_remove_block "hardware/lineage/compat/Android.bp" "prebuilt_libprotobuf-cpp-full-3.9.1-vendorcompat"
safe_remove_block "hardware/lineage/compat/Android.bp" "prebuilt_libprotobuf-cpp-lite-3.9.1-vendorcompat"
safe_remove_block "hardware/lineage/compat/Android.bp" "prebuilt_libprotobuf-cpp-full-21.12-vendorcompat"
safe_remove_block "hardware/lineage/compat/Android.bp" "prebuilt_libprotobuf-cpp-lite-21.12-vendorcompat"
safe_remove_block "prebuilts/misc/protobuf_vendorcompat/Android.bp" "prebuilt_libprotobuf-cpp-full-3.9.1-vendorcompat"
safe_remove_block "prebuilts/misc/protobuf_vendorcompat/Android.bp" "prebuilt_libprotobuf-cpp-lite-3.9.1-vendorcompat"
safe_remove_block "prebuilts/misc/protobuf_vendorcompat/Android.bp" "prebuilt_libprotobuf-cpp-full-21.12-vendorcompat"
safe_remove_block "prebuilts/misc/protobuf_vendorcompat/Android.bp" "prebuilt_libprotobuf-cpp-lite-21.12-vendorcompat"

echo "🧼 Fixing vendor/xiaomi/beryl namespace and removing errors..."
if [ -f vendor/xiaomi/beryl/Android.bp ]; then
    remove_line_contains "vendor/xiaomi/beryl/Android.bp" "hardware/lineage/interfaces/power"
    remove_line_contains "vendor/xiaomi/beryl/Android.bp" "hardware/lineage/compat"
    sed -i 's#hardware/lineage/interfaces/power-libperfmgr#hardware/lineage/interfaces/power#g' vendor/xiaomi/beryl/Android.bp || true
fi

if [ -f hardware/mediatek/sensors/Android.bp ]; then
    remove_line_contains "hardware/mediatek/sensors/Android.bp" "hardware/lineage/interfaces/power"
    remove_line_contains "hardware/mediatek/sensors/Android.bp" "hardware/lineage/compat"
    safe_remove_block "hardware/mediatek/sensors/Android.bp" "android.hardware.sensors@2.0-subhal-impl-1.0"
fi

echo "🧼 Cleaning stale soong output..."
rm -rf out/soong out/.module_paths out/build.ninja || true

echo "🍽️ Trying to lunch infinity_beryl ..."
LUNCH_OK=0
for TARGET in infinity_beryl-user infinity_beryl-userdebug infinity_beryl-eng; do
    if lunch "$TARGET" >/dev/null 2>&1; then
        echo "Using lunch target: $TARGET"
        LUNCH_OK=1
        break
    fi
done

if [ "$LUNCH_OK" -ne 1 ]; then
    echo "⚠️ Lunch failed for all combinations. Check your device tree and AndroidProducts.mk."
    exit 1
fi

echo "🧼 Running installclean..."
make installclean || true

echo "🏗️ Starting Infinity-X build for beryl..."
if command -v m >/dev/null 2>&1; then
    m bacon -j"$(nproc)"
else
    make bacon -j"$(nproc)"
fi

if ls out/target/product/*/*.zip >/dev/null 2>&1; then
    echo "✅ Build artifact found."
else
    echo "⚠️ No build zip found yet. Check log: $LOG_FILE"
fi

echo "=========================================================="
echo "✅ Build script finished (check above for any errors)."
echo "Log: $LOG_FILE"
echo "=========================================================="
