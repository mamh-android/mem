#!/bin/bash
# FIXME: Fix procrank & librank not found issue

# adb root > /dev/null
# sleep 2

# Filter out '\r' and '\0' in  "adb shell" output
function adb_shell()
{
    adb shell "$@" |sed 's/\r//g;s/\x0/ /g'
}

# Run a adb shell command
# $1: Title
# $2: command to run
function run()
{
	adb_shell "echo; echo ===$1===; $2"
}

function print_prop()
{
    adb_shell "echo -n \"$1: \"; getprop $1"
}

# Dump all entries in a specified /sys or /proc node
# $1: Title
# $2: node name
function dump_node()
{
    run "$1" "
if [[ -d $2 ]]; then
    cd $2"'
    for i in *; do
        echo -n "$i: "
        cat $i
    done
fi'
}

echo "----- Memory Info -----"
date '+%F %H:%M:%S'
adb_shell "getprop ro.build.display.id"
adb_shell "cat /proc/version"

echo -e "\nKK related info:"
print_prop sys.sysctl.extra_free_kbytes
print_prop ro.config.low_ram
print_prop dalvik.vm.jit.codecachesize
dump_node "KSM info" /sys/kernel/mm/ksm
run zram_info 'echo -n "ZRAM used memory (bytes): "; cat /sys/block/zram0/mem_used_total'
echo "Also see SwapFree and SwapTotal in meminfo below"

# Basic info
run meminfo 'cat /proc/meminfo'
run gc 'cat /proc/driver/gc'
run LMK_adj 'cat /sys/module/lowmemorykiller/parameters/adj'
run LMK_minfree 'cat /sys/module/lowmemorykiller/parameters/minfree'
run procrank procrank
run vmallocinfo 'cat /proc/vmallocinfo'
run vmstat 'cat /proc/vmstat'
run zoneinfo 'cat /proc/zoneinfo'
run buddyinfo 'cat /proc/buddyinfo'
run pagetypeinfo 'cat /proc/pagetypeinfo'
run cmainfo 'cat /proc/cmainfo'
run slabinfo 'cat /proc/slabinfo'
dump_node sysctl_vm /proc/sys/vm

# Debugfs info
# FIXME: find better way to handle two different of 'su' command issue
run memblock 'cat /sys/kernel/debug/memblock/memory'
run memblock_reserved 'cat /sys/kernel/debug/memblock/reserved'
run ion 'cat /sys/kernel/debug/ion/carveout_heap'

# dumpsys
run Dumpsys_Meminfo 'dumpsys meminfo'
