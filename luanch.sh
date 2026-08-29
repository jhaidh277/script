#!/bin/bash

echo "=========================================================="
echo "🚀 Starting Official RisingOS Build Script for Crave (Cleaned)"
echo "=========================================================="

# মেইন সোর্স ডিরেক্টরি ট্র্যাক রাখার জন্য পাথ সেভ
MAIN_DIR=$(pwd)

# ccache এবং অন্যান্য কনফিগারেশন এরর বাইপাস করা
export USE_CCACHE=0
export NOMINATIVE_CCACHE=1
echo "⚠️ Skipping ccache configuration as it is not present in container..."

# vendorsetup.sh এর লুপ এবং ঝামেলা বন্ধ করা
export SKIP_VENDORSETUP=true

# আগের করাপ্টেড ডিরেক্টরি এবং কনফ্লিক্ট ফোর্স ক্লিন
echo "Force cleaning corrupted directories and conflicting git hooks..."
rm -rf .repo/local_manifests || true
rm -rf out/target/product/hotdogb
rm -rf device/oneplus/hotdogb
rm -rf vendor/oneplus/hotdogb
# ৩. RisingOS Repo initialization (seventeen branch)
repo init --no-repo-verify --git-lfs -u https://github.com/RisingOS-Revived/android -b seventeen -g default,-mips,-darwin,-notdefault --depth 1 || true

echo "📥 Creating local manifest..."
mkdir -p .repo/local_manifests
cat << 'EOF' > .repo/local_manifests/roomservice.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <project name="jhaidh277/android_device_oneplus_hotdogb" path="device/oneplus/hotdogb" remote="github" revision="rising" />
  <project name="jhaidh277/android_device_oneplus_sm8150-common" path="device/oneplus/sm8150-common" remote="github" revision="lineage-23.2" />
  <project name="jhaidh277/android_kernel_oneplus_sm8150" path="kernel/oneplus/sm8150" remote="github" revision="16.0" />
  <project path="vendor/oneplus/hotdogb" name="TheMuppets/proprietary_vendor_oneplus_hotdogb" remote="github" revision="lineage-23.2" />
  <project path="vendor/oneplus/sm8150-common" name="TheMuppets/proprietary_vendor_oneplus_sm8150-common" remote="github" revision="lineage-23.2" />
  <project path="hardware/oplus" name="LineageOS/android_hardware_oplus" remote="github" revision="lineage-23.2" />
</manifest>
EOF

# ৬. Crave Official Source Sync
echo "Syncing sources via Crave resync..."
/opt/crave/resync.sh || echo "⚠️ Crave resync flagged an issue, but proceeding anyway..."

# hardware/lineage/compat/Android.bp এর ডুপ্লিকেট মডিউল ফিক্স করার জন্য sed কমান্ড
if [ -f "hardware/lineage/compat/Android.bp" ]; then
    echo "🛠️ Fixing duplicate modules in hardware/lineage/compat/Android.bp..."
    sed -i '/prebuilt_libprotobuf-cpp-full-3.9.1-vendorcompat/,/^}/d' hardware/lineage/compat/Android.bp || true
    sed -i '/prebuilt_libprotobuf-cpp-lite-3.9.1-vendorcompat/,/^}/d' hardware/lineage/compat/Android.bp || true
    sed -i '/prebuilt_libprotobuf-cpp-full-21.12-vendorcompat/,/^}/d' hardware/lineage/compat/Android.bp || true
    sed -i '/prebuilt_libprotobuf-cpp-lite-21.12-vendorcompat/,/^}/d' hardware/lineage/compat/Android.bp || true
fi

# ডুপ্লিকেট "prebuilt_" মডিউল ডাইনামিক ফিক্স
BP_FILE="vendor/oneplus/sm8150-common/Android.bp"
if [ -f "$BP_FILE" ]; then
    echo "🛠️ Dynamically fixing duplicate prebuilt_ module definition..."
    awk '/name:[[:space:]]*"prebuilt_"/ { count++; if (count == 2) { sub(/"prebuilt_"/, "\"prebuilt_duplicate_fixed_\"") } } { print }' "$BP_FILE" > "${BP_FILE}.tmp" && mv "${BP_FILE}.tmp" "$BP_FILE" || true
fi

# সোর্সে থাকা KernelSU অ্যাক্টিভেট করা
if [ -d "kernel/oneplus/sm8150" ]; then
    cd kernel/oneplus/sm8150
    find arch/arm64/configs/ -type f -name "*defconfig" | while read -r defconfig; do
        sed -i '/CONFIG_KERNELSU/d' "$defconfig" || true
        echo "CONFIG_KERNELSU=y" >> "$defconfig"
    done
    cd "$MAIN_DIR"
fi

# Safety Check
rm -f device/oneplus/hotdogb/vendorsetup.sh 2>/dev/null || true
rm -f device/oneplus/sm8150-common/vendorsetup.sh 2>/dev/null || true

# ========================================================
# Environment configuration
# ========================================================
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

source build/envsetup.sh || true

# GSI Android.bp ফাইল মডিফাই
if [ -f build/make/target/product/gsi/Android.bp ]; then
    sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp || true
fi

# RisingOS অফিসিয়াল লাঞ্চ কমান্ড (riseup ব্যবহার করে)
riseup hotdogb userdebug || echo "⚠️ riseup failed..."

# লাঞ্চ সফল হওয়ার পর ওল্ড ইমেজ ক্লিন করা
make installclean || true

# RisingOS ফাইনাল কম্পাইলেশন কমান্ড
rise b
