#!/bin/bash

SOCK="/tmp/wob.sock"

# recreate socket safely
[ -e "$SOCK" ] && rm "$SOCK"
mkfifo "$SOCK"

tail -f "$SOCK" | wob
