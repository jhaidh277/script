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

# --- Helper functions ---
safe_remove_block() {
    local file="$1"
    local needle="$2"
    [ -f "$file" ] || return 0
    python3 - "$file" "$needle" <<'PY'
import sys
path, needle = sys.argv[1], sys.argv[2]
with open(path, 'r', encoding='utf-8', errors='ignore') as f:
    lines = f.readlines()
out = []
i = 0
n = len(lines)
while i < n:
    if needle in lines[i]:
        depth = 0
        started = False
        while i < n:
            line = lines[i]
            depth += line.count('{')
            depth -= line.count('}')
            started = True
            i += 1
            if started and depth <= 0 and line.strip().endswith('}'):
                break
        continue
    out.append(lines[i])
    i += 1
with open(path, 'w', encoding='utf-8') as f:
    f.writelines(out)
PY
}

remove_line_contains() {
    local file="$1"
    local pattern="$2"
    [ -f "$file" ] && sed -i "\|$pattern|d" "$file" || true
}

fix_android_products_mk() {
    local file="$1"
    local device="$2"
    [ -d "$(dirname "$file")" ] || return 0
    python3 - "$file" "$device" <<'PY'
import sys, os
file_path, device = sys.argv[1], sys.argv[2]
os.makedirs(os.path.dirname(file_path), exist_ok=True)
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(f'PRODUCT_MAKEFILES := $(LOCAL_DIR)/{device}.mk\n\nCOMMON_LUNCH_CHOICES := {device}-user {device}-userdebug {device}-eng\n')
PY
}

echo "🧹 Cleaning local manifests..."
rm -rf .repo/local_manifests .repo/local_manifest.xml || true

echo "🧹 Cleaning up output directories..."
rm -rf out/soong out/.module_paths out/target out/obj out/build.ninja || true

echo "📥 Running repo init for Infinity-X (branch 16)..."
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault --depth 1

mkdir -p .repo/repo/hooks || true

echo "📥 Cloning local manifest for beryl..."
rm -rf .repo/local_manifests
git clone https://github.com/jhaidh277/hotdogb_local_manifest --depth 1 -b beryl .repo/local_manifests

if [ -x /opt/crave/resync.sh ]; then
    echo "🔄 Syncing sources via Crave resync..."
    /opt/crave/resync.sh
fi

echo "📦 Sourcing build/envsetup.sh ..."
source build/envsetup.sh

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
for file in "hardware/lineage/compat/Android.bp" "prebuilts/misc/protobuf_vendorcompat/Android.bp"; do
    safe_remove_block "$file" "prebuilt_libprotobuf-cpp-full-3.9.1-vendorcompat"
    safe_remove_block "$file" "prebuilt_libprotobuf-cpp-lite-3.9.1-vendorcompat"
    safe_remove_block "$file" "prebuilt_libprotobuf-cpp-full-21.12-vendorcompat"
    safe_remove_block "$file" "prebuilt_libprotobuf-cpp-lite-21.12-vendorcompat"
done

echo "🧼 Fixing vendor/xiaomi/beryl and sensors namespace..."
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

echo "🍽️ Trying to lunch infinity_beryl ..."
lunch infinity_beryl-userdebug

echo "🏗️ Starting Infinity-X build..."
m bacon -j$(nproc)
