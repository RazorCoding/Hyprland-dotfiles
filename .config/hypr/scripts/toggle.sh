#!/usr/bin/env bash

state=$(hyprctl getoption input:touchpad:enabled | awk '/int:/ {print $2}')

if [[ "$state" == "1" ]]; then
    hyprctl eval 'hl.input({touchpad = {enabled = false}})'
else
    hyprctl eval 'hl.input({touchpad = {enabled = true}})'
fi
