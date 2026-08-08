crave run --clean --no-patch -- echo "=========================================================="
echo "🚀 Starting Build Script for Project Infinity-X - OnePlus 7T (hotdogb)"
echo "=========================================================="

echo "🧹 Cleaning local manifests..."
rm -rf .repo/local_manifests

echo "📥 Initializing repo..."
repo init --no-repo-verify --git-lfs \
  -u https://github.com/ProjectInfinity-X/manifest \
  -b 16 \
  -g default,-mips,-darwin,-notdefault \
  --depth 1

echo "📥 Cloning local manifest..."
git clone --depth 1 -b infinity \
  https://github.com/jhaidh277/hotdogb_local_manifest \
  .repo/local_manifests

# ================================
# Sync sources
# ================================
echo ">>> Syncing sources"
if [[ -f /opt/crave/resync.sh ]]; then
    echo "Using Crave resync script..."
    /opt/crave/resync.sh
else
    echo "Crave resync not found – falling back to repo sync..."
    repo sync -c --force-sync --no-tags --no-clone-bundle --force-remove-dirty
fi

# ------------------------------------------------------------
# 🩹 FIX: Remove duplicate protobuf modules from hardware/lineage/compat
# ------------------------------------------------------------
BP1="hardware/lineage/compat/Android.bp"
if [[ -f "$BP1" ]]; then
  echo "🩹 Removing duplicate protobuf modules from $BP1..."
  awk '
  BEGIN { skip = 0 }
  /name: "prebuilt_libprotobuf-cpp-(full|lite)-(3\.9\.1|21\.12)-vendorcompat"/ {
      skip = 1
      next
  }
  skip && /^[[:space:]]*}/ {
      skip = 0
      next
  }
  !skip { print }
  ' "$BP1" > "${BP1}.tmp" && mv "${BP1}.tmp" "$BP1"
  echo "✅ Protobuf modules cleaned."
else
  echo "⚠️ $BP1 not found, skipping protobuf fix."
fi

# KernelSU
if [[ -d kernel/oneplus/sm8150 ]]; then
  echo "🧬 Enabling KernelSU in defconfigs..."
  find kernel/oneplus/sm8150/arch/arm64/configs -type f -name "*defconfig" -print0 |
  while IFS= read -r -d '' defconfig; do
    sed -i '/CONFIG_KERNELSU/d' "$defconfig"
    echo "CONFIG_KERNELSU=y" >> "$defconfig"
  done
  echo "✅ KernelSU enabled in defconfigs."
fi

echo "📦 Sourcing build environment..."
source build/envsetup.sh

# Optional: remove Calendar from GSI product
if [[ -f build/make/target/product/gsi/Android.bp ]]; then
  sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp || true
fi

echo "🍽️ Lunching target..."
lunch infinity_hotdogb-userdebug

echo "🧹 installclean..."
make installclean

echo "🏗️ Building (m bacon)..."
m bacon

echo "=========================================================="
echo "✅ Build finished."
echo "=========================================================="
