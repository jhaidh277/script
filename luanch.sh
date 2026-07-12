#!/bin/bash

set -e

echo "=========================================================="
echo "🚀 Infinity‑X Build for Beryl (Xiaomi Mi A2)"
echo "=========================================================="

# ১. মেইন পাথ set
MAIN_DIR=$(pwd)

# ২. Environment configuration
export USE_CCACHE=0
export SKIP_VENDORSETUP=true

export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=true
export TARGET_MULTISIM_CONFIG=dsds

# Android 16/trunk staging flags (Infinity‑X)
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

# ৩. আগের device tree cleanup
echo "🧹 Cleaning up directories..."
rm -rf .repo/local_manifests || true
rm -rf device/xiaomi/beryl \
       device/xiaomi/beryl-kernel \
       vendor/xiaomi/beryl \
       kernel/xiaomi/beryl \
       kernel/xiaomi/msm8996 || true

# ৪. Repo init (Infinity‑X manifest)
echo "📥 Running repo init for Infinity‑X (branch 16)..."
repo init --no-repo-verify --git-lfs \
          -u https://github.com/ProjectInfinity-X/manifest \
          -b 16 \
          -g default,-mips,-darwin,-notdefault \
          --depth 1 || true

mkdir -p .repo/repo/hooks || true

# ৫. Local manifest (Beryl‑specific)
# যদি তোমার থাকা local_manifest Beryl‑এর না হয়, 
# এটা clone না করে নিজের manifest folder manual add করো।
echo "📥 Cloning local manifest for beryl..."
git clone https://github.com/jhaidh277/hotdogb_local_manifest \
          --depth 1 \
          -b beryl \
          .repo/local_manifests || true

# ৬. Source sync (Crave বা repo sync)
if [ -x /opt/crave/resync.sh ]; then
    echo "🔄 Syncing sources via Crave resync..."
    /opt/crave/resync.sh || echo "⚠️ Crave resync flagged an issue, but proceeding..."

# ৮. envsetup
echo "📦 Sourcing build/envsetup.sh ..."
if ! source build/envsetup.sh; then
    echo "❌ Failed to source build/envsetup.sh"
    exit 1
fi

# ৯. GSI cleanup (ish)
if [ -f build/make/target/product/gsi/Android.bp ]; then
    echo "🧹 Cleaning known problematic entries from GSI Android.bp (Calendar, if present)..."
    sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp || true
fi

# ১০. Lunch attempt (Infinity‑X / lineage / vanilla)
echo "🍽️ Trying to lunch infinity_beryl ..."
if ! lunch infinity_beryl-userdebug; then
    if ! lunch lineage_beryl-userdebug; then
        if ! lunch beryl-userdebug; then
            echo "⚠️ Lunch failed for all combinations. Check your device tree and manifest."
            exit 1
        fi
    fi
fi

# ১১. installclean
echo "🧼 Running installclean..."
make installclean || true

# ১২. Final build
echo "🏗️ Starting Infinity‑X build for beryl..."
m bacon -j$(nproc)

echo "=========================================================="
echo "✅ Build script finished (check above for any errors)."
echo "=========================================================="
