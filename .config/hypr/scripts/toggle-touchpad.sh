#!/usr/bin/env bash

DEVICE="elan2841:00-04f3:31ad-touchpad"
STATE_FILE="$HOME/.cache/touchpad-state"

mkdir -p "$HOME/.cache"

if [[ ! -f "$STATE_FILE" ]]; then
    echo "enabled" > "$STATE_FILE"
fi

STATE=$(cat "$STATE_FILE")

if [[ "$STATE" == "enabled" ]]; then
    hyprctl eval "hl.device({name = \"$DEVICE\", enabled = false})" || exit 1
    echo "disabled" > "$STATE_FILE"
    notify-send -a "Touchpad" -t 1500 "Touchpad" "Disabled"
else
    hyprctl eval "hl.device({name = \"$DEVICE\", enabled = true})" || exit 1
    echo "enabled" > "$STATE_FILE"
    notify-send -a "Touchpad" -t 1500 "Touchpad" "Enabled"
fi
