#!/bin/bash
  
  # 1. System update and ccache installation
sudo apt update && sudo apt install ccache -y && \

# 2. Clean up any existing local manifests
rm -rf .repo/local_manifests; \

# 3. Initialize the ProjectInfinity-X Android 16 repository
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault && \

# 4. Clone and setup your custom local manifest
git clone https://github.com/jhaidh277/ossop --depth 1 -b main .repo/local_manifests && \
cp .repo/local_manifests/op.xml .repo/local_manifests/local_manifest.xml && \

# 5. Sync the source code using Crave script
/opt/crave/resync.sh && \

# 6. Modify the GSI Android.bp file to remove Calendar entry
sed -i "/Calendar/d" build/make/target/product/gsi/Android.bp && \

# 7. Set up the build environment and select the device target
source build/envsetup.sh && \
lunch infinity_hotdogb-userdebug && \

# 8. Export KernelSU and Telephony configuration properties
export WITH_KSU=true && \
export KSU_SUPPORT=1 && \
export KSU_VERSION=11620 && \
export ADDITIONAL_BUILD_PROPERTIES="persist.radio.multisim.config=dsds telephony.lteOnCdmaDevice=1" && \

# 9. Start the compilation
m bacon
