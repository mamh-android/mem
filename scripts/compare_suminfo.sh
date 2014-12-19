#!/bin/bash


get_value()
{
	perl -nale "if (/^$1/) {print \$F[1];}" $2
}

get_gc_value()
{
	perl -nale "if (/$1/) {print \$F[2];}" $2
}

# file 2
file=$1

buffers1=$(get_value "Buffers:" "$file")
cached1=$(get_value "Cached:" "$file")

anonpages1=$(get_value "AnonPages:" "$file")

memtotal1=$(get_value "MemTotal:" "$file")
memfree1=$(get_value "MemFree:" "$file")

freesum1=$(($memfree1+$cached1+$buffers1))

contig1=$(get_gc_value "contiguousPaged:" "$file")
contignon1=$(get_gc_value "contiguousNonPaged:" "$file")
gc_virtual1=$(get_gc_value "virtualPaged:" "$file")

gc_alloc1=$(($contig1+$contignon1+$gc_virtual1))

gc_total1=$(perl -nale "if (/GC Memory Sum:/) {print \$F[3];}" "$file")

# file 2
file=$2

buffers2=$(get_value "Buffers:" "$file")
cached2=$(get_value "Cached:" "$file")

anonpages2=$(get_value "AnonPages:" "$file")

memtotal2=$(get_value "MemTotal:" "$file")
memfree2=$(get_value "MemFree:" "$file")

freesum2=$(($memfree2+$cached2+$buffers2))

contig2=$(get_gc_value "contiguousPaged:" "$file")
contignon2=$(get_gc_value "contiguousNonPaged:" "$file")
gc_virtual2=$(get_gc_value "virtualPaged:" "$file")

gc_alloc2=$(($contig2+$contignon2+$gc_virtual2))

gc_total2=$(perl -nale "if (/GC Memory Sum:/) {print \$F[3];}" "$file")

mem_incr_diff=$(($freesum1-$freesum2))
anonpages_diff=$(($anonpages2-$anonpages1))
gc_alloc_diff=$(($gc_alloc2-$gc_alloc1))
gc_total_diff=$(($gc_total2-$gc_total1))
other_diff=$(($mem_incr_diff - $gc_alloc_diff - $anonpages_diff ))

echo "Mem Incr diff:" $mem_incr_diff
echo "Anonpages diff:" $anonpages_diff
echo "GC Total diff:" $gc_total_diff
echo "GC Alloc diff:" $gc_alloc_diff
echo "Other diff:" $other_diff

echo -e "$mem_incr_diff\t$anonpages_diff\t$gc_total_diff\t$gc_alloc_diff"

