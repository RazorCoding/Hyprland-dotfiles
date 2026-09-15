#!/bin/bash

# Network interface
IFACE="wlo1"
TMP_FILE="/tmp/net_graph_${IFACE}.tmp"

# Read previous RX/TX
if [[ -f "$TMP_FILE" ]]; then
    read prev_rx prev_tx < "$TMP_FILE"
else
    prev_rx=$(cat /sys/class/net/$IFACE/statistics/rx_bytes)
    prev_tx=$(cat /sys/class/net/$IFACE/statistics/tx_bytes)
fi

# Read current RX/TX
rx=$(cat /sys/class/net/$IFACE/statistics/rx_bytes)
tx=$(cat /sys/class/net/$IFACE/statistics/tx_bytes)

# Calculate speed (bytes since last run)
rx_rate=$(( rx - prev_rx ))
tx_rate=$(( tx - prev_tx ))

# Save counters
echo "$rx $tx" > "$TMP_FILE"

# Convert speeds to human-readable format
rx_human=$(numfmt --to=iec $rx_rate)
tx_human=$(numfmt --to=iec $tx_rate)

# Output JSON for Waybar
echo '{"text": "'"D: [$rx_human]"' U:'" [$tx_human] "'", "tooltip": "RX: '"$rx_human"', TX: '"$tx_human"'", "class": "network"}'

