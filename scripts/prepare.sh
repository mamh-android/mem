#!/bin/sh
adb root
sleep 2
adb wait-for-device

# Need this step to make sure "adb shell" works now
adb shell echo root done.

adb remount

~/work/misc/prebuilt_tools/install_busybox.sh
echo busybox installed.

adb push ~/work/misc/prebuilt_tools/memtest/ /system/xbin/
echo memory test binaries copied.
