#!/bin/bash
# nload-style network monitor for waybar (custom module)
# Shows current download/upload rates and totals, like nload, by reading /proc/net-dev

IFACE="wlo1"
CACHE="/tmp/nload_${IFACE}.cache"

# rx_bytes (col 2) and tx_bytes (col 10) for the interface
read -r curr_rx curr_tx < <(awk -v iface="${IFACE}:" '$0 ~ iface {print $2, $10}' /proc/net/dev)

now=$(date +%s)

if [[ -f "$CACHE" ]]; then
    read -r prev_rx prev_tx prev_now < "$CACHE"
else
    prev_rx=$curr_rx
    prev_tx=$curr_tx
    prev_now=$now
fi

interval=$(( now - prev_now ))
(( interval < 1 )) && interval=1

# Current rates in bytes/s
rx_rate=$(( (curr_rx - prev_rx) / interval ))
tx_rate=$(( (curr_tx - prev_tx) / interval ))
(( rx_rate < 0 )) && rx_rate=0
(( tx_rate < 0 )) && tx_rate=0

# Save current counters for next run
echo "$curr_rx $curr_tx $now" > "$CACHE"

rx_human=$(numfmt --to=iec $rx_rate 2>/dev/null || echo "$rx_rate")
tx_human=$(numfmt --to=iec $tx_rate 2>/dev/null || echo "$tx_rate")
rx_total=$(numfmt --to=iec $curr_rx 2>/dev/null || echo "$curr_rx")
tx_total=$(numfmt --to=iec $curr_tx 2>/dev/null || echo "$curr_tx")

text="↓ ${rx_human}B/s   ↑ ${tx_human}B/s"
tooltip="nload ${IFACE}\n↓ now: ${rx_human}B/s\n↑ now: ${tx_human}B/s\n↓ total: ${rx_total}B\n↑ total: ${tx_total}B"

printf '{"text": "%s", "tooltip": "%s", "class": "nload"}\n' "$text" "$tooltip"
