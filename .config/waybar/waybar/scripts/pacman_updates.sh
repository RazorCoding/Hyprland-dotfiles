#!/bin/bash

updates=$(checkupdates 2>/dev/null | wc -l)

if [ "$updates" -gt 0 ]; then
    echo " $updates"   # You can change the icon if you want
else
    echo "😴"            # No updates available
fi

