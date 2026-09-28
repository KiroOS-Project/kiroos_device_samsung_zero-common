#!/system/bin/sh
#
# KiroOS: Doze timings for a better standby. Stock N waits 30 min of stillness before deep
# idle (and 5 min before light idle); KiroOS gets there in about 15 (3 for light idle).
# Written only when nobody else set device_idle_constants (ours carry kiroos=1).
#
cur=$(settings get global device_idle_constants)
case "$cur" in
    ""|null|kiroos=*)
        settings put global device_idle_constants \
            "kiroos=1,light_after_inactive_to=180000,inactive_to=900000,sensing_to=120000,locating_to=15000,motion_inactive_to=300000,idle_after_inactive_to=900000"
        ;;
esac
