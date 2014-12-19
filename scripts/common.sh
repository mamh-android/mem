#!/bin/bash
# Common functions used by other scripts

adb_root()
{
    adb shell id |grep uid=0 > /dev/null
    if [ $? -eq 0 ]; then
        echo already rooted
    else
        adb root
        sleep 2
        adb wait-for-device

        # Need this step to make sure "adb shell" works now
        adb shell echo root done.
    fi

    adb shell setenforce 0
}

adb_remount()
{
    adb_root
    adb remount
}

# Sync PC's time to adb connected device
adb_sync_time()
{
    adb_root

    adb shell date -s $(date +%Y%m%d.%H%M%S)
}

adb_top_activity()
{
    adb shell dumpsys activity | perl -nle 'if (/Recent #0/) {s/^.+ A=([^ ]+).+/\1/g; print}'
}
