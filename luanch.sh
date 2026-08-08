crave run --clean --no-patch -- "rm -rf .repo/local_manifests; \
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault --depth 1; \
git clone --depth 1 -b infinity https://github.com/jhaidh277/hotdogb_local_manifest .repo/local_manifests; \
/opt/crave/resync.sh; \
sed -i '/prebuilt_libprotobuf-cpp-full-3.9.1-vendorcompat/,/^}/d' hardware/lineage/compat/Android.bp; \
sed -i '/prebuilt_libprotobuf-cpp-lite-3.9.1-vendorcompat/,/^}/d' hardware/lineage/compat/Android.bp; \
sed -i '/prebuilt_libprotobuf-cpp-full-21.12-vendorcompat/,/^}/d' hardware/lineage/compat/Android.bp; \
sed -i '/prebuilt_libprotobuf-cpp-lite-21.12-vendorcompat/,/^}/d' hardware/lineage/compat/Android.bp; \
sed -i '/visibility: \[/,/\],/d' device/oneplus/sm8150-common/camera_helper/Android.bp; \
touch device/oneplus/sm8150-common/camera_helper/CameraProviderExtension.cpp; \
sed -i '/libcameraservice_extension.opsm8150/d' frameworks/av/services/camera/libcameraservice/Android.bp; \
find kernel/oneplus/sm8150/arch/arm64/configs -type f -name '*defconfig' -exec sed -i '/CONFIG_KERNELSU/d' {} \; -exec sh -c 'echo CONFIG_KERNELSU=y >> {}' \; ; \
source build/envsetup.sh; \
sed -i '/Calendar/d' build/make/target/product/gsi/Android.bp; \
lunch infinity_hotdogb-userdebug && make installclean && m bacon -j\$(nproc --all)"
