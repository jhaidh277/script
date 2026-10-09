#!/bin/bash

echo "=========================================================="
echo "🚀 Starting Permanent AxionOS Build Script"
echo "=========================================================="

MAIN_DIR=$(pwd)

export USE_CCACHE=0
export NOMINATIVE_CCACHE=1
export SKIP_VENDORSETUP=true

git config --global http.postBuffer 524288000
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999

# ১. পুরোনো করাপ্টেড ফাইল ক্লিন করা
echo "Cleaning up old manifests and conflicting directories..."
rm -rf .repo/local_manifests || true
rm -rf out/target/product/hotdogb

# ২. AxionOS Repo initialization
repo init -u https://github.com/AxionAOSP/android.git -b lineage-23.2 --git-lfs --depth 1 || true

# ৩. স্থায়ী লোকাল ম্যানিফেস্ট তৈরি (যেখানে PDL টুলস এবং ডিভাইস ট্রি পার্মানেন্টলি পিন করা থাকবে)
echo "📥 Creating permanent local manifest for device, vendor, and PDL tools..."
mkdir -p .repo/local_manifests
cat << 'EOF' > .repo/local_manifests/roomservice.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <!-- Device & Common Trees -->
  <project name="jhaidh277/android_device_oneplus_hotdogb" path="device/oneplus/hotdogb" remote="github" revision="axion" />
  <project name="jhaidh277/android_device_oneplus_sm8150-common" path="device/oneplus/sm8150-common" remote="github" revision="axion" />

  <!-- Kernel -->
  <project name="crdroidandroid/android_kernel_oneplus_sm8150" path="kernel/oneplus/sm8150" remote="github" revision="17.0" />
  
  <!-- Vendor Blobs & Hardware -->
  <project name="TheMuppets/proprietary_vendor_oneplus_hotdogb" path="vendor/oneplus/hotdogb" remote="github" revision="lineage-23.2" />
  <project name="TheMuppets/proprietary_vendor_oneplus_sm8150-common" path="vendor/oneplus/sm8150-common" remote="github" revision="lineage-23.2" />
  <project name="LineageOS/android_hardware_oplus" path="hardware/oplus" remote="github" revision="lineage-23.2" />

  <!-- CRITICAL FIX: Missing PDL Tools & Generators for Soong Bootstrap -->
  <project name="AxionAOSP/android_system_tools_pdl" path="system/tools/pdl" remote="github" revision="lineage-23.2" />
</manifest>
EOF

# ৪. Crave Official Source Sync (ম্যানিফেস্ট অনুযায়ী সবকিছু স্বয়ংক্রিয়ভাবে সিংক হবে)
echo "Syncing all sources via Crave resync..."
until /opt/crave/resync.sh; do
    echo "⚠️ Crave resync encountered an issue. Retrying in 10 seconds..."
    sleep 10
done

# ৫. BoardConfig সেপোলিসি ফিক্স
if [ -f "device/oneplus/sm8150-common/BoardConfigCommon.mk" ]; then
    echo "🛠️ Fixing missing libion sepolicy include..."
    sed -i '/libion\/sepolicy.mk/d' device/oneplus/sm8150-common/BoardConfigCommon.mk || true
fi

# ৬. রাস্ট মডিউল কনফ্লিক্ট দূর করা
echo "🛠️ Removing conflicting rust crates..."
rm -rf external/rust/android-crates-io || true

# ৭. এনভায়রনমেন্ট সেটআপ ও লাঞ্চ
echo "Setting up build environment..."
source build/envsetup.sh || true

echo "🔑 Generating private keys..."
gk -s || true

echo "⚙️ Configuring build environment for hotdogb..."
axion hotdogb userdebug gms

# ৮. ফাইনাল কম্পাইলেশন শুরু
echo "🔥 Starting AxionOS compilation..."
ax -br -j16
