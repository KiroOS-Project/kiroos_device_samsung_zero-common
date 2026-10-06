#!/system/bin/sh
#
# KiroOS: compile the apps after a system update.
#
# The boot after an update only verifies the apps (pm.dexopt.boot=verify-at-runtime), so it is
# quick, but until Android's nightly job (idle + charging) compiles them the apps run
# interpreted/JIT and the whole UI is slower. Once per build, a couple of minutes after boot,
# this compiles the apps that draw the UI with "speed" and everything else with
# "speed-profile" (only the code the profiles saw being used), at low priority.
#

# KeurStore: one app just installed (sys.kiroos.guard.optimize = its package), compiled now
if [ "$1" = optimize ]; then
    pkg=$(getprop sys.kiroos.guard.optimize)
    case "$pkg" in
        *[!A-Za-z0-9._]*|"") exit 0 ;;
    esac
    nice -n 10 cmd package compile -m speed "$pkg" >/dev/null 2>&1
    exit 0
fi

build=$(getprop ro.build.date.utc)
[ "$(getprop persist.sys.kiroos.dexopt_build)" = "$build" ] && exit 0

# let the boot settle (launcher, SystemUI, services) before taking CPU time. Beta 3: half a
# minute, since the boot itself now prepares only the apps that run at once (the others run
# from their APK until they are compiled here)
sleep 30

# (SystemUI, Kiro Home, the keyboard and Settings are compiled with "speed" during the boot
# itself since Beta 3, under the boot animation's bar: PackageManagerService kiroBootCompileUi)
for p in com.kiroos.phone com.kiroos.messages com.kiroos.kai com.kiroos.camera; do
    nice -n 10 cmd package compile -m speed "$p" >/dev/null 2>&1
done
nice -n 10 cmd package compile -m speed-profile -a >/dev/null 2>&1

setprop persist.sys.kiroos.dexopt_build "$build"
