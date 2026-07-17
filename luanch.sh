#!/bin/bash
set -euo pipefail

echo "=========================================================="
echo "🚀 Infinity‑X Build for Beryl (redmi note 14 5g)"
echo "=========================================================="

MAIN_DIR="$(pwd)"
LOG_DIR="$MAIN_DIR/output_logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/build_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee "$LOG_FILE") 2>&1

# ========= Env vars =========
export USE_CCACHE=0          # আমরা ccache force বন্ধ রাখছি
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

# ========= ccache workaround =========
if command -v ccache >/dev/null 2>&1; then
    echo "✅ Real ccache found, enabling it."
    export USE_CCACHE=1
    export CCACHE_EXEC="$(command -v ccache)"
else
    echo "⚠️ ccache not found, using stub to satisfy envsetup.sh."
    # envsetup.sh শুধু command আছে কি না দেখলে, এই alias সেটি pass করবে
    alias ccache='echo "ccache stub (no real caching)"; true'
    export USE_CCACHE=0
fi

# ========= helper ফাংশন =========
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

content = f'''PRODUCT_MAKEFILES := \\
    $(LOCAL_DIR)/{device}.mk

COMMON_LUNCH_CHOICES := \\
    {device}-user \\
    {device}-userdebug \\
    {device}-eng
'''

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
PY
}

# ========= clean local manifest + out =========
echo "🧹 Cleaning local manifests..."
rm -rf .repo/local_manifests .repo/local_manifest.xml || true

echo "🧹 Cleaning up output directories..."
rm -rf out/soong out/.module_paths out/target out/obj out/build.ninja || true

# ========= repo init + local manifest =========
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

# ========= envsetup =========
echo "📦 Sourcing build/envsetup.sh ..."
if [ -f build/envsetup.sh ]; then
    # shellcheck disable=SC1091
    source build/envsetup.sh
else
    echo "❌ Failed to find build/envsetup.sh"
    exit 1
fi

# ========= AndroidProducts.mk auto-fix =========
echo "🧩 Fixing AndroidProducts.mk for infinity_beryl..."
fix_android_products_mk "device/xiaomi/beryl/AndroidProducts.mk" "infinity_beryl"

# ========= kernel modules.load fix =========
echo "🧩 Creating missing kernel module list files..."
mkdir -p device/xiaomi/beryl-kernel
: > device/xiaomi/beryl-kernel/modules.load
: > device/xiaomi/beryl-kernel/modules.load.vendor_ramdisk
: > device/xiaomi/beryl-kernel/modules.load.recovery

# ========= GSI Calendar clean =========
echo "🧼 Removing GSI Calendar entry..."
if [ -f build/make/target/product/gsi/Android.bp ]; then
    remove_line_contains "build/make/target/product/gsi/Android.bp" "Calendar"
fi

# ========= protobuf vendorcompat duplicate clean =========
echo "🧼 Removing duplicate protobuf vendorcompat modules..."
safe_remove_block "hardware/lineage/compat/Android.bp" "prebuilt_libprotobuf-cpp-full-3.9.1-vendorcompat"
safe_remove_block "hardware/lineage/compat/Android.bp" "prebuilt_libprotobuf-cpp-lite-3.9.1-vendorcompat"
safe_remove_block "hardware/lineage/compat/Android.bp" "prebuilt_libprotobuf-cpp-full-21.12-vendorcompat"
safe_remove_block "hardware/lineage/compat/Android.bp" "prebuilt_libprotobuf-cpp-lite-21.12-vendorcompat"
safe_remove_block "prebuilts/misc/protobuf_vendorcompat/Android.bp" "prebuilt_libprotobuf-cpp-full-3.9.1-vendorcompat"
safe_remove_block "prebuilts/misc/protobuf_vendorcompat/Android.bp" "prebuilt_libprotobuf-cpp-lite-3.9.1-vendorcompat"
safe_remove_block "prebuilts/misc/protobuf_vendorcompat/Android.bp" "prebuilt_libprotobuf-cpp-full-21.12-vendorcompat"
safe_remove_block "prebuilts/misc/protobuf_vendorcompat/Android.bp" "prebuilt_libprotobuf-cpp-lite-21.12-vendorcompat"

# ========= vendor / sensors namespace + duplicate fix =========
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

# ========= lunch =========
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

# ========= build =========
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
