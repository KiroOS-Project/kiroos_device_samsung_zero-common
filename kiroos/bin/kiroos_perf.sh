#!/system/bin/sh
#
# KiroOS battery profiles for the Exynos 7420 (4x Cortex-A53 @1.5 GHz + 4x Cortex-A57 @2.1 GHz,
# Mali-T760 MP8 @772 MHz). Applied by init when persist.sys.kiroos.perf changes.
#
# The limits go through Samsung's mp-cpufreq cluster QoS nodes and the Mali DVFS locks, which
# stack with (never overwrite) the scaling_max_freq the power HAL manages, so touch boost and
# the thermal/IPA throttling keep working in every profile.
#
#   saving       A53 <= 1.2 GHz, A57 <= 1.2 GHz, GPU 266-420 MHz, relaxed ramp
#   balanced     stock CPU limits, GPU >= 350 MHz, quick ramp, touch boost held while touching
#   performance  A53 >= 0.8 GHz, A57 >= 1.2 GHz floors, GPU >= 350 MHz, fast ramp
#   extreme      A53 >= 1.3 GHz, A57 >= 1.7 GHz floors, GPU 544-772 MHz, fastest ramp
#   screen off   (any profile) no floors, A53 and A57 <= 1.2 GHz
#
# Every profile runs the interactive governor, only its tuning changes. Never switch governor:
#  - switching tears down the interactive sysfs nodes; the power HAL opened boostpulse once at
#    boot, so after Saving (then "conservative") the touch / app launch boost was dead in every
#    profile until the next reboot: Balanced stuttered because it ran with no touch boost at all;
#  - the "performance" governor on this kernel ignores the frequency QoS once set, so a cap
#    taken with the screen off (1.2 GHz on the A53) stuck for good.
#

MP=/sys/devices/system/cpu/cpufreq/mp-cpufreq
GPU=/sys/devices/14ac0000.mali

w() { [ -w "$1" ] && echo "$2" > "$1"; }

# Interactive on both clusters. Only if something else left another governor: then the nodes
# were just recreated root-only, give them back to the power HAL (system) like init.power.rc.
interactive() {
    for c in 0 4; do
        f=/sys/devices/system/cpu/cpu$c/cpufreq/scaling_governor
        [ -e "$f" ] || continue
        [ "$(cat $f)" = interactive ] && continue
        w $f interactive
        chown system:system /sys/devices/system/cpu/cpu$c/cpufreq/interactive/*
        chmod 0660 /sys/devices/system/cpu/cpu$c/cpufreq/interactive/*
    done
}

# tune <cpu> <hispeed_freq> <go_hispeed_load> <target_loads> <above_hispeed_delay>
#      <min_sample_time> <boostpulse_duration>
# The kernel keeps 4 parameter sets and switches the big cluster to set 1-3 by itself under
# heavy load (single / multi thread mode); init only tunes set 0, so those modes fell back to
# the kernel defaults (hispeed at max, target load 90%): the same tuning goes in every set.
# A cluster that is hotplugged out keeps the values it had; the next run (screen on/off) lands.
tune() {
    d=/sys/devices/system/cpu/cpu$1/cpufreq/interactive
    [ -d $d ] || return
    for i in 0 1 2 3; do
        w $d/param_index $i
        w $d/hispeed_freq $2
        w $d/go_hispeed_load $3
        w $d/target_loads "$4"
        w $d/above_hispeed_delay "$5"
        w $d/min_sample_time $6
        w $d/timer_rate 20000
    done
    w $d/param_index 0
    w $d/boostpulse_duration $7
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

# gpu <highspeed_clock MHz> <highspeed_load %> <down_staycount> <max clock MHz>
# The Mali "interactive" DVFS (polled every 30 ms) climbs one step per poll when a level is
# more than 85% busy (266 -> 700 MHz took ~180 ms, the first frames of a game at low clock) and
# jumps to highspeed_clock only above highspeed_load (stock 420 MHz at 95%). down_staycount is
# how many polls a busy level is held before stepping down: 1 made the clock see-saw between
# two steps under a steady game load, which is uneven frame pacing. Same for Vulkan and GLES.
# The max clock (kernel kiro_max_clock_limit, device tree 700) lets a GPU saturated at 700 MHz
# step up to 772 MHz; Samsung's hardware counter boost that reached it skips compute (OpenCL).
gpu() {
    w $GPU/kiro_max_clock_limit $4
    w $GPU/highspeed_clock $1
    w $GPU/highspeed_load $2
    for c in 772 700 600 544 420; do
        w $GPU/down_staycount "$c $3"
    done
}

interactive

# Tuning (timer 20 ms; a frame is 16.7 ms). Android sends a touch hint at most every 100 ms,
# so a boostpulse of 120 ms or more holds the boost for as long as the finger moves; below
# that the clock dipped between hints, which is the stutter of a scroll. min_sample_time is
# how long a speed is held before stepping down: too short and the clock saw-tooths between
# frames. Stock (init.power.rc): A53 900 MHz / 85 / 75, A57 1.2 GHz / 89 / "65 1.5G:75",
# min_sample_time 40 ms, boostpulse 40 ms.
profile=$(getprop persist.sys.kiroos.perf)
case "$profile" in
    saving)
        #    cpu hispeed go  target_loads            above_hispeed_delay      sample boost
        tune 0   900000  90 "80 1000000:90"          40000                    40000  80000
        tune 4   1000000 90 "80"                     40000                    40000  80000
        # GPU floor 266 MHz: from its 100 MHz idle step even a list scroll dropped frames
        limits 1200000 1200000 400000 800000 420 266
        gpu 420 95 1 700
        ;;
    performance)
        tune 0   1296000 75 "60 1296000:75"          20000                    80000  200000
        tune 4   1500000 80 "60 1800000:75"          "20000 1800000:40000"    80000  200000
        limits 1500000 2100000 800000 1200000 0 350
        gpu 600 80 3 700
        ;;
    extreme)
        tune 0   1500000 70 "50"                     20000                    80000  300000
        tune 4   1800000 75 "55"                     20000                    80000  300000
        limits 1500000 2100000 1296000 1704000 0 544
        gpu 700 75 3 772
        ;;
    *)
        profile=balanced
        tune 0   1000000 80 "70 1000000:80 1296000:90" "20000 1296000:40000"  60000  120000
        tune 4   1300000 85 "65 1500000:75 1800000:85" "20000 1500000:40000 1800000:80000" 60000 120000
        # GPU floor 350 MHz: from its lowest step the Mali ramps up too late and scrolling
        # janks (measured on the home: 13-35% janky frames -> 0-1%); the GPU is power-gated
        # whenever nothing is drawn, so the floor only costs while the screen animates
        limits 1500000 2100000 400000 800000 0 350
        gpu 544 85 2 700
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
