#!/usr/bin/env bash
# nload-style network readout for a hyprlock label.
# nload itself is an interactive curses tool and cannot print a one-shot
# value, so this reads /proc/net/dev and computes the current rates.
# Output example: "↓ 1.4 MB/s ↑ 88 KB/s"

set -u

STATE="${XDG_RUNTIME_DIR:-/tmp}/hyprlock-netload"

# Interface used for the default route, falling back to the first
# non-loopback interface that is up.
iface=$(ip -o route show default 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
if [ -z "${iface:-}" ]; then
    iface=$(ip -o link show up 2>/dev/null | awk -F': ' '$2 != "lo" { print $2; exit }' | cut -d@ -f1)
fi
if [ -z "${iface:-}" ]; then
    echo "↓ -- ↑ --"
    exit 0
fi

# /proc/net/dev: field 2 = received bytes, field 10 = transmitted bytes
set -- $(awk -v ifc="$iface:" '$1 == ifc { print $2, $10 }' /proc/net/dev)
rx=${1:-0}
tx=${2:-0}
now=$(date +%s%N)

prev_ts=""
prev_iface=""
prev_rx=""
prev_tx=""
if [ -r "$STATE" ]; then
    read -r prev_ts prev_iface prev_rx prev_tx <"$STATE"
fi

printf '%s %s %s %s\n' "$now" "$iface" "$rx" "$tx" >"$STATE"

rx_rate=0
tx_rate=0
if [ -n "$prev_ts" ] && [ "$prev_iface" = "$iface" ]; then
    dt_ns=$((now - prev_ts))
    if [ "$dt_ns" -gt 0 ]; then
        rx_rate=$(( (rx - prev_rx) * 1000000000 / dt_ns ))
        tx_rate=$(( (tx - prev_tx) * 1000000000 / dt_ns ))
        # Counters can wrap or reset (interface down, suspend, VM migration)
        [ "$rx_rate" -lt 0 ] && rx_rate=0
        [ "$tx_rate" -lt 0 ] && tx_rate=0
    fi
fi

fmt() {
    awk -v b="$1" 'BEGIN {
        if (b >= 1073741824)      printf "%.1f GB/s", b / 1073741824
        else if (b >= 1048576)    printf "%.1f MB/s", b / 1048576
        else if (b >= 1024)       printf "%.1f KB/s", b / 1024
        else                      printf "%d B/s", b
    }'
}

echo "↓ $(fmt "$rx_rate") ↑ $(fmt "$tx_rate")"
