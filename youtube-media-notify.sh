#!/usr/bin/bash

last=""

player="$(playerctl -l 2>/dev/null | grep -Ei 'chrom|firefox|brave|edge|opera' | head -n1)"

[ -z "$player" ] && exit 1

playerctl -p "$player" metadata --follow --format '{{title}}' 2>/dev/null |
while IFS= read -r title; do
    [ -z "$title" ] && continue

    # Only notify when the video title changes
    [ "$title" = "$last" ] && continue
    last="$title"

    notify-send \
        -u low \
        -t 2000 \
        " YouTube" \
        "$title"
done
