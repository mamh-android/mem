Short explanations of scripts here:

- meminfo.sh / summarize_meminfo.sh / compare_pss.sh / compare_suminfo.sh / generate_sumeinfo_table.sh / collect_info.sh
Scripts to collect and analyze memory footprint status on device

- adb_valgrind
Wrapper script for easier usage of valgrind on device

- enable_ksm.sh
Enables/disables KSM feature on device

- compare_heapdumps
Compares two "am dumpheap -n <pid>" native heap dumps and show report. Useful
for leak detection
