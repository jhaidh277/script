# =====================================================================
# 🛠️ CRITICAL FIXES (মেকফাইল এবং সোর্স কোড এরর অটো-ফিক্স)
# =====================================================================
echo "Applying deep fixes for device tree and vendor configs..."

# ১. গিট লক বা করাপ্টেড স্টেট পুরোপুরি ক্লিন করা
rm -rf device/oneplus/hotdogb/.git

# ডিভাইস ট্রির ভেতর ফাইল রিনেম ও পাথ ফিক্স করা
cd device/oneplus/hotdogb
if [ -f lineage_hotdogb.mk ]; then
    echo "Renaming lineage_hotdogb.mk to infinity_hotdogb.mk..."
    mv lineage_hotdogb.mk infinity_hotdogb.mk
fi

if [ -f infinity_hotdogb.mk ]; then
    # প্রোডাক্ট নাম পরিবর্তন করা
    sed -i 's/lineage_hotdogb/infinity_hotdogb/g' infinity_hotdogb.mk
    
    # রমের আসল কনফিগারেশন ফাইলটি খুঁজে বের করে মেকফাইলে পাথ সেট করা
    echo "Checking core Infinity config file location..."
    cd ../../.. # মেইন ডিরেক্টরিতে ব্যাক করা
    
    if [ -f vendor/infinity/config/common.mk ]; then
        CONF_PATH="vendor\/infinity\/config\/common.mk"
    elif [ -f vendor/infinity/config/common_full_phone.mk ]; then
        CONF_PATH="vendor\/infinity\/config\/common_full_phone.mk"
    elif [ -f vendor/infinity/config/infinity.mk ]; then
        CONF_PATH="vendor\/infinity\/config\/infinity.mk"
    else
        # যদি কোনোটিই না মেলে, তবে ইনফিনিটি রমের ডিরেক্টরিতে যা আছে তা ডাইনামিকালি নিবে
        DETECTED_MK=$(ls vendor/infinity/config/*.mk 2>/dev/null | head -n 1)
        if [ ! -z "$DETECTED_MK" ]; then
            CONF_PATH=$(echo "$DETECTED_MK" | sed 's/\//\\\//g')
        else
            CONF_PATH="vendor\/infinity\/config\/common.mk" # ফলব্যাক
        fi
    fi
    
    # মেকফাইলে সঠিক পাথটি রিপ্লেস করা
    echo "Setting config path to: $CONF_PATH"
    cd device/oneplus/hotdogb
    sed -i "s|inherit-product, vendor/.*\.mk|inherit-product, $CONF_PATH|g" infinity_hotdogb.mk
    sed -i "s|vendor/infinity/config/common_full_phone.mk|$CONF_PATH|g" infinity_hotdogb.mk
    sed -i "s|vendor/lineage/config/common_full_phone.mk|$CONF_PATH|g" infinity_hotdogb.mk
fi

# ২. AndroidProducts.mk আপডেট
if [ -f AndroidProducts.mk ]; then
    sed -i 's/lineage_hotdogb/infinity_hotdogb/g' AndroidProducts.mk
fi
cd ../../..

# লাঞ্চ লুপ এড়াতে অপ্রয়োজনীয় vendorsetup.sh রিমুভ করা
rm -f device/oneplus/hotdogb/vendorsetup.sh || true
rm -f device/oneplus/sm8150-common/vendorsetup.sh || true
