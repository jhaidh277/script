#!/bin/bash

# কোনো কমান্ড ব্যর্থ হলে স্ক্রিপ্ট থামিয়ে দিবে
set -e

# ১. সিস্টেম সেটআপ এবং ডিপেনডেন্সি
sudo apt update
sudo apt install patchelf ccache aria2 python3-pip ripgrep -y
pip3 install telegram-upload --break-system-packages

# CCACHE কনফিগারেশন (বিল্ডের গতি বাড়ানোর জন্য)
mkdir -p /tmp/ccache
export CCACHE_DIR=/tmp/ccache
export USE_CCACHE=1
ccache -M 50G
ccache -s

# ২. পুরোনো ফাইল মুছে ক্লিনআপ
rm -rf .repo/local_manifests/
rm -rf device/oneplus/hotdogb
rm -rf vendor/oneplus/hotdogb
rm -rf kernel/oneplus/sm8150

# ৩. রিপো ইনিশিয়ালাইজেশন
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault

# ৪. গিট হুক ক্লিনআপ (যাতে 'hooks is different' এরর না আসে)
echo "Cleaning up problematic git hooks..."
find .repo/ -name "hooks" -type d -exec rm -rf {} + 2>/dev/null 2>&1 || true

# ৫. লোকাল ম্যানিফেস্ট ক্লোন
git clone https://github.com/mdnoyon80123/hotdogb_local_manifest-j --depth 1 -b main .repo/local_manifests

# ৬. সোর্স সিঙ্ক (সব কোর ব্যবহার করে দ্রুত সিঙ্ক হবে)
/opt/crave/resync.sh
repo sync -c -j$(nproc) --force-sync --no-clone-bundle --no-tags --detach

# ৭. KernelSU ইন্টিগ্রেশন
echo "Integrating KernelSU..."
pushd kernel/oneplus/sm8150
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s v0.9.5
popd

# ৮. এনভায়রনমেন্ট কনফিগারেশন
export WITH_ADB_INSECURE=true
export SELINUX_IGNORE_NEVERALLOWS=true
export TARGET_GAPPS_PACKAGE_TYPE=none
export TARGET_MULTISIM_CONFIG=dsds
export KERNEL_SUPPORTS_KSU=true
source build/envsetup.sh

# ৯. কনফ্লিক্ট ক্লিনআপ
rg -l -0 '<<<<<<<|=======|>>>>>>>' device/oneplus/hotdogb | xargs -0 sed -i '/^<<<<<<< /d;/^=======/d;/^>>>>>>> /d' || true

# ১০. বিল্ড প্রক্রিয়া (সর্বোচ্চ গতিতে বিল্ড করার জন্য -j$(nproc))
make installclean
lunch infinity_hotdogb-userdebug
m bacon -j$(nproc)

# ১১. টেলিগ্রাম আপলোড
ZIP_FILE=$(ls out/target/product/hotdogb/*.zip | head -n 1)
if [ -f "$ZIP_FILE" ]; then
    telegram-upload --to "me" --caption "Build Finished: $(date)" "$ZIP_FILE"
    echo "Upload finished successfully!"
else
    echo "Error: Build file not found."
    exit 1
fi

ccache -s
