#!/bin/bash

echo "=========================================================="
echo "🚀 Starting Permanent AxionOS Build Script with PDL Fix"
echo "=========================================================="

MAIN_DIR=$(pwd)

export USE_CCACHE=0
export NOMINATIVE_CCACHE=1
export SKIP_VENDORSETUP=true

git config --global http.postBuffer 524288000
git config --global http.lowSpeedLimit 0
git config --global http.lowSpeedTime 999999

# ১. পুরোনো করাপ্টেড ফাইল এবং সোং ক্যাশ ক্লিন করা
echo "Cleaning up old manifests, soong cache, and conflicting directories..."
rm -rf .repo/local_manifests || true

# ২. AxionOS Repo initialization
repo init -u https://github.com/AxionAOSP/android.git -b lineage-23.2 --git-lfs --depth 1 || true

# ৩. স্থায়ী লোকাল ম্যানিফেস্ট তৈরি (ডিভাইস, ভেন্ডর ও অন্যান্য ডিপেন্ডেন্সির জন্য)
echo "📥 Creating permanent local manifest for device, vendor, and tools..."
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

  <!-- PDL Tools for Soong Bootstrap -->
  <project name="AxionAOSP/android_system_tools_pdl" path="system/tools/pdl" remote="github" revision="lineage-23.2" />
</manifest>
EOF

# ৪. স্থায়ী ফিক্স: ম্যানুয়ালি system/tools/pdl পিন করে দেওয়া যাতে সোং বুটস্ট্রাপে কোনো এরর না আসে
echo "🛠️ Ensuring system/tools/pdl is correctly placed..."
mkdir -p system/tools
rm -rf system/tools/pdl
git clone https://github.com/AxionAOSP/android_system_tools_pdl -b lineage-23.2 system/tools/pdl || git clone https://github.com/LineageOS/android_system_tools_pdl -b lineage-23.2 system/tools/pdl || true

# ৫. Crave Official Source Sync
echo "Syncing all sources via Crave resync..."
/opt/crave/resync.sh
    echo "⚠️ Crave resync encountered an issue. Retrying in 10 seconds..."
    sleep 10
done

# ৬. অতিরিক্ত সুরক্ষা: সিংক হওয়ার পরেও যদি pdl ফোল্ডার মুছে যায়, তবে পুনরায় ক্লোন করা
if [ ! -d "system/tools/pdl" ]; then
    echo "📥 Re-cloning system/tools/pdl post-sync..."
    mkdir -p system/tools/pdl
    git clone https://github.com/AxionAOSP/android_system_tools_pdl -b lineage-23.2 system/tools/pdl || git clone https://github.com/LineageOS/android_system_tools_pdl -b lineage-23.2 system/tools/pdl || true
fi

# ৭. BoardConfig সেপোলিসি ফিক্স
if [ -f "device/oneplus/sm8150-common/BoardConfigCommon.mk" ]; then
    echo "🛠️ Fixing missing libion sepolicy include..."
    sed -i '/libion\/sepolicy.mk/d' device/oneplus/sm8150-common/BoardConfigCommon.mk || true
fi

# ৮. রাস্ট মডিউল কনফ্লিক্ট দূর করা
echo "🛠️ Removing conflicting rust crates..."
rm -rf external/rust/android-crates-io || true

# ৯. এনভায়রনমেন্ট সেটআপ ও লাঞ্চ
echo "Setting up build environment..."
source build/envsetup.sh || true

echo "🔑 Generating private keys..."
gk -s || true

echo "⚙️ Configuring build environment for hotdogb..."
axion hotdogb userdebug gms

# ১০. ফাইনাল কম্পাইলেশন শুরু
echo "🔥 Starting AxionOS compilation..."
ax -br -j16
