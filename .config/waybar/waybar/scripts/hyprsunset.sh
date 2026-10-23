#!/bin/bash

hour=$(date +%H)
hour=$((10#$hour))

if [ "$hour" -ge 7 ] && [ "$hour" -lt 18 ]; then
    temp=6500
    icon="🌞"
    text="Day"
elif [ "$hour" -ge 18 ] && [ "$hour" -lt 20 ]; then
    temp=5000
    icon="🌆"
    text="Sunset"
elif [ "$hour" -ge 20 ] && [ "$hour" -lt 22 ]; then
    temp=4500
    icon="🌙"
    text="Evening"
else
    temp=4000
    icon="🌃"
    text="Night"
fi

# apply only if different
current=$(pgrep -a hyprsunset | grep -o '[0-9]\{4\}')

if [ "$current" != "$temp" ]; then
    killall -q hyprsunset
    hyprsunset -t "$temp"
fi

echo "{\"text\":\"$icon $text\",\"tooltip\":\"Color temp: ${temp}K\"}"
