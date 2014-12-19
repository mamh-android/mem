#!/bin/sh
ADB_SHELL="adb shell "

adb_root

$ADB_SHELL 'echo 0 > /d/tracing/tracing_on'

$ADB_SHELL 'echo "order > 0" > /d/tracing/events/kmem/mm_page_alloc/filter'
$ADB_SHELL 'echo "order >= 0" > /d/tracing/events/kmem/mm_page_free/filter'
$ADB_SHELL 'echo "kmem:mm_page_alloc" > /d/tracing/set_event'
# Notice the '>>' used here
$ADB_SHELL 'echo "kmem:mm_page_free" >> /d/tracing/set_event'

$ADB_SHELL 'echo 1 > /d/tracing/tracing_on'

$ADB_SHELL 'cat /d/tracing/trace_pipe'

