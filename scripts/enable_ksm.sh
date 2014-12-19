#!/bin/bash
# Enables KSM feature on device, or
# Use "enable_ksm.sh 0" to disable KSM feature

adb_root

if [ "$1" == "0" ]; then
    adb shell 'echo 0 > /sys/kernel/mm/ksm/run'
else
    adb shell 'echo 100 > /sys/kernel/mm/ksm/pages_to_scan'
    adb shell 'echo 50 > /sys/kernel/mm/ksm/sleep_millisecs'
    adb shell 'echo 1 > /sys/kernel/mm/ksm/run'
fi
