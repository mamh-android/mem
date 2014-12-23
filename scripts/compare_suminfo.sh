#!/bin/bash
# Parse two "suminfo.log" and generate table to be imported to Excel

DELIM="\t"
res_file="mem_summary_compare.txt"

if [ $# -ne 2 ]
then
    echo "usage: $0 sum1.log sum2.log"
    exit
fi

num=0
while read line1
do
    if [ $num -eq 0 ]
    then
        log_name2=`head -1 $2`
        echo -e "${DELIM}$line1${DELIM}$log_name2" > $res_file
        num=1
        continue
    fi
    # get the memory size
    i=`expr index "$line1" ":"`
    if [ "$i" == "0" ]
    then
        echo "$line1: i: $i"
        continue
    fi
    size=`echo $line1 | cut -d ":" -f 2`
    # get the item name
    item=`echo $line1 | cut -d ":" -f 1`
    echo "size: $size; item: $item"
    if [ "$size" != "" ] && [ "$item" != "" ]
    then
        size2=`grep "$item:" $2 | cut -d ":" -f 2`
        echo -e "$item${DELIM}$size${DELIM}$size2" >> $res_file
    elif [ "$size" == "" ] && [ "$item" != "" ]
    then
        echo "$item" >> $res_file
    fi
done < $1
