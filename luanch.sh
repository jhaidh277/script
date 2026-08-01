#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "=========================================================="
echo "🚀 AxionOS hotdogb Auto-Build (GMS)"
echo "=========================================================="

if [ ! -f "./build/envsetup.sh" ]; then
    echo "ERROR: build/envsetup.sh not found."
    echo "Run this from the Android source root."
    exit 1
fi

MAIN_DIR="$PWD"

echo "🧹 Cleaning workspace for hotdogb..."
rm -rf .repo/local_manifests
rm -rf out/target/product/hotdogb

export USE_CCACHE=0
export NOMINATIVE_CCACHE=1
export SKIP_VENDORSETUP=true
export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=false
export TARGET_MULTISIM_CONFIG=dsds
export TARGET_INCLUDES_LOS_PREBUILTS=false

echo "📥 Initializing repo..."
repo init --depth=1 -u https://github.com/AxionAOSP/android.git -b lineage-23.2 --git-lfs || {
    echo "ERROR: repo init failed."
    exit 1
}

echo "📥 Cloning local manifest..."
rm -rf .repo/local_manifests
git clone https://github.com/jhaidh277/hotdogb_local_manifest --depth 1 -b axion .repo/local_manifests || {
    echo "ERROR: local manifest clone failed."
    exit 1
}

if [ -x /opt/crave/resync.sh ]; then
    echo "🔄 Running Crave resync..."
    /opt/crave/resync.sh
fi

if [ -d "kernel/oneplus/sm8150" ]; then
    echo "🧬 Applying KernelSU..."
    cd kernel/oneplus/sm8150
    find arch/arm64/configs/ -type f -name "*defconfig" | while read -r defconfig; do
        sed -i '/CONFIG_KERNELSU/d' "$defconfig" || true
        echo "CONFIG_KERNELSU=y" >> "$defconfig"
    done
    cd "$MAIN_DIR"
fi

# ------------------------------------------------------------
# envsetup.sh, axion, ax — এই ফাংশনগুলোর ভিতরে অনেক ভেরিয়েবল
# আনডিক্লেয়ারড থাকে, তাই পুরো বিল্ড প্রসেস শেষ না হওয়া
# পর্যন্ত 'set -u' বন্ধ রাখা হলো (ইন্টারেক্টিভ শেলের মতো আচরণ)।
# ------------------------------------------------------------
set +u

echo "📦 Sourcing build/envsetup.sh..."
export TOP="$MAIN_DIR"
source ./build/envsetup.sh

type axion >/dev/null 2>&1 || {
    echo "ERROR: axion command not available after sourcing envsetup.sh"
    exit 1
}

echo "🔑 Generating private keys..."
mkdir -p vendor/lineage-priv/keys
gk -s

echo "💾 Setting up swap (avoids OOM during build)..."
setupSwap || true

echo "🍽️ Configuring with axion helper (hotdogb, userdebug, gms)..."
axion hotdogb userdebug gms

echo "🧹 Running installclean..."
make installclean || true

echo "🏗️ Building the ROM..."
ax -br -j18

set -u
# ------------------------------------------------------------

echo "=========================================================="
echo "✅ Build script finished."
echo "=========================================================="

# টেলিগ্রাম আপলোড সেকশন
TELEGRAM_BIN="/home/admin/.local/bin/telegram-upload"
CHAT_ID="@jihad099012"
OUT_DIR="out/target/product/hotdogb"
ZIP_FILE=$(ls -t "${OUT_DIR}"/*.zip 2>/dev/null | head -n 1 || true)

if [ -n "$ZIP_FILE" ] && [ -f "$ZIP_FILE" ]; then
    echo "📤 Uploading ROM..."
    "$TELEGRAM_BIN" --to "$CHAT_ID" --caption "ROM Build Successful for OnePlus 7T GMS! 🎉" "$ZIP_FILE" || true
else
    echo "⚠️ ROM zip not found in $OUT_DIR"
fi
