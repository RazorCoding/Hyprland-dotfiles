#!/usr/bin/env python3
import json, os, time, datetime

IFACE = "wlo1"
LIMIT_GB = 1400
STATE_FILE = os.path.expanduser("~/.cache/waybar_data_usage.json")

def read_counters():
    try:
        with open("/proc/net/dev") as f:
            for line in f:
                if IFACE + ":" in line:
                    parts = line.split(":")[1].split()
                    return int(parts[0]), int(parts[8])
    except Exception:
        pass
    return 0, 0

def fmt_bytes(b):
    g = b / 1e9
    if g >= 1000:
        return f"{g/1000:.2f}T"
    if g >= 1:
        return f"{g:.1f}G"
    if b >= 1e6:
        return f"{b/1e6:.0f}M"
    return f"{b/1e3:.0f}K"

now = datetime.datetime.now()
cycle_key = f"{now.year}-{now.month:02d}"

rx, tx = read_counters()

state = {}
if os.path.exists(STATE_FILE):
    try:
        with open(STATE_FILE) as f:
            state = json.load(f)
    except Exception:
        state = {}

if state.get("cycle_key") != cycle_key:
    state = {"cycle_key": cycle_key, "last_rx": rx, "last_tx": tx,
             "total_rx": 0, "total_tx": 0}

last_rx = state.get("last_rx", rx)
last_tx = state.get("last_tx", tx)
total_rx = state.get("total_rx", 0)
total_tx = state.get("total_tx", 0)

delta_rx = (rx - last_rx) if rx >= last_rx else rx
delta_tx = (tx - last_tx) if tx >= last_tx else tx
if delta_rx < 0:
    delta_rx = 0
if delta_tx < 0:
    delta_tx = 0

total_rx += delta_rx
total_tx += delta_tx

state.update({"cycle_key": cycle_key, "last_rx": rx, "last_tx": tx,
              "total_rx": total_rx, "total_tx": total_tx, "updated": time.time()})
os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
with open(STATE_FILE, "w") as f:
    json.dump(state, f)

limit_bytes = LIMIT_GB * 1e9
pct = (total_rx / limit_bytes * 100) if limit_bytes else 0.0
remaining = max(0, limit_bytes - total_rx)

if now.month == 12:
    next_cycle = datetime.date(now.year + 1, 1, 1)
else:
    next_cycle = datetime.date(now.year, now.month + 1, 1)

if pct >= 100:
    cls = "critical"
elif pct >= 90:
    cls = "critical"
elif pct >= 70:
    cls = "warning"
else:
    cls = "normal"

text = f"\u2193 {fmt_bytes(total_rx)}/{LIMIT_GB}G  \u2191 {fmt_bytes(total_tx)}"
tooltip = ("Data usage (billing cycle)\n"
           f"Downloaded: {fmt_bytes(total_rx)} / {LIMIT_GB} GB ({pct:.1f}%)\n"
           f"Uploaded: {fmt_bytes(total_tx)}\n"
           f"Remaining: {fmt_bytes(remaining)}\n"
           f"Next cycle: {next_cycle.strftime('%d %b %Y')}\n"
           f"Limit: {LIMIT_GB} GB (FUP)")

print(json.dumps({"text": text, "tooltip": tooltip, "class": cls}, ensure_ascii=False))
