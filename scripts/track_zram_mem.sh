#!/bin/bash
# This script tracks zRAM memory savings. It shows Realfree memory and 'Pss +
# zRAM used' memory as an indicator of how zRAM saves memory. Unit is MB, and
# output is like this:
# Realfree	Pss_plus_zRAM
# 135.0	141.5
# 135.0	141.7
# 135.0	141.7
# <...>

# Filter out '\r' and '\0' in  "adb shell" output
adb_shell()
{
    adb shell "$@" |sed 's/\r//g;s/\x0/ /g'
}

# Parse /proc/meminfo items
get_meminfo_value()
{
	perl -nale "BEGIN { \$val=0; }
                if (/^$1/) {\$val = \$F[1]; last}
                END { print \$val; }" $2
}

calc()
{
    echo "$@" | bc -l
}

convert_KB_to_MB()
{
    calc "$1/1024"
}

file=$(mktemp)

printf "Realfree\tPss_plus_zRAM\n"
while true; do
    adb_shell 'cat /proc/meminfo' > $file

    # Get real free memory
    memfree=$(get_meminfo_value "MemFree:" "$file")
    buffers=$(get_meminfo_value "Buffers:" "$file")
    cached=$(get_meminfo_value "Cached:" "$file")
    mapped=$(get_meminfo_value "Mapped:" "$file")
    anonpages=$(get_meminfo_value "AnonPages:" "$file")

    free_cache_buffer=$(($memfree+$cached+$buffers))
    realfree=$(($free_cache_buffer-$mapped))
    # echo free_cache_buffer $free_cache_buffer
    # echo mapped $mapped
    # echo anonpages $anonpages

    # Get zRAM used + total Pss
    meminfo_pss_total=$(($anonpages+$mapped))
    zram_used_bytes=$(adb_shell cat /sys/block/zram0/mem_used_total)
    zram_used=$(printf "%.0f" $(calc "$zram_used_bytes/1024"))
    # echo zram_used $zram_used
    zram_pss=$(($meminfo_pss_total+$zram_used))
    # echo pss $meminfo_pss_total

    printf "%.1f\t%.1f\n" $(convert_KB_to_MB $realfree) $(convert_KB_to_MB $zram_pss)

    sleep 2
done

rm $file
