#!/system/bin/sh
#
# KiroOS local diagnostics.
# Saves system logs in internal storage, folder KiroOS/diagnostics/<date>-<mode>/
# Nothing is ever sent anywhere.
#
#   setprop debug.kiroos.diag snapshot   logcat, dmesg, kernel panic logs, battery, memory, thermal
#   setprop debug.kiroos.diag monitor    thermal/CPU/battery sampled every 10 s for 10 minutes
#   (automatic at boot)                  kernel log of the previous boot, if it ended with a panic
#
# The last 10 reports are kept.

MODE=${1:-snapshot}
BASE=/data/media/0/KiroOS/diagnostics
STAMP=$(date +%Y%m%d-%H%M%S)
DIR=$BASE/$STAMP-$MODE
mkdir -p $DIR

thermal() {
    for z in /sys/class/thermal/thermal_zone*; do
        [ -f $z/temp ] && echo "$(cat $z/type 2>/dev/null) $(cat $z/temp 2>/dev/null)"
    done
}

cpu() {
    for c in /sys/devices/system/cpu/cpu[0-9]*; do
        f=$(cat $c/cpufreq/scaling_cur_freq 2>/dev/null)
        echo "$(basename $c) online=$(cat $c/online 2>/dev/null) freq=${f:-off}"
    done
}

battery() {
    for f in capacity status temp current_now voltage_now; do
        echo "$f=$(cat /sys/class/power_supply/battery/$f 2>/dev/null)"
    done
}

# Kernel log of the previous boot: panics, watchdog resets, thermal shutdowns
previous_boot() {
    [ -f /proc/last_kmsg ] && cat /proc/last_kmsg > $DIR/last_kmsg.txt
    for f in /sys/fs/pstore/*; do
        [ -f "$f" ] && cat "$f" > $DIR/pstore-$(basename $f).txt
    done
    [ -f /cache/recovery/last_log ] && cp /cache/recovery/last_log $DIR/recovery_last_log.txt
}

case $MODE in
    snapshot)
        getprop > $DIR/properties.txt
        logcat -d -b all -v threadtime > $DIR/logcat.txt 2>&1
        dmesg > $DIR/dmesg.txt 2>&1
        previous_boot
        { echo "== uptime"; cat /proc/uptime
          echo "== thermal (millidegrees)"; thermal
          echo "== cpu"; cpu
          echo "== battery"; battery
          echo "== meminfo"; cat /proc/meminfo
          echo "== zram"; for f in disksize orig_data_size compr_data_size mem_used_total num_reads num_writes; do
              echo "$f=$(cat /sys/block/zram0/$f 2>/dev/null)"; done
          echo "== swap"; cat /proc/swaps
        } > $DIR/system.txt 2>&1
        dumpsys batterystats --charged > $DIR/batterystats.txt 2>&1
        dumpsys power > $DIR/power.txt 2>&1
        dumpsys meminfo > $DIR/meminfo.txt 2>&1
        dumpsys deviceidle > $DIR/deviceidle.txt 2>&1
        ;;
    monitor)
        i=0
        while [ $i -lt 60 ]; do
            { echo "== $(date +%H:%M:%S)"; thermal; cpu; battery; } >> $DIR/monitor.txt 2>&1
            i=$((i + 1))
            sleep 10
        done
        ;;
    boot)
        # Only when the previous boot ended badly (panic, watchdog, thermal shutdown)
        if grep -qiE "kernel panic|watchdog|internal error|thermal.*shutdown|upload mode" \
                /proc/last_kmsg /sys/fs/pstore/* 2>/dev/null; then
            previous_boot
        else
            rm -rf $DIR
            exit 0
        fi
        ;;
esac

# Readable from the phone and over USB (MTP)
chown -R media_rw:media_rw $BASE 2>/dev/null
chmod -R 0775 $BASE 2>/dev/null

# Keep only the last 10 reports
ls -1d $BASE/*/ 2>/dev/null | sort -r | tail -n +11 | while read old; do rm -rf "$old"; done

setprop debug.kiroos.diag done
