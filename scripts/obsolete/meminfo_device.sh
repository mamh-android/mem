#!/system/bin/sh

function run()
{
	echo; echo ===$1===; $2
}

echo "----- Memory Info -----"

run meminfo 'cat /proc/meminfo'
run gc 'cat /proc/driver/gc'
run LMK_adj 'cat /sys/module/lowmemorykiller/parameters/adj'
run LMK_minfree 'cat /sys/module/lowmemorykiller/parameters/minfree'
run procrank procrank
run librank librank
run iomem 'cat /proc/iomem'
run vmallocinfo 'cat /proc/vmallocinfo'
run vmstat 'cat /proc/vmstat'
run zoneinfo 'cat /proc/zoneinfo'
run buddyinfo 'cat /proc/buddyinfo'
run pagetypeinfo 'cat /proc/pagetypeinfo'
run cmainfo 'cat /proc/cmainfo'
run slabinfo 'cat /proc/slabinfo'
run sysctl 'sysctl -a'
run sysctl_vm ''; cd /proc/sys/vm; for i in *; do echo -n "$i: "; cat $i; done

# Debugfs info
mount -t debugfs debugfs /sys/kernel/debug
run memblock 'cat /sys/kernel/debug/memblock/memory'
run memblock_reserved 'cat /sys/kernel/debug/memblock/reserved'
run ion 'cat /sys/kernel/debug/ion/carveout_heap'
run SurfaceFlinger 'dumpsys SurfaceFlinger'

# Process maps and smaps
run smaps ''; cd /proc; for i in *; do if [ -f $i/smaps ]; then echo "PID: $i"; cat $i/cmdline; echo; showmap $i; dumpsys meminfo $i; fi; done
