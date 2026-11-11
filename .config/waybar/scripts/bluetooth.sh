#!/bin/bash
set -u

ICON=""
TIMEOUT=5

emit_json() {
    # args: text tooltip class alt
    python3 -c 'import json,sys; print(json.dumps({"text":sys.argv[1],"tooltip":sys.argv[2],"class":sys.argv[3],"alt":sys.argv[4]}, ensure_ascii=False))' "$1" "$2" "$3" "$4"
}

run_bt() {
    timeout "$TIMEOUT" bluetoothctl "$@" 2>/dev/null
}

# rfkill can hard/soft block the adapter even when bluetoothd is running.
rf_out=$(timeout "$TIMEOUT" rfkill list bluetooth 2>/dev/null || true)
if printf '%s\n' "$rf_out" | grep -qiE 'Soft blocked: yes|Hard blocked: yes'; then
    emit_json "$ICON" "Bluetooth blocked by rfkill" "off" "blocked"
    exit 0
fi

powered=$(run_bt show | awk '/^[[:space:]]*Powered:/ {print $2; exit}')
[ -z "$powered" ] && powered="no"

if [ "$powered" != "yes" ]; then
    emit_json "$ICON" "Bluetooth off" "off" "off"
    exit 0
fi

connected_macs=$(run_bt devices Connected | awk '/^Device / {print $2}')
connected_count=$(printf '%s\n' "$connected_macs" | grep -c . 2>/dev/null || true)
[ -z "$connected_count" ] && connected_count=0

if [ "$connected_count" -gt 0 ]; then
    first_name=""
    first_battery=""
    rows=""

    while IFS= read -r mac; do
        [ -z "$mac" ] && continue
        info=$(run_bt info "$mac")

        name=$(printf '%s\n' "$info" | sed -n 's/^[[:space:]]*Name:[[:space:]]*//p' | head -n 1)
        [ -z "$name" ] && name="$mac"

        battery=$(printf '%s\n' "$info" | sed -n 's/.*Battery Percentage:.*(\([0-9]\{1,3\}\)).*/\1/p' | head -n 1)

        if [ -n "$battery" ]; then
            rows="${rows}${name} (${battery}%)"
        else
            rows="${rows}${name}"
        fi
        rows="${rows}"$'\n'

        if [ -z "$first_name" ]; then
            first_name="$name"
            first_battery="$battery"
        fi
    done <<< "$connected_macs"

    # Trim trailing newline for tooltip.
    rows="${rows%$'\n'}"

    if [ -n "$first_battery" ]; then
        text="$ICON $first_name ($first_battery%)"
    else
        text="$ICON $first_name"
    fi

    if [ -n "$first_battery" ]; then
        if [ "$first_battery" -le 15 ]; then
            class="critical"
        elif [ "$first_battery" -le 35 ]; then
            class="warning"
        else
            class="connected"
        fi
    else
        class="connected"
    fi

    emit_json "$text" "Bluetooth connected:
$rows" "$class" "$class"
else
    paired_count=$(run_bt devices Paired | grep -c '^Device ' 2>/dev/null || true)
    [ -z "$paired_count" ] && paired_count=0

    if [ "$paired_count" -gt 0 ]; then
        tooltip="Bluetooth on
No devices connected"
    else
        tooltip="Bluetooth on"
    fi

    emit_json "$ICON" "$tooltip" "on" "on"
fi
