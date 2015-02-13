#!/bin/bash
# Summarize memory usage break down data from raw memory data file
#
# Note:
# - Realfree means normal free memory (free+cached+buffers) - "Mapped in /proc/meminfo",
#   which can be added up with Pss calculation with no overlap
#
# Todo:
# - Combine get_*() functions to general get_value() which read value of specified "key"
# - Better to rewrite this whole file with python etc. and reduce the total parse times

exec_dir=$(basename "$0")

# Parse /proc/meminfo items
get_meminfo_value()
{
	perl -nale "BEGIN { \$val=0; }
                if (/^$1/) {\$val = \$F[1]; last}
                END { print \$val; }" $2
}

# Parse /proc/driver/gc items
get_gc_value()
{
	perl -nale "BEGIN { \$val=0; }
                if (/$1/) {\$val = \$F[2]; last}
                END { print \$val; }" $2
}

# Parse /proc/driver/gc GC total item
get_gc_total()
{
	perl -nale "BEGIN { \$val=0; }
                if (/$1/) {\$val = \$F[3]; last}
                END { print \$val; }" $2
}

get_procrank_pss_total()
{
    # The appendix of 'K' removed
	perl -nale 'BEGIN { $val=0; }
                if (/TOTAL$/) {
                    $val = substr($F[0], 0, -1);
                    last;
                }
                END { print $val; }' $1
}

# Get PSS of those processes that are unnecessary for customer and should be removed from total PSS
get_pss_unnecessary()
{
    perl -nale 'BEGIN {$total=0;}
                if (/procrank$/ || /com.marvell.gpssetting$/ || /com.marvell.powersetting$/ ||
                    /com.marvell.usbsetting$/ || /com.marvell.powermeter$/ || /com.marvell.android.location$/ ||
                    /com.android.onetimeinitializer$/) {
                    $total += substr($F[3], 0, -1);
                }
                END {print $total;}' $1
}

# Parse from dumpsys meminfo
get_zram_saved()
{
	perl -nale 'BEGIN { $val=0; }
                if (/ZRAM:/) {$val = $F[6]-$F[1]; last}
                END { print $val; }' $1
}

# Parse from dumpsys meminfo
get_ksm_saved()
{
	perl -nale 'BEGIN { $val=0; }
                if (/KSM:/) {$val = $F[1]; last}
                END { print $val; }' $1
}

# Parse from dumpsys meminfo
get_dumpsys_lost_ram()
{
	perl -nale 'BEGIN { $val=0; }
                if (/Lost RAM:/) {$val = $F[2]; last}
                END { print $val; }' $1
}

# Get CMA memory info in KB from /proc/cmainfo
# parameters: <item_index> <file_name>
get_cma_item()
{
	perl -nale 'BEGIN { $val=0; $found_cmainfo=0; $item = shift; }
                if (/cmainfo/) { $found_cmainfo = 1; }
                if ($found_cmainfo == 1 && /^Total:/) {
                    if (/pages/) {
                        $val = int $F[$item];
                    } else {
                        $val = hex $F[$item];
                    }
                    last;
                }
                END { print $val*4; }' $1 $2
}

get_cma_contigous()
{
    get_cma_item 2 $1
}

get_cma_total()
{
    get_cma_item 3 $1
}

get_ion_system_heap_total()
{
	perl -nale 'BEGIN { $val=0; $found_ion_system=0; }
                if (/ion_system/) { $found_ion_system = 1; }
                if ($found_ion_system == 1 && /total:/) {
                    $val = $F[3];
                    $val =~ s/\D+//g;
                    last;
                }
                END { print $val; }' $1
}

get_zram_used()
{
	perl -nale 'BEGIN { $val=0; }
                if (/ZRAM used memory/) {$val = $F[4]; last}
                END { print int $val/1024; }' $1
}


#Get vmalloc info from /proc/vmallocinfo node, items with 'pages=' are those
#really allocate physical pages
get_vmalloc_info()
{
    local str
    local vmalloc_info

	str=$(perl -nale 'BEGIN { $val=0; $found_vmallocinfo=0; }
                if (/vmallocinfo/) { $found_vmallocinfo = 1; }
                if ($found_vmallocinfo == 1) {
                    if (/^$/) { last; }
                    $pos0 = index $_, "pages=";
                    if ($pos0 > 0) {
                        $pos1 = index $_, " ", $pos0;
                        $pages= int (substr $_, $pos0 + 6, $pos1);
                        if (/module/) {
                            $module_pages += $pages;
                        } elsif (/create_log/) {
                            $logcat_pages += $pages;
                        } elsif (/gckOS/) {
                            $gc_pages += $pages;
                        } else {
                            $other_pages += $pages;
                        }
                    }
                }
                END { printf "%d %d %d %d", $module_pages*4, $logcat_pages*4, $gc_pages*4, $other_pages*4; }' $1)
    IFS=' ' read -a vmalloc_info <<< "$str"
    vmalloc_modules=${vmalloc_info[0]}
    vmalloc_logcat=${vmalloc_info[1]}
    vmalloc_gc=${vmalloc_info[2]}
    vmalloc_others=${vmalloc_info[3]}
    vmalloc_total=$(($vmalloc_modules+$vmalloc_logcat+$vmalloc_gc+$vmalloc_others))
}

calc()
{
    echo "$@" | bc -l
}

convert_KB_to_MB()
{
    calc "$1/1024"
}

# Print memory usage size (input unit is KB)
print_size()
{
    printf "$1: %s KB (%.1f MB)\n" "$2" $(convert_KB_to_MB "$2")
}

while [ "$1" != "" ]; do
	file=$1

	buffers=$(get_meminfo_value "Buffers:" "$file")
	cached=$(get_meminfo_value "Cached:" "$file")
	swapcached=$(get_meminfo_value "SwapCached:" "$file")

	active=$(get_meminfo_value "Active:" "$file")
	inactive=$(get_meminfo_value "Inactive:" "$file")
	anonpages=$(get_meminfo_value "AnonPages:" "$file")
	mapped=$(get_meminfo_value "Mapped:" "$file")

	memtotal=$(get_meminfo_value "MemTotal:" "$file")
    # Assuming that total reserved memory should be no more than 256 MB
    ddrtotal=$(echo "($memtotal+256*1024-1)/(256*1024)*(256*1024)" | bc)
	memfree=$(get_meminfo_value "MemFree:" "$file")
    free_cache_buffer=$(($memfree+$cached+$buffers))
    realfree=$(($free_cache_buffer-$mapped))

	slab=$(get_meminfo_value "Slab:" "$file")
	pagetables=$(get_meminfo_value "PageTables:" "$file")
	vmallocused=$(get_meminfo_value "VmallocUsed:" "$file")
	kernelstack=$(get_meminfo_value "KernelStack:" "$file")
    kernelused=$(($slab+$pagetables+$kernelstack))

	contig=$(get_gc_value "contiguousPaged:" "$file")
	contignon=$(get_gc_value "contiguousNonPaged:" "$file")
	gc_virtual=$(get_gc_value "virtualPaged:" "$file")

	diff1=$(($active+$inactive-($buffers+$cached+$swapcached+$anonpages)))
	# Check if MemTotal = MemFree + Active + Inactive + Slab + PageTables + VmallocUsed + X (X : alloc_pages() (get_free_pages(), etc))
	diff2=$(($memtotal-$memfree-$active-$inactive-$slab-$pagetables-$vmallocused-$kernelstack))
	gc_alloc=$(($contig+$contignon+$gc_virtual))

	gc_total=$(get_gc_total "GC Memory Sum:" "$file")

    pss_total=$(get_procrank_pss_total "$file")
    pss_unnecessary=$(get_pss_unnecessary "$file")
    meminfo_pss_total=$(($anonpages+$mapped))

    kernel_others_total=$(($memtotal-$kernelused-$meminfo_pss_total-$gc_alloc-$realfree))
    cma_contigous=$(get_cma_contigous "$file")
    cma_total=$(get_cma_total "$file")

    ion_system_heap_total=$(get_ion_system_heap_total "$file")
    zram_used=$(get_zram_used "$file")
    get_vmalloc_info "$file"
    kernel_unknown=$(($kernel_others_total-$cma_contigous-$vmalloc_total-$ion_system_heap_total-$zram_used))

    zram_saved=$(get_zram_saved "$file")
    ksm_saved=$(get_ksm_saved "$file")
    dumpsys_lost_ram=$(get_dumpsys_lost_ram "$file")

	echo -e "$file:\n-----------------"
    echo -e "\nBasic info:"
    print_size "DDR size" $ddrtotal
    print_size "Reserved memory" $((ddrtotal-memtotal))
    print_size "CMA total" $cma_total
	print_size "Free" $memfree
	print_size "Cached" $cached
	print_size "Buffers" $buffers
	print_size "Free+Cached+Buffers" $free_cache_buffer
	print_size "Real Free" $realfree
    echo -e "\nKernel:"
    print_size "Kernel Used" $kernelused
    print_size "  slab" $slab
    print_size "  pagetables" $pagetables
    print_size "  kernelstack" $kernelstack
    echo -e "\nKernel Others:"
    print_size "  CMA contigous" $cma_contigous
    print_size "  vmalloc total" $vmalloc_total
    print_size "    modules" $vmalloc_modules
    print_size "    logcat" $vmalloc_logcat
    print_size "    gc" $vmalloc_gc
    print_size "    others" $vmalloc_others
    print_size "  ION system heap" $ion_system_heap_total
    print_size "  zRAM used" $zram_used
    print_size "  Unknown" $kernel_unknown
    echo -e "\nGC:"
	print_size "GC Allocate" $gc_alloc
	print_size "GC Total" $gc_total
    echo -e "\nPss:"
    print_size "Procrank Pss Total" $pss_total
    print_size "Procrank Pss Total (filtered debug apps)" $(($pss_total-$pss_unnecessary))
    print_size "/proc/meminfo Pss Total" $meminfo_pss_total
    print_size "/proc/meminfo Pss Total (filtered debug apps)" $(($meminfo_pss_total-$pss_unnecessary))
    echo -e "\nSaved:"
	print_size "zRAM saved" $zram_saved
	print_size "KSM saved" $ksm_saved
    echo -e "\nDebug:"
    print_size "Diff1" $diff1
    echo

	shift
done
