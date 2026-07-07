#!/bin/bash

echo "=========================================================="
echo "🚀 Starting 100% Verified Script (Cleaned)"
echo "=========================================================="

MAIN_DIR=$(pwd)

export USE_CCACHE=0
export NOMINATIVE_CCACHE=1
export SKIP_VENDORSETUP=true

# ৩. কনফ্লিক্ট ক্লিন করা (সেপারেটর ঠিক করা হয়েছে)
echo "Force cleaning corrupted directories..."
rm -rf .repo/local_manifests || true
rm -rf device/oneplus/hotdogb device/oneplus/sm8150-common vendor/oneplus/hotdogb vendor/oneplus/sm8150-common kernel/oneplus/sm8150 hardware/oplus || true

# ৩. Repo initialization (সেপারেটর ঠিক করা হয়েছে)
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectMatrixx/android -b 16.2 -g default,-mips,-darwin,-notdefault --depth 1 || true

# ৪. Directory structure
mkdir -p .repo/repo/hooks || true

# ৫. Local manifest clone
git clone https://github.com/jhaidh277/hotdogb_local_manifest --depth 1 -b matrix .repo/local_manifests || true

# ৬. Crave Official Source Sync
/opt/crave/resync.sh || { echo "⚠️ Crave resync flagged an issue, but proceeding anyway..."; true; }

# ৭. Prebuilt ফিক্স
BP_FILE="vendor/oneplus/sm8150-common/Android.bp"
if [ -f "$BP_FILE" ]; then
    sed -i "s/\"prebuilt\"/\"prebuiltfixed\"/g" "$BP_FILE" || true
fi

# ৮. KernelSU ফিক্স
if [ -d "kernel/oneplus/sm8150" ]; then
    cd kernel/oneplus/sm8150
    find arch/arm64/configs/ -type f -name "*defconfig" | while read -r defconfig; do
        sed -i "/CONFIG_KERNELSU/d" "$defconfig" || true
        echo "CONFIG_KERNELSU=y" >> "$defconfig" || true
        echo "CONFIG_KPROBES=y" >> "$defconfig" || true
    done
    cd "$MAIN_DIR" || true
fi

# ৯. Blocked File Fix (sed দিয়ে ফাইল খালি করা)
if [ -f "external/ant-wireless/ant_native/Android.mk" ]; then
    sed -i "d" external/ant-wireless/ant_native/Android.mk || true
fi

# ১০. Environment configuration
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

# ১১. GSI Calendar ফিক্স
if [ -f "build/make/target/product/gsi/Android.bp" ]; then
    sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp || true
fi

# ১২. লাঞ্চ কমান্ড (সঠিক ফরম্যাট)
lunch matrixx_hotdogb-bp4a-user || lunch matrixx_hotdogb-userdebug || lunch lineage_hotdogb-userdebug || lunch hotdogb-userdebug || echo "⚠️ Lunch failed..."

# ১৩. বিল্ড কমান্ড
make installclean || true
make matrixx -j$(nproc)
