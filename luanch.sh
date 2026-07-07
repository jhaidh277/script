#!/bin/bash

echo "=========================================================="
echo "🚀 Starting Matrixx Build Script (Final Fixed)"
echo "=========================================================="

MAIN_DIR=$(pwd)

# ১. কনফিগারেশন
export USE_CCACHE=0
export NOMINATIVE_CCACHE=1
export SKIP_VENDORSETUP=true

# ২. blocked Android.mk চিরতরে ফিক্স করা (রিনেম পদ্ধতি)
if [ -f "external/ant-wireless/ant_native/Android.mk" ]; then
    echo "🛠 Blocking Android.mk to prevent build error..."
    mv external/ant-wireless/ant_native/Android.mk external/ant-wireless/ant_native/Android.mk.disabled || true
fi

# ৩. ক্লিনআপ ও ম্যানিফেস্ট সেটআপ (ডিভাইস নট ফাউন্ড ফিক্স)
echo "Cleaning and cloning manifests..."
rm -rf .repo/local_manifests || true
rm -rf device/oneplus/hotdogb device/oneplus/sm8150-common vendor/oneplus/sm8150-common || true

mkdir -p .repo/local_manifests
git clone https://github.com/jhaidh277/hotdogb_local_manifest --depth 1 -b matrix .repo/local_manifests || true

# ৪. সিঙ্ক করা
echo "Syncing sources..."
/opt/crave/resync.sh || true

# ৫. প্রি-বিল্ড ও KernelSU ফিক্স
if [ -f "vendor/oneplus/sm8150-common/Android.bp" ]; then
    sed -i "s/\"prebuilt\"/\"prebuiltfixed\"/g" "vendor/oneplus/sm8150-common/Android.bp" || true
fi

if [ -d "kernel/oneplus/sm8150" ]; then
    cd kernel/oneplus/sm8150
    find arch/arm64/configs/ -type f -name "*defconfig" | while read -r defconfig; do
        sed -i "/CONFIG_KERNELSU/d" "$defconfig" || true
        echo "CONFIG_KERNELSU=y" >> "$defconfig" || true
        echo "CONFIG_KPROBES=y" >> "$defconfig" || true
    done
    cd "$MAIN_DIR" || true
fi

# ৬. GSI Calendar ফিক্স
if [ -f "build/make/target/product/gsi/Android.bp" ]; then
    sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp || true
fi

# ৭. এনভায়রনমেন্ট সেটআপ
export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
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

source build/envsetup.sh || true

# ৮. লাঞ্চ কমান্ড (নতুন ফরম্যাট অনুযায়ী)
lunch matrixx_hotdogb-bp4a-user || lunch matrixx_hotdogb-userdebug || echo "⚠️ Lunch failed..."

# ৯. বিল্ড কমান্ড
make installclean || true
make matrixx -j$(nproc)
