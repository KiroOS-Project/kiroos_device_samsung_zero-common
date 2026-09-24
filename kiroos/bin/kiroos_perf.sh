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

setprop sys.kiroos.perf.applied "$profile"
