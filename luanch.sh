#!/bin/bash

echo "=========================================================="
echo "🚀 Starting Foolproof AxionOS Build Script for Crave"
echo "=========================================================="

MAIN_DIR=$(pwd)

export USE_CCACHE=0
export NOMINATIVE_CCACHE=1
echo "⚠️ Skipping ccache configuration as it is not present in container..."

export SKIP_VENDORSETUP=true

git config --global http.postBuffer 524288000
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999

# ১. আগের করাপ্টেড বা কনফ্লিক্টিং ফাইল ক্লিন করা
echo "Force cleaning corrupted directories and manifests..."
rm -rf .repo/local_manifests || true
rm -rf out/target/product/hotdogb
rm -rf device/oneplus/hotdogb
rm -rf device/oneplus/sm8150-common
rm -rf vendor/oneplus/hotdogb
rm -rf vendor/oneplus/sm8150-common

# ২. AxionOS Repo initialization
repo init -u https://github.com/AxionAOSP/android.git -b lineage-23.2 --git-lfs --depth 1 || true

# ৩. বিল্ড সিস্টেম অটো-ফেচ করার আগেই ম্যানুয়ালি সঠিক ব্রাঞ্চ থেকে ক্লোন করে নেওয়া (সবচেয়ে গুরুত্বপূর্ণ ধাপ)
echo "📥 Pre-cloning device trees and dependencies to prevent auto-fetch errors..."
mkdir -p device/oneplus
mkdir -p vendor/oneplus
mkdir -p kernel/oneplus
mkdir -p hardware

# Device tree (axion branch)
git clone https://github.com/jhaidh277/android_device_oneplus_hotdogb -b axion device/oneplus/hotdogb

# Common device tree (axion branch)
git clone https://github.com/jhaidh277/android_device_oneplus_sm8150-common -b axion device/oneplus/sm8150-common

# Kernel
git clone https://github.com/crdroidandroid/android_kernel_oneplus_sm8150 -b 17.0 kernel/oneplus/sm8150

# Vendor blobs
git clone https://github.com/TheMuppets/proprietary_vendor_oneplus_hotdogb -b lineage-24.0 vendor/oneplus/hotdogb
git clone https://github.com/TheMuppets/proprietary_vendor_oneplus_sm8150-common -b lineage-24.0 vendor/oneplus/sm8150-common

# Hardware oplus
git clone https://github.com/LineageOS/android_hardware_oplus -b lineage-24.0 hardware/oplus

# ৪. Crave Official Source Sync (বাকি রিমেইনিং সোর্সের জন্য)
echo "Syncing remaining sources via Crave resync..."
until /opt/crave/resync.sh; do
    echo "⚠️ Crave resync flagged an issue. Retrying in 10 seconds..."
    sleep 10
done

# ৫. BoardConfig সেপোলিসি ফিক্স (Missing libion sepolicy.mk error fix)
if [ -f "device/oneplus/sm8150-common/BoardConfigCommon.mk" ]; then
    echo "🛠️ Fixing missing libion sepolicy include in BoardConfigCommon.mk..."
    sed -i '/libion\/sepolicy.mk/d' device/oneplus/sm8150-common/BoardConfigCommon.mk || true
fi

# ৬. ফিক্স: রাস্ট মডিউল কনফ্লিক্ট দূর করা
echo "🛠️ Removing conflicting rust crates..."
rm -rf external/rust/android-crates-io || true

# ৭. এনভায়রনমেন্ট সেটআপ
echo "Setting up build environment..."
source build/envsetup.sh || true

# ৮. প্রাইভেট কি জেনারেশন
echo "🔑 Generating private keys..."
gk -s || true

# ৯. AxionOS ডিভাইস লাঞ্চ কমান্ড
echo "⚙️ Configuring build environment for hotdogb (userdebug, gms)..."
axion hotdogb userdebug gms

# ১০. ফাইনাল কম্পাইলেশন শুরু
echo "🔥 Starting AxionOS compilation..."
ax -br -j16
