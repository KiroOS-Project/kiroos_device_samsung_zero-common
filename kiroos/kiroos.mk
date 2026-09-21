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

# KiroOS v1.0 app suite (packages/apps/KiroOS/*) and the stock apps it replaces
$(call inherit-product, packages/apps/KiroOS/kiroos_apps.mk)

# Google Apps (GApps) integration
$(call inherit-product-if-exists, vendor/google/gapps.mk)
