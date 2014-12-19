#!/bin/bash
# Summarize data for given files

PATH=/bin:/usr/bin:/usr/local/bin:$PATH
export PATH

exec_dir=$(basename "$0")

get_value()
{
	perl -nale "BEGIN { \$val=0; }
                if (/^$1/) {\$val = \$F[1]; last}
                END { print \$val; }" $2
}

get_gc_value()
{
	perl -nale "BEGIN { \$val=0; }
                if (/$1/) {\$val = \$F[2]; last}
                END { print \$val; }" $2
}

get_pss_total()
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

get_zram_saved()
{
	perl -nale 'BEGIN { $val=0; }
                if (/ZRAM:/) {$val = $F[6]-$F[1];}
                END { print $val; }' $1
}

get_ksm_saved()
{
	perl -nale 'BEGIN { $val=0; }
                if (/KSM:/) {$val = $F[1];}
                END { print $val; }' $1
}

get_lost_ram()
{
	perl -nale 'BEGIN { $val=0; }
                if (/Lost RAM:/) {$val = $F[2];}
                END { print $val; }' $1
}

calc()
{
    echo "$@" | bc -l
}

convert_MB_to_KB()
{
    calc "$1/1024"
}

print_size()
{
    printf "$1: %s KB\n" "$2"
}

parse_meminfo()
{
	file=$1

	buffers=$(get_value "Buffers:" "$file")
	cached=$(get_value "Cached:" "$file")
	swapcached=$(get_value "SwapCached:" "$file")

	active=$(get_value "Active:" "$file")
	inactive=$(get_value "Inactive:" "$file")
	anonpages=$(get_value "AnonPages:" "$file")
	mapped=$(get_value "Mapped:" "$file")

	memtotal=$(get_value "MemTotal:" "$file")
    # Assuming that total reserved memory should be no more than 256 MB
    ddrtotal=$(echo "($memtotal+256*1024-1)/(256*1024)*(256*1024)" | bc)
	memfree=$(get_value "MemFree:" "$file")
    free_cache_buffer=$(($memfree+$cached+$buffers))
    realfree=$(($free_cache_buffer-$mapped))

	slab=$(get_value "Slab:" "$file")
	pagetables=$(get_value "PageTables:" "$file")
	vmallocused=$(get_value "VmallocUsed:" "$file")
	kernelstack=$(get_value "KernelStack:" "$file")
    kernelused=$(($slab+$pagetables+$kernelstack))

	contig=$(get_gc_value "contiguousPaged:" "$file")
	contignon=$(get_gc_value "contiguousNonPaged:" "$file")
	gc_virtual=$(get_gc_value "virtualPaged:" "$file")

	diff1=$(($active+$inactive-($buffers+$cached+$swapcached+$anonpages)))
	# Check if MemTotal = MemFree + Active + Inactive + Slab + PageTables + VmallocUsed + X (X : alloc_pages() (get_free_pages(), etc))
	diff2=$(($memtotal-$memfree-$active-$inactive-$slab-$pagetables-$vmallocused-$kernelstack))
	gc_alloc=$(($contig+$contignon+$gc_virtual))

	gc_total=$(perl -nale "if (/GC Memory Sum:/) {print \$F[3];}" "$file")

    pss_total=$(get_pss_total "$file")
    pss_unnecessary=$(get_pss_unnecessary "$file")
    meminfo_pss_total=$(($anonpages+$mapped))

    zram_saved=$(get_zram_saved "$file")
    ksm_saved=$(get_ksm_saved "$file")
    lost_ram=$(get_lost_ram "$file")
}

report_summary()
{
    print_size "DDR size" $ddrtotal
    print_size "Reserved memory" $((ddrtotal-memtotal))
	print_size "Free_Cached_Buffers" $free_cache_buffer
	print_size "Real Free" $realfree
    print_size "Kernel Used" $kernelused
    print_size "Slab" $slab
    print_size "Pagetables" $pagetables
    print_size "Kernelstack" $kernelstack
	print_size "GC Allocated" $gc_alloc
	print_size "GC Total" "$gc_total"
    print_size "Procrank Pss" $pss_total
    print_size "Meminfo Pss" $meminfo_pss_total

    print_size "Kernel Others" $(($memtotal-$kernelused-$meminfo_pss_total-$gc_alloc-$realfree))
	print_size "zRAM saved" $zram_saved
	print_size "KSM saved" $ksm_saved
}

tmpfile=$(mktemp)
cat > $tmpfile

parse_meminfo "$tmpfile"

report_summary

rm $tmpfile
