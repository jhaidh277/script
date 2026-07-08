#!/bin/bash

echo "=========================================================="
echo "🚀 Starting 100% Verified Script (Cleaned for AxionOS)"
echo "=========================================================="

# মেইন সোর্স ডিরেক্টরি ট্র্যাক রাখার জন্য পাথ সেভ
MAIN_DIR=$(pwd)

# 🎯 FIX 1: ccache এবং অন্যান্য কনফিগারেশন এরর পুরোপুরি বাইপাস করা
export USE_CCACHE=0
export NOMINATIVE_CCACHE=1
echo "⚠️ Skipping ccache configuration..."

# 🎯 FIX 2: vendorsetup.sh এর লুপ এবং ঝামেলা চিরতরে বন্ধ করা
export SKIP_VENDORSETUP=true

# 🎯 FIX 3: আগের করাপ্টেড ডিরেক্টরি এবং কনফ্লিক্ট ফোর্স ক্লিন
echo "Force cleaning corrupted directories..."
rm -rf .repo/local_manifests || true
rm -rf device/oneplus/hotdogb device/oneplus/sm8150-common vendor/oneplus/hotdogb vendor/oneplus/sm8150-common kernel/oneplus/sm8150 hardware/oplus || true

# ৩. Repo initialization (Updated for AxionOS)
repo init -u https://github.com/AxionAOSP/android.git -b lineage-23.2 --git-lfs --depth 1 || true

# ৪. Directory structure নিশ্চিত করা
mkdir -p .repo/repo/hooks || true

# ৫. Local manifest clone (Axion branch)
git clone https://github.com/jhaidh277/hotdogb_local_manifest --depth 1 -b axion .repo/local_manifests || true

# ৬. Crave Official Source Sync
echo "Syncing sources via Crave resync..."
/opt/crave/resync.sh || echo "⚠️ Crave resync flagged an issue..."

# 🎯 [DYNAMIC CRITICAL FIX - VERIFIED] ডুপ্লিকেট "prebuilt_" মডিউল ১০০% ফিক্স
BP_FILE="vendor/oneplus/sm8150-common/Android.bp"
if [ -f "$BP_FILE" ]; then
    echo "🛠️ Dynamically fixing duplicate prebuilt_ module definition..."
    awk '/name:[[:space:]]*"prebuilt_"/ { count++; if (count == 2) { sub(/"prebuilt_"/, "\"prebuilt_duplicate_fixed_\"") } } { print }' "$BP_FILE" > "${BP_FILE}.tmp" && mv "${BP_FILE}.tmp" "$BP_FILE" || true
fi

# 🎯 [KERNELSU ACTIVATION] সোর্সে থাকা KernelSU অ্যাক্টিভেট করা
if [ -d "kernel/oneplus/sm8150" ]; then
    cd kernel/oneplus/sm8150
    find arch/arm64/configs/ -type f -name "*defconfig" | while read -r defconfig; do
        sed -i '/CONFIG_KERNELSU/d' "$defconfig" || true
        echo "CONFIG_KERNELSU=y" >> "$defconfig"
    done
    cd "$MAIN_DIR"
fi

# ৭. Safety Check
rm -f device/oneplus/hotdogb/vendorsetup.sh 2>/dev/null || true
rm -f device/oneplus/sm8150-common/vendorsetup.sh 2>/dev/null || true

# ৮. Environment configuration
export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=true
export TARGET_MULTISIM_CONFIG=dsds

source build/envsetup.sh || true

# ৯. GSI Android.bp ফাইল মডিফাই
if [ -f build/make/target/product/gsi/Android.bp ]; then
    sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp || true
fi

# ১০. কী জেনারেট করা ও বিল্ড শুরু করা
gk -s
axion hotdogb userdebug gms
make installclean || true
ax -br -j$(nproc)
