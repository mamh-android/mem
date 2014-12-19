#!/bin/bash
# FIXME: Fix procrank & librank not found issue
. $(dirname "$0")/common.sh

# Filter out '\r' and '\0' in  "adb shell" output
adb_shell()
{
    adb shell "$@" |sed 's/\r//g;s/\x0/ /g'
}

# There may be two different 'su' commands on device:
# $ su -c 'ls -l'    OR
# $ su -c ls -l
# Check which type of `su' command is on device
su_exists=1
su_support_multiple_argument=1

check_su_parameter_type()
{
    out=$(adb_shell 'su -c ls -l' |head -1)
    if [[ $out =~ not\ found ]]; then
        su_exists=0
    elif [[ $out =~ ^su:\ exec\ failed ]]; then
        su_support_multiple_argument=0
    fi
}

# Quote input string for `adb shell su -c *' command
# Relies on predetermined su commands status
# $1: string to be quoted
# FIXME: Double quote the original '"' character in input string?
sudo_cmd()
{
    local cmd

    if [ $su_exists -eq 0 ]; then
        # Fallback to original command to run
        cmd="$1"
    elif [ $su_support_multiple_argument -eq 0 ]; then
        # `su -c' on device does not support multiple arguments, quote all arguments as single argument
        cmd="su -c \"$1\""
    else
        cmd="su -c $1"
    fi
	echo "$cmd"
}

# Run a adb shell command
# $1: Title
# $2: command to run
run()
{
	adb_shell "echo; echo ===$1===; $2"
}

print_prop()
{
    adb_shell "echo -n \"$1: \"; getprop $1"
}

# Dump all entries in a specified /sys or /proc node
# $1: Title
# $2: node name
dump_node()
{
    local cmd

    cmd=$(printf '
if [[ -d %s ]]; then
    cd %s
    for i in *; do
        echo -n "$i: "
        %s
    done
fi' "$2" "$2" "$(sudo_cmd 'cat $i')")
    run "$1" "$cmd"
}

check_su_parameter_type

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
run procrank "$(sudo_cmd procrank)"
run librank "$(sudo_cmd librank)"
run iomem 'cat /proc/iomem'
run vmallocinfo 'cat /proc/vmallocinfo'
run vmstat 'cat /proc/vmstat'
run zoneinfo 'cat /proc/zoneinfo'
run buddyinfo 'cat /proc/buddyinfo'
run pagetypeinfo 'cat /proc/pagetypeinfo'
run cmainfo 'cat /proc/cmainfo'
run slabinfo 'cat /proc/slabinfo'
run showslab "$(sudo_cmd 'showslab -s c')"
run slabinfo_alias "$(sudo_cmd 'slabinfo -a')"
run slabinfo_list "$(sudo_cmd 'slabinfo')"
run sysctl 'sysctl -a'
dump_node sysctl_vm /proc/sys/vm

# Debugfs info
adb_shell "$(sudo_cmd 'mount -t debugfs debugfs /sys/kernel/debug')"
run memblock "$(sudo_cmd 'cat /sys/kernel/debug/memblock/memory')"
run memblock_reserved "$(sudo_cmd 'cat /sys/kernel/debug/memblock/reserved')"
run ion_carveout "$(sudo_cmd 'cat /sys/kernel/debug/ion/heaps/carveout_heap')"
run ion_system "$(sudo_cmd 'cat /sys/kernel/debug/ion/heaps/system_heap')"

# Specified interface for other platforms
echo "Nodes for other platform, not exist on Marvell platform"
echo "------------------------------------------------------------"
dump_node mali /proc/mali
run mtk_ion_carveout "$(sudo_cmd 'cat /sys/kernel/debug/ion/ion_carveout_heap')"
run mtk_ion_mm "$(sudo_cmd 'cat /sys/kernel/debug/ion/ion_mm_heap')"
run mtk_ion_sys_contig "$(sudo_cmd 'cat /sys/kernel/debug/ion/ion_system_contig_heap')"

# dumpsys
run Dumpsys_SurfaceFlinger 'dumpsys SurfaceFlinger'
run Dumpsys_Meminfo 'dumpsys meminfo -a'
run Dumpsys_Procstats 'dumpsys procstats'
run Dumpsys_OOM 'dumpsys activity oom'

# Showmaps
sudo_cat_cmdline=$(sudo_cmd 'cat /proc/$i/cmdline')
sudo_showmap=$(sudo_cmd 'showmap $i')
sudo_cat_smaps=$(sudo_cmd 'cat /proc/$i/smaps')

showmap_cmd=$(printf 'cd /proc
for i in *; do
    if [ -f $i/smaps ]; then
        echo "PID: $i"
        %s
        %s
    fi
done' "$sudo_cat_cmdline" "$sudo_showmap")
run showmap "$showmap_cmd"

# Process maps and smaps
smaps_cmd=$(printf 'cd /proc
for i in *; do
    if [ -f $i/smaps ]; then
        echo "PID: $i"
        %s
        echo
        %s
    fi
done' "$sudo_cat_cmdline" "$sudo_cat_smaps")
run smaps "$smaps_cmd"
