#!/bin/bash

SEP="/"

icon_on=""

info=$(bluetoothctl devices Connected 2>/dev/null)

macs=$(printf '%s\n' "$info" |
	awk '/^Device [0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}/ {print $2}')

if [ -n "$macs" ]; then
	first_level=""
	first_name=""
	rows=""
	count=0

	while read -r mac; do
		[ -z "$mac" ] && continue
		count=$((count + 1))

		dev=$(bluetoothctl info "$mac" 2>/dev/null)

		name=$(printf '%s\n' "$dev" |
			sed -n 's/^[[:space:]]*Name:[[:space:]]*//p' | head -1)
		[ -z "$name" ] && name="$mac"

		level=$(printf '%s\n' "$dev" |
			sed -n 's/.*Battery Percentage:.*(\([0-9]\{1,3\}\)).*/\1/p' | head -1)

		if [ -n "$level" ]; then
			rows="$rows$name ($level%)\n"
			[ -z "$first_level" ] && first_level="$level"
		else
			rows="$rows$name\n"
		fi

		[ -z "$first_name" ] && first_name="$name"
	done <<< "$macs"

	safe_name=${first_name//\"/}
	safe_name=${safe_name//\\/\\\\}

	if [ -n "$first_name" ] && [ -n "$first_level" ]; then
		text="$icon_on $safe_name ($first_level%)"
	elif [ -n "$first_name" ]; then
		text="$icon_on $safe_name"
	else
		text="$icon_on"
	fi

	if [ "$first_level" -ge 0 ] 2>/dev/null; then
		if [ "$first_level" -le 15 ]; then
			class="critical"
		elif [ "$first_level" -le 35 ]; then
			class="warning"
		else
			class="connected"
		fi
	else
		class="connected"
	fi

	printf '{"text":"%s","tooltip":"Bluetooth connected:\\n%s","class":"%s","alt":"connected"}\n' \
		"$text" "$rows" "$class"
else
	printf '{"text":"","tooltip":"Bluetooth off","class":"disconnected","alt":"disconnected"}\n'
fi
