#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# ১. সিস্টেম সেটআপ এবং দ্রুত ডাউনলোডের জন্য কনফিগারেশন
sudo apt update
sudo apt install patchelf ccache aria2 python3-pip ripgrep -y
pip3 install telegram-upload --break-system-packages

# CCACHE দ্রুতগতির জন্য কনফিগার করা
mkdir -p /tmp/ccache
export CCACHE_DIR=/tmp/ccache
export USE_CCACHE=1
ccache -M 50G
ccache -s

# ২. ক্লিনআপ
rm -rf .repo/local_manifests/
rm -rf device/oneplus/hotdogb
rm -rf vendor/oneplus/hotdogb
rm -rf kernel/oneplus/sm8150

# ৩. রিপো ইনিশিয়ালাইজেশন
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault

# ৪. গিট হুক ক্লিনআপ (সিস্টেম হ্যাং হওয়া রোধ করবে)
echo "Cleaning up git hooks..."
find .repo/ -name "hooks" -type d -exec rm -rf {} + 2>/dev/null || true

# ৫. লোকাল ম্যানিফেস্ট ক্লোন
git clone https://github.com/mdnoyon80123/hotdogb_local_manifest-j --depth 1 -b main .repo/local_manifests

# ৬. দ্রুত সোর্স সিঙ্ক (প্রসেসরের সব কোর ব্যবহার করে)
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

# ১০. ফাস্ট বিল্ড প্রসেস
make installclean
lunch infinity_hotdogb-userdebug
# -j$(nproc) কমান্ডটি আপনার বিল্ডকে সর্বোচ্চ গতিতে চলতে সাহায্য করবে
m bacon -j$(nproc)

# ১১. টেলিগ্রাম আপলোড
ZIP_FILE=$(ls out/target/product/hotdogb/*.zip | head -n 1)
if [ -f "$ZIP_FILE" ]; then
    telegram-upload --to "me" --caption "Build Finished: $(date)" "$ZIP_FILE"
else
    echo "Build failed."
    exit 1
fi
