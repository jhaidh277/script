#!/bin/bash
set -e

echo "=========================================================="
echo "🚀 Infinity‑X Build for Beryl (redmi note 14 5g)"
echo "=========================================================="

MAIN_DIR=$(pwd)

export USE_CCACHE=0
export SKIP_VENDORSETUP=true
export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=true
export TARGET_MULTISIM_CONFIG=dsds
export TARGET_RELEASE=trunk_staging
export ALLOW_MISSING_DEPENDENCIES=true
export ALLOW_RELEASE_CONFIG_MIXED_TYPES=true
export TARGET_RELEASE_CONFIG_BUILD_FLAVOR=default
export BUILD_WITHOUT_SU=true
export OVERRIDE_ANDROID_VERSION_CHECK=true
export WITHOUT_SU=true
export PRODUCT_ARGUMENT_VALIDATION=false
export FORCE_BUILD_NOTICES=false
export SKIP_NOTICE_BUILD=true
export OVERRIDE_NOTICE_FIELDS=true

if ! command -v ccache >/dev/null 2>&1; then
    export USE_CCACHE=0
fi

echo "🧹 Cleaning up directories..."
rm -rf .repo/local_manifests || true
rm -rf .repo/projects/device_xiaomi_beryl-kernel.git || true
rm -rf .repo/projects/vendor_xiaomi_beryl.git || true
rm -rf .repo/project-objects/device_xiaomi_beryl-kernel.git || true
rm -rf .repo/project-objects/vendor_xiaomi_beryl.git || true

echo "📥 Running repo init for Infinity-X (branch 16)..."
repo init --no-repo-verify --git-lfs \
          -u https://github.com/ProjectInfinity-X/manifest \
          -b 16 \
          -g default,-mips,-darwin,-notdefault \
          --depth 1 || true

mkdir -p .repo/repo/hooks || true

echo "📥 Cloning local manifest for beryl..."
git clone https://github.com/jhaidh277/hotdogb_local_manifest \
          --depth 1 \
          -b beryl \
          .repo/local_manifests || true

if [ -x /opt/crave/resync.sh ]; then
    echo "🔄 Syncing sources via Crave resync..."
    /opt/crave/resync.sh || echo "⚠️ Crave resync flagged an issue, but proceeding..."
fi

echo "🔧 Fixing manifest branches..."
if [ -d .repo/local_manifests ]; then
    find .repo/local_manifests -type f -name "*.xml" -exec sed -i \
        -e 's/revision="lineage-22.2"/revision="alpha-15.2"/g' \
        -e 's/branch="lineage-22.2"/branch="alpha-15.2"/g' {} +
fi

echo "🔄 Syncing sources..."
repo sync -j1 --fail-fast --force-sync --no-tags --current-branch || exit 1

echo "📦 Sourcing build/envsetup.sh ..."
if ! source build/envsetup.sh; then
    echo "❌ Failed to source build/envsetup.sh"
    exit 1
fi

if [ -f build/make/target/product/gsi/Android.bp ]; then
    echo "🧹 Cleaning known problematic entries from GSI Android.bp (Calendar, if present)..."
    sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp || true
fi

echo "🧼 Removing duplicate protobuf vendorcompat modules..."
if [ -f hardware/lineage/compat/Android.bp ]; then
    sed -i '/prebuilt_libprotobuf-cpp-full-3.9.1-vendorcompat/,/}/d' hardware/lineage/compat/Android.bp || true
    sed -i '/prebuilt_libprotobuf-cpp-lite-3.9.1-vendorcompat/,/}/d' hardware/lineage/compat/Android.bp || true
    sed -i '/prebuilt_libprotobuf-cpp-full-21.12-vendorcompat/,/}/d' hardware/lineage/compat/Android.bp || true
    sed -i '/prebuilt_libprotobuf-cpp-lite-21.12-vendorcompat/,/}/d' hardware/lineage/compat/Android.bp || true
fi

echo "🍽️ Trying to lunch infinity_beryl ..."
if ! lunch infinity_beryl-userdebug; then
    if ! lunch lineage_beryl-userdebug; then
        if ! lunch beryl-userdebug; then
            echo "⚠️ Lunch failed for all combinations. Check your device tree and manifest."
            exit 1
        fi
    fi
fi

echo "🧼 Running installclean..."
make installclean || true

echo "🏗️ Starting Infinity-X build for beryl..."
m bacon -j$(nproc)

echo "=========================================================="
echo "✅ Build script finished (check above for any errors)."
echo "=========================================================="
