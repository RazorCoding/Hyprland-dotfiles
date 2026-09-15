#!/bin/bash

# Get battery name (BAT0, BAT1, etc.)
BAT=$(ls /sys/class/power_supply | grep BAT)

# Get design and full charge capacity
DESIGN=$(cat /sys/class/power_supply/$BAT/charge_full_design 2>/dev/null)
FULL=$(cat /sys/class/power_supply/$BAT/charge_full 2>/dev/null)

# Fallback for some systems (use energy instead of charge)
if [ -z "$DESIGN" ]; then
  DESIGN=$(cat /sys/class/power_supply/$BAT/energy_full_design 2>/dev/null)
  FULL=$(cat /sys/class/power_supply/$BAT/energy_full 2>/dev/null)
fi

# Check if values are found
if [[ -z "$DESIGN" || -z "$FULL" ]]; then
  echo "Battery health: N/A"
  exit 1
fi

# Calculate health %
HEALTH=$(awk "BEGIN { printf \"%.1f\", ($FULL / $DESIGN) * 100 }")
echo " $HEALTH%"

