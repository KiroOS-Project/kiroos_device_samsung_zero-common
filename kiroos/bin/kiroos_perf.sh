#!/system/bin/sh
#
# KiroOS battery profiles for the Exynos 7420 (4x Cortex-A53 @1.5 GHz + 4x Cortex-A57 @2.1 GHz,
# Mali-T760 MP8 @772 MHz). Applied by init when persist.sys.kiroos.perf changes.
#
# The limits go through Samsung's mp-cpufreq cluster QoS nodes and the Mali DVFS locks, which
# stack with (never overwrite) the scaling_max_freq the power HAL manages, so touch boost and
# the thermal/IPA throttling keep working in every profile.
#
#   saving       A53 <= 1.2 GHz, A57 <= 1.2 GHz, GPU <= 420 MHz, conservative governor
#   balanced     stock CPU limits, GPU >= 350 MHz, interactive governor
#   performance  A53 >= 0.8 GHz, A57 >= 1.2 GHz floors, GPU >= 350 MHz
#   extreme      A53 >= 1.3 GHz, A57 >= 1.7 GHz floors, GPU >= 544 MHz, interactive governor
#   screen off   (any profile) no floors, A53 and A57 <= 1.2 GHz
#
# Never the "performance" governor: on this kernel it ignores the frequency QoS once set, so a
# cap taken with the screen off (1.2 GHz on the A53) stuck for good, and the hotplug driver only
# brings the A57 cluster in when the A53 reach their maximum: extreme ran on 4 A53 at 1.2 GHz.
#

MP=/sys/devices/system/cpu/cpufreq/mp-cpufreq
GPU=/sys/devices/14ac0000.mali

w() { [ -w "$1" ] && echo "$2" > "$1"; }

governor() {
    for c in 0 1 2 3 4 5 6 7; do
        w /sys/devices/system/cpu/cpu$c/cpufreq/scaling_governor "$1"
    done
}

# limits <A53 max> <A57 max> <A53 min> <A57 min> <GPU max MHz|0> <GPU min MHz|0>
# Mali locks: 0 releases the lock (it then reads back as -1).
limits() {
    # order matters: lower the minimum before the maximum, raise the maximum before the minimum
    w $MP/cluster0_min_freq 400000
    w $MP/cluster1_min_freq 800000
    w $MP/cluster0_max_freq "$1"
    w $MP/cluster1_max_freq "$2"
    w $MP/cluster0_min_freq "$3"
    w $MP/cluster1_min_freq "$4"
    w $GPU/dvfs_min_lock 0
    w $GPU/dvfs_max_lock "$5"
    w $GPU/dvfs_min_lock "$6"
}

profile=$(getprop persist.sys.kiroos.perf)
case "$profile" in
    saving)
        limits 1200000 1200000 400000 800000 420 0
        governor conservative
        ;;
    performance)
        governor interactive
        limits 1500000 2100000 800000 1200000 0 350
        ;;
    extreme)
        governor interactive
        limits 1500000 2100000 1296000 1704000 0 544
        ;;
    *)
        profile=balanced
        governor interactive
        # GPU floor 350 MHz: from its lowest step the Mali ramps up too late and scrolling
        # janks (measured on the home: 13-35% janky frames -> 0-1%); the GPU is power-gated
        # whenever nothing is drawn, so the floor only costs while the screen animates
        limits 1500000 2100000 400000 800000 0 350
        ;;
esac

# Screen off (sys.kiroos.guard.screen=0, set by SystemUI): whatever the profile, no clock
# floors and the CPU capped at 1.2 GHz. Music, calls and syncs need far less; the floors of
# Performance / Extreme only make sense while the screen is on.
if [ "$(getprop sys.kiroos.guard.screen)" = "0" ]; then
    limits 1200000 1200000 400000 800000 0 0
fi

# Kiro Thermal Guardian (sys.kiroos.guard.thermal, set by SystemUI from the battery
# temperature): lower caps on top of the profile, lifted as soon as the phone cools down.
#   1  42 C: A53 <= 1.3 GHz, A57 <= 1.7 GHz, GPU <= 600 MHz (hardly noticeable)
#   2  47 C: A53 <= 1.2 GHz, A57 <= 1.4 GHz, GPU <= 420 MHz
#   3  50 C: A53 <= 1.0 GHz, A57 <= 1.0 GHz, GPU <= 350 MHz (cooling screen)
stage=$(getprop sys.kiroos.guard.thermal)
case "$stage" in
    1) w $MP/cluster0_max_freq 1296000; w $MP/cluster1_max_freq 1704000; w $GPU/dvfs_max_lock 600 ;;
    2) w $MP/cluster0_max_freq 1200000; w $MP/cluster1_max_freq 1400000; w $GPU/dvfs_max_lock 420 ;;
    3) w $MP/cluster0_max_freq 1000000; w $MP/cluster1_max_freq 1000000; w $GPU/dvfs_max_lock 350 ;;
esac
# a floor above a cap would pin the clock: floors never above the caps
if [ -n "$stage" ] && [ "$stage" != 0 ]; then
    c0max=$(cat $MP/cluster0_max_freq); c1max=$(cat $MP/cluster1_max_freq)
    [ "$(cat $MP/cluster0_min_freq)" -gt "$c0max" ] && w $MP/cluster0_min_freq "$c0max"
    [ "$(cat $MP/cluster1_min_freq)" -gt "$c1max" ] && w $MP/cluster1_min_freq "$c1max"
    w $GPU/dvfs_min_lock 0
fi

setprop sys.kiroos.perf.applied "$profile"
