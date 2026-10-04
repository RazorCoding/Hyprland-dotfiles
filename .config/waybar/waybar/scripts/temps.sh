#!/bin/bash

CPU_TEMP=$(($(cat /sys/class/hwmon/hwmon5/temp1_input)/1000))
AMD_TEMP=$(($(cat /sys/class/hwmon/hwmon4/temp1_input)/1000))

# Try to read NVIDIA temperature from hwmon if available
NV_TEMP_FILE=$(find /sys/class/hwmon -name temp1_input -path "*nvidia*" 2>/dev/null | head -n1)

if [ -f "$NV_TEMP_FILE" ]; then
    NV_TEMP=$(($(cat "$NV_TEMP_FILE")/1000))
else
    NV_TEMP="--"
fi

RAM_USED=$(free -h | awk '/Mem:/ {print $3}')
RAM_TOTAL=$(free -h | awk '/Mem:/ {print $2}')

TEXT=" $CPU_TEMP° | 󰢮 $AMD_TEMP° | 󰢮 $NV_TEMP° |  $RAM_USED"


