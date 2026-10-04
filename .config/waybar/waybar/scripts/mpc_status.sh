#!/bin/bash

# Export runtime dir for MPD socket
export XDG_RUNTIME_DIR=/run/user/$(id -u)

# (Optional) export MPD_HOST if you have custom socket location
# export MPD_HOST=unix:///run/user/$(id -u)/mpd/socket

# Run mpc with full path and format
/usr/bin/mpc --format '%artist% - %title%' current
