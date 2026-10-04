#!/bin/bash

SEP="/"

icon_on=""

out=$(bluetoothctl devices Connected 2>/dev/null)

names=$(printf '%s\n' "$out" |
	awk '/^Device [0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}/ {$1="";$2="";sub(/^[ \t]+/,"");if(length)print}')

if [ -n "$names" ]; then
	count=$(printf '%s\n' "$names" | grep -c .)
	if [ "$count" -gt 1 ]; then
		joined=$(printf '%s\n' "$names" | paste -sd', ')
		text="$SEP $icon_on"
	else
		joined=$(printf '%s\n' "$names")
		text="$SEP $icon_on $joined"
	fi

	printf '{"text":"%s","tooltip":"Bluetooth connected:\\n%s","class":"connected","alt":"connected"}\n' \
		"$text" "$joined"
else
	printf '{"text":"","tooltip":"Bluetooth off","class":"disconnected","alt":"disconnected"}\n'
fi
