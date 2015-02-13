#!/bin/bash
#Todo: Add cpufreq scaling min max detection

${0%/*}/meminfo.sh > meminfo.log
${0%/*}/summarize_meminfo.sh meminfo.log > suminfo.log

ADB="adb"

$ADB bugreport > dumpstate.log
$ADB shell getprop > properties.txt
$ADB shell 'su -c dmesg' > kernel.log
$ADB shell procrank > procrank.txt
$ADB shell librank > librank.txt
$ADB logcat -v threadtime -d > logcat.log
$ADB logcat -b events -v threadtime -d > events.log
