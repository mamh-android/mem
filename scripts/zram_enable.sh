#!/bin/bash
# Enables zRAM feature on device, or
# Use "zram_enable.sh 0" to disable zRAM feature
. $(dirname "$0")/common.sh

adb_root

if [ "$1" == "0" ]; then
    adb shell 'swapoff /dev/block/zram0'
else
    adb shell 'swapon /dev/block/zram0'
fi
