#!/bin/bash
# Parse "dumpsys meminfo" Pss data and compare
# Generate pss_compare.txt file

calc()
{
    echo "$@" | bc -l
}

convert_KB_to_MB()
{
    calc "$1/1024"
}

DELIM="\t"

if [ $# -ne 2 ]
then
    echo "usage: $0 meminfo1.log meminfo2.log"
    exit
fi

res_file="pss_compare.txt"
temp_file1=$(mktemp)
temp_file2=$(mktemp)
echo -e "${DELIM}$1 (MB)${DELIM}$2 (MB)" > $res_file

sed -n '/Total PSS by process:/,/Total PSS by OOM adjustment:/p' $1 | sed '/Total PSS/d' > $temp_file1
sed -n '/Total PSS by process:/,/Total PSS by OOM adjustment:/p' $2 | sed '/Total PSS/d' > $temp_file2

cat $temp_file1
echo "==================================="
cat $temp_file2

num1=0
num2=0
num_both=0
mem1=0
mem2=0
mem_both1=0
mem_both2=0

while read line
do
    if [ "$line" != "" ]
    then
        #echo "line:   $line"
        size=`echo $line | cut -d " " -f 1`
        size_MB=`convert_KB_to_MB $size`
        name=`echo $line | cut -d " " -f 3`
        in_log2=`grep "kB: $name " $temp_file2`
        echo "in_log2: $in_log2"
        if [ "$in_log2" == "" ]
        # this item only in log1, not in log2, 
        then
            printf "%s${DELIM}%.1f\n" $name $size_MB >> $res_file
            num1=`expr $num1 + 1`
            mem1=`expr $mem1 + $size`
        else
            size2=`echo $in_log2 | cut -d " " -f 1`
            size2_MB=`convert_KB_to_MB $size2`
            #echo "size2_MB: $size2_MB"
            printf "%s${DELIM}%.1f${DELIM}%.1f\n" $name $size_MB $size2_MB >> $res_file
            num_both=`expr $num_both + 1`
            mem_both1=`expr $mem_both1 + $size`
            mem_both2=`expr $mem_both2 + $size2`
        fi
    fi
done < $temp_file1

while read line
do
    if [ "$line" != "" ]
    then
        name=`echo $line | cut -d " " -f 3`
        in_log1=`grep "$name" $temp_file1`
        if [ "$in_log1" == "" ]
        then
            size=`echo "$line" | cut -d " " -f 1`
            size_MB=`convert_KB_to_MB $size`
            printf "%s${DELIM}${DELIM}%.1f\n" $name $size_MB >> $res_file
            num2=`expr $num2 + 1`
            mem2=`expr $mem2 + $size`
        fi
    fi
done < $temp_file2

mem_total1=`expr $mem_both1 + $mem1`
mem_total2=`expr $mem_both2 + $mem2`
printf "%s${DELIM}%.1f${DELIM}%.1f\n" "Total Pss" $(convert_KB_to_MB $mem_total1) $(convert_KB_to_MB $mem_total2) >> $res_file

# Show info about different processes
printf "\n\nIn only one image:\n" >> $res_file
printf "process num${DELIM}$num1${DELIM}$num2\n"  >> $res_file
printf "Total Pss (MB)${DELIM}%.1f${DELIM}%.1f\n" $(convert_KB_to_MB $mem1) $(convert_KB_to_MB $mem2) >> $res_file
printf "\nIn both two images:\n" >> $res_file
printf "process num:${DELIM}%d${DELIM}%d\n" $num_both $num_both >> $res_file
printf "Total Pss (MB)${DELIM}%.1f${DELIM}%.1f\n" $(convert_KB_to_MB $mem_both1) $(convert_KB_to_MB $mem_both2) >> $res_file

rm -f $temp_file1
rm -f $temp_file2
