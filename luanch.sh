rm -rf .repo/local_manifests
rm -rf out/target/product/hotdogb
rm -rf device/oneplus/hotdogb
rm -rf device/oneplus/sm8150-common
rm -rf vendor/oneplus/hotdogb
rm -rf vendor/oneplus/sm8150-common
rm -rf kernel/oneplus/sm8150
rm -rf hardware/dolby

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

repo init --depth=1 -u https://github.com/AxionAOSP/android.git -b lineage-23.2 --git-lfs

git clone https://github.com/jhaidh277/hotdogb_local_manifest --depth 1 -b axion .repo/local_manifests

if [ -x /opt/crave/resync.sh ]; then
    echo "🔄 Running Crave resync..."
    /opt/crave/resync.sh
fi

# ---------------------------------------------------------
# 2. Optional KernelSU enable
# ---------------------------------------------------------

if [ -d "kernel/oneplus/sm8150" ]; then
    echo "🧬 Applying KernelSU to arm64 defconfigs..."
    cd kernel/oneplus/sm8150
    find arch/arm64/configs/ -type f -name "*defconfig" | while read -r defconfig; do
        sed -i '/CONFIG_KERNELSU/d' "$defconfig" || true
        echo "CONFIG_KERNELSU=y" >> "$defconfig"
    done
    cd "$MAIN_DIR"
fi

# ---------------------------------------------------------
# 3. Source envsetup
# ---------------------------------------------------------


AXION_KERNEL_MODULES_BINDER_UX_HOOKS=y

AXION_KERNEL_MODULES_BINDER_OBS_HOOKS=y

. build/envsetup.sh

axion hotdogb userdebug gms

ax -br -j4 

echo "=========================================================="
echo "✅ Build script finished."
echo "=========================================================="

# ---------------------------------------------------------
# 4. Telegram upload
# ---------------------------------------------------------

TELEGRAM_BIN="/home/admin/.local/bin/telegram-upload"
CHAT_ID="@jihad099012"
OUT_DIR="out/target/product/hotdogb"
ZIP_FILE=$(ls -t ${OUT_DIR}/*.zip 2>/dev/null | head -n 1)

if [ -f "$ZIP_FILE" ]; then
    echo "📤 Uploading ROM..."
    "$TELEGRAM_BIN" --to "$CHAT_ID" --caption "ROM Build Successful for OnePlus 7T GMS! 🎉" "$ZIP_FILE" || true
else
    echo "⚠️ ROM zip not found in $OUT_DIR"
fi
