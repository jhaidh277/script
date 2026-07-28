rm -rf .repo/local_manifests
 
repo init --depth=1 -u https://github.com/AxionAOSP/android.git -b lineage-23.2 --git-lfs
 
git clone https://github.com/jhaidh277/hotdogb_local_manifest --depth 1 -b axion .repo/local_manifests

# Optional: KernelSU enable
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

 \ 

/opt/crave/resync.sh
 
source build/envsetup.sh
 
axion xpeng userdebug gms
 \ 

ax -b

# Telegram upload
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
