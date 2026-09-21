#!/bin/bash

echo "=========================================================="
echo "🚀 Starting Official AxionOS Build Script for Crave"
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

# ১. AxionOS Repo initialization (lineage-23.2 branch)
repo init -u https://github.com/AxionAOSP/android.git -b lineage-23.2 --git-lfs --depth 1 || true

echo "📥 Creating local manifest..."
mkdir -p .repo/local_manifests
cat << 'EOF' > .repo/local_manifests/roomservice.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <project name="jhaidh277/android_device_oneplus_hotdogb" path="device/oneplus/hotdogb" remote="github" revision="lineage-23.2" />
  <project name="jhaidh277/android_device_oneplus_sm8150-common" path="device/oneplus/sm8150-common" remote="github" revision="lineage-23.2" />
  <project name="crdroidandroid/android_kernel_oneplus_sm8150" path="kernel/oneplus/sm8150" remote="github" revision="17.0" />
  <project path="vendor/oneplus/hotdogb" name="TheMuppets/proprietary_vendor_oneplus_hotdogb" remote="github" revision="lineage-23.2" />
  <project path="vendor/oneplus/sm8150-common" name="TheMuppets/proprietary_vendor_oneplus_sm8150-common" remote="github" revision="lineage-23.2" />
  <project path="hardware/oplus" name="LineageOS/android_hardware_oplus" remote="github" revision="lineage-23.2" />
  <project name="LineageOS/android_packages_modules_Bluetooth" path="packages/modules/Bluetooth" remote="github" revision="lineage-23.2" />
  <project name="LineageOS/android_packages_modules_Nfc" path="packages/modules/Nfc" remote="github" revision="lineage-23.2" />
  <project name="LineageOS/android_packages_modules_Uwb" path="packages/modules/Uwb" remote="github" revision="lineage-23.2" />
</manifest>
EOF

# ২. Crave Official Source Sync
echo "Syncing sources via Crave resync..."
/opt/crave/resync.sh || echo "⚠️ Crave resync flagged an issue, but proceeding anyway..."

# 🛠️ Rust Module Conflict Fix
echo "🛠️ Removing conflicting rust crates to prevent 'already defined' errors..."
rm -rf external/rust/android-crates-io || true

# ৩. Environment setup
. build/envsetup.sh || true

# ৪. Private Keys Generation (AxionOS requires gk -s once)
echo "🔑 Generating private keys..."
gk -s || true

# ৫. AxionOS Device Lunch Command
echo "⚙️ Configuring build environment for hotdogb (userdebug, gms)..."
axion hotdogb userdebug gms

# ৬. Final Compilation using AxionOS 'ax' command
echo "🔥 Starting AxionOS compilation..."
ax -br -j16
