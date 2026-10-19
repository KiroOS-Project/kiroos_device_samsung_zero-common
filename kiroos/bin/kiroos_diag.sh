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

# Beta 4.1: a light battery log, always on (service kiroos_battlog): one line a minute with the
# charge, voltage, current, the gauge's own values, the cable, USB and the Battery Guardian, in
# /data/kiroos/battlog.txt (256 KB, the previous one kept as .1). When the reported charge moves
# by more than 5% in a minute, the kernel's battery messages of that moment go to
# battlog_events.txt. Nothing leaves the phone. It is there so a wrong charge (Beta 4.1 test:
# 18% shown, 62% real, no charging, no USB until a restart) can be traced after the fact.
if [ "$MODE" = battlog ]; then
    L=/data/kiroos/battlog.txt
    E=/data/kiroos/battlog_events.txt
    B=/sys/class/power_supply/battery
    last=
    while true; do
        cap=$(cat $B/capacity 2>/dev/null)
        line="$(date '+%m-%d %H:%M:%S') up=$(cut -d' ' -f1 /proc/uptime) cap=$cap"
        line="$line st=$(cat $B/status 2>/dev/null) mv=$(( $(cat $B/voltage_now 2>/dev/null || echo 0) / 1000 ))"
        line="$line ma=$(cat $B/current_now 2>/dev/null) avg=$(cat $B/current_avg 2>/dev/null)"
        line="$line t=$(cat $B/temp 2>/dev/null) fg=[$(cat $B/fg_capacity 2>/dev/null)]"
        line="$line usb=$(cat /sys/class/power_supply/usb/online 2>/dev/null) ac=$(cat /sys/class/power_supply/ac/online 2>/dev/null)"
        line="$line src=$(cat $B/batt_charging_source 2>/dev/null) kcharge=$(cat $B/batt_kiro_charge 2>/dev/null)"
        line="$line kcap=$(cat $B/batt_kiro_cap 2>/dev/null) guard=$(getprop sys.kiroos.guard.charge)/$(getprop sys.kiroos.guard.thermal)"
        line="$line usbstate=$(getprop sys.usb.state) perf=$(getprop sys.kiroos.perf.applied)"
        echo "$line" >> $L
        if [ -n "$last" ] && [ -n "$cap" ] && { [ $((cap - last)) -gt 5 ] || [ $((last - cap)) -gt 5 ]; }; then
            { echo "== $(date '+%m-%d %H:%M:%S') charge $last -> $cap"
              dmesg | grep -iE 'soc|fuel|vfsoc|compens|kiro|charg|cable|muic|batt' | tail -120
            } >> $E
        fi
        last=$cap
        for f in $L $E; do
            [ -f $f ] && [ $(stat -c %s $f) -gt 262144 ] && mv -f $f $f.1
        done
        sleep 60
    done
fi

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
