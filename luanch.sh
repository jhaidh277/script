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

# ৩. প্রি-ক্লোনিং (ডিভাইস ট্রি, কমন ট্রি এবং অন্যান্য ডিপেন্ডেন্সি)
echo "📥 Pre-cloning device trees and dependencies..."
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

# Vendor blobs (lineage-23.2 branch)
git clone https://github.com/TheMuppets/proprietary_vendor_oneplus_hotdogb -b lineage-23.2 vendor/oneplus/hotdogb
git clone https://github.com/TheMuppets/proprietary_vendor_oneplus_sm8150-common -b lineage-23.2 vendor/oneplus/sm8150-common

# Hardware oplus
git clone https://github.com/LineageOS/android_hardware_oplus -b lineage-23.2 hardware/oplus

# ৪. Crave Official Source Sync
echo "Syncing remaining sources via Crave resync..."
until /opt/crave/resync.sh; do
    echo "⚠️ Crave resync flagged an issue. Retrying in 10 seconds..."
    sleep 10
done

# ৫. PDL জেনারেটর এবং ব্লুটুথ/টুলস সংক্রান্ত মিসিং ফাইলগুলোর ফিক্স সিংক
echo "🔄 Ensuring sync for system tools, pdl, and bluetooth modules..."
repo sync system/tools/pdl packages/modules/Bluetooth tools/netsim tools/rootcanal external/rust/pica -j16 || true

# ৬. BoardConfig সেপোলিসি ফিক্স
if [ -f "device/oneplus/sm8150-common/BoardConfigCommon.mk" ]; then
    echo "🛠️ Fixing missing libion sepolicy include in BoardConfigCommon.mk..."
    sed -i '/libion\/sepolicy.mk/d' device/oneplus/sm8150-common/BoardConfigCommon.mk || true
fi

# ৭. রাস্ট মডিউল কনফ্লিক্ট দূর করা
echo "🛠️ Removing conflicting rust crates..."
rm -rf external/rust/android-crates-io || true

# ৮. এনভায়রনমেন্ট সেটআপ
echo "Setting up build environment..."
source build/envsetup.sh || true

# ৯. প্রাইভেট কি জেনারেশন
echo "🔑 Generating private keys..."
gk -s || true

# ১০. AxionOS ডিভাইস লাঞ্চ কমান্ড
echo "⚙️ Configuring build environment for hotdogb (userdebug, gms)..."
axion hotdogb userdebug gms

# ১১. ফাইনাল কম্পাইলেশন শুরু
echo "🔥 Starting AxionOS compilation..."
ax -br -j16
