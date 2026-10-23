#!/bin/bash

BAR="▁▂▃▄▅▆▇█"
FIFO="/tmp/cava_pipe"
CONFIG="/tmp/polybar_cava_config"

# Kill any previous cava instance using our config
pkill -f "cava -p $CONFIG" 2>/dev/null

# Remove stale FIFO
rm -f "$FIFO"
mkfifo "$FIFO"

# Generate sed mapping
DICT="s/;//g;"
for ((i=0; i<${#BAR}; i++)); do
    DICT+="s/$i/${BAR:i:1}/g;"
done

# CAVA configuration
cat > "$CONFIG" <<EOF
[general]
bars = 18

[input]
method = pulse

[output]
method = raw
raw_target = $FIFO
data_format = ascii
ascii_max_range = 7
EOF

cleanup() {
    [[ -n "$CAVA_PID" ]] && kill "$CAVA_PID" 2>/dev/null
    rm -f "$FIFO" "$CONFIG"
}

trap cleanup EXIT INT TERM

# Start cava
cava -p "$CONFIG" &
CAVA_PID=$!

# Give cava a moment to start
sleep 0.1

# Read and transform CAVA output
while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    output=$(printf '%s\n' "$line" | sed "$DICT")

    # Force exactly one Waybar output line
    printf '%s\n' "$output"
done < "$FIFO"

