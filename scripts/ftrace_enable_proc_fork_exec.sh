#!/bin/sh
ADB_SHELL="adb shell "

adb_root

$ADB_SHELL 'echo 0 > /d/tracing/tracing_on'
$ADB_SHELL 'echo "sched:sched_process_fork" > /d/tracing/set_event'
# Notice the '>>' used here
$ADB_SHELL 'echo "sched:sched_process_exec" >> /d/tracing/set_event'
$ADB_SHELL 'echo 1 > /d/tracing/tracing_on'

$ADB_SHELL 'cat /d/tracing/trace_pipe'
