#
# KiroOS product layer, shared by the whole Galaxy S6 family:
#   zero  family (device/samsung/universal7420-common): S6 zerofltexx, S6 edge zeroltexx
#   noble family (device/samsung/noblelte-common):      S6 edge+ zenltexx
# Device trees inherit this after their hardware common tree.
#

KIROOS_COMMON := device/samsung/universal7420-common/kiroos

# Overlays: Pure Black theme, wallpaper, framework defaults
DEVICE_PACKAGE_OVERLAYS += $(KIROOS_COMMON)/overlay

# Init: I/O, zram swap, diagnostics, wake gestures, touchkeys, battery profiles, Game Space
PRODUCT_COPY_FILES += \
    $(KIROOS_COMMON)/init.kiroos.rc:root/init.kiroos.rc \
    $(KIROOS_COMMON)/bin/kiroos_diag.sh:system/bin/kiroos_diag.sh \
    $(KIROOS_COMMON)/bin/init.btmac.sh:system/bin/init.btmac.sh \
    $(KIROOS_COMMON)/bin/kiroos_perf.sh:system/bin/kiroos_perf.sh \
    $(KIROOS_COMMON)/media/bootanimation.zip:system/media/bootanimation.zip

# Vulkan 1.0: the Mali-T760 r12 vendor driver ships vulkan.exynos5.so (HAL) in both
# families' blobs; declaring the features lets apps and the loader use it.
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.vulkan.level-0.xml:system/etc/permissions/android.hardware.vulkan.level.xml \
    frameworks/native/data/etc/android.hardware.vulkan.version-1_0_3.xml:system/etc/permissions/android.hardware.vulkan.version.xml

PRODUCT_PROPERTY_OVERRIDES += \
    wifi.supplicant_scan_interval=180 \
    ro.webview.provider=com.android.webview \
    log.tag.RILD=F \
    log.tag.Sensors=F \
    persist.sys.kiroos.perf=balanced

# First boot after a KiroOS update: only extract the apps instead of verifying every one
# before the lock screen (about 3 minutes with ~100 apps on the S6). Apps verify what they
# use at run time and background dexopt compiles them (speed-profile) while idle and
# charging. Overrides the verify-profile of core_minimal.mk (default.prop).
PRODUCT_PROPERTY_OVERRIDES += \
    pm.dexopt.boot=verify-at-runtime

# kAI on-device model: llama.cpp server + Qwen2.5 0.5B (built/fetched by kiro_kai_build.sh
# into vendor/kiroos/kai, kept out of git for its size). kAI starts the server only while
# it is open; without these files it falls back to the PC over USB.
KIROOS_KAI := vendor/kiroos/kai
ifneq ($(wildcard $(KIROOS_KAI)/kai_llama),)
PRODUCT_COPY_FILES += \
    $(KIROOS_KAI)/kai_llama:system/bin/kai_llama \
    $(KIROOS_KAI)/qwen2.5-0.5b-instruct-q4_k_m.gguf:system/usr/share/kai/qwen2.5-0.5b-instruct-q4_k_m.gguf \
    $(KIROOS_KAI)/LICENSE-Qwen2.5.txt:system/usr/share/kai/LICENSE.txt
endif

# KiroOS v1.0 app suite (packages/apps/KiroOS/*) and the stock apps it replaces
$(call inherit-product, packages/apps/KiroOS/kiroos_apps.mk)

# Google Apps (GApps) integration
$(call inherit-product-if-exists, vendor/google/gapps.mk)
