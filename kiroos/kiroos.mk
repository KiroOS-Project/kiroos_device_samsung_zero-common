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
    $(KIROOS_COMMON)/bin/kiroos_dexopt.sh:system/bin/kiroos_dexopt.sh \
    $(KIROOS_COMMON)/bin/kiroos_doze.sh:system/bin/kiroos_doze.sh \
    $(KIROOS_COMMON)/media/bootanimation.zip:system/media/bootanimation.zip

# Vulkan 1.0: the Mali-T760 driver (DDK r15p0) has Vulkan inside libGLES_mali.so, reached
# through the vulkan.exynos5.so HAL link (in the zero blobs; zenltexx/vulkan/Android.mk for the
# edge+); declaring the features lets apps and the loader use it. The version is declared per
# device (device.mk): both the zero and the noble driver report 1.0.26.
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.vulkan.level-0.xml:system/etc/permissions/android.hardware.vulkan.level.xml

# Beta 4: low latency audio. The fast output (256 frames, FastMixer) and the fast capture
# (audio_policy.conf "fast" input, FastCapture) were there, but without the feature apps
# (games, instruments, OpenSL ES / Oboe audio) never took the fast path.
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.audio.low_latency.xml:system/etc/permissions/android.hardware.audio.low_latency.xml

PRODUCT_PROPERTY_OVERRIDES += \
    wifi.supplicant_scan_interval=180 \
    ro.webview.provider=com.kiroos.webview \
    log.tag.RILD=F \
    log.tag.Sensors=F \
    persist.sys.kiroos.perf=balanced

# First boot after a KiroOS update: only extract the apps instead of verifying every one
# before the lock screen (about 3 minutes with ~100 apps on the S6). Apps verify what they
# use at run time and background dexopt compiles them (speed-profile) while idle and
# charging. Overrides the verify-profile of core_minimal.mk (default.prop).
PRODUCT_PROPERTY_OVERRIDES += \
    pm.dexopt.boot=verify-at-runtime

# Beta 3: the KiroOS recovery is restored at boot if something else replaced it (init.kiroos.rc;
# 1 keeps another recovery, for developers)
PRODUCT_PROPERTY_OVERRIDES += \
    persist.sys.kiroos.keeprecovery=0

# kAI 1.1 on-device models ("Keng 1.5" Flash-Lite Live / Lite / Pro) and the speech
# model, run inside the kAI app by llama.cpp / whisper.cpp (JNI). Fetched by
# /home/icholas/kai/kiro_fetch_models.sh and kiro_fetch_keng_live.sh into vendor/kiroos/kai, kept
# out of git for their size; /data/kiroos/models links to them.
KIROOS_KAI := vendor/kiroos/kai
KIROOS_KAI_FILES := \
    qwen3-0.6b-q4_k_m.gguf \
    smollm2-135m-instruct-q4_k_m.gguf \
    llama-3.2-1b-instruct-q4_k_m.gguf \
    whisper-base-q5_1.bin \
    NOTICE.txt \
    LICENSE-Qwen3.txt \
    LICENSE-Llama-3.2.txt \
    LICENSE-whisper.txt
PRODUCT_COPY_FILES += \
    $(foreach f,$(KIROOS_KAI_FILES),$(if $(wildcard $(KIROOS_KAI)/$(f)),$(KIROOS_KAI)/$(f):system/usr/share/kai/$(f)))

# KiroOS v1.0 app suite (packages/apps/KiroOS/*) and the stock apps it replaces
$(call inherit-product, packages/apps/KiroOS/kiroos_apps.mk)

# Google Apps (GApps) integration
$(call inherit-product-if-exists, vendor/google/gapps.mk)
