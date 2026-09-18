#!/usr/bin/env python3
import sys, json
from datetime import datetime

# DEBUG: dump the raw stdin payload so the available fields can be inspected.
# Remove once done: jq . /tmp/statusline-input.json
raw = sys.stdin.read()
with open("/tmp/statusline-input.json", "w") as f:
    f.write(raw)
data = json.loads(raw)
limits = data.get("rate_limits") or {}

def fmt_window(key, label, include_date=False):
    window = limits.get(key)
    if not window:
        return None

    used = window.get("used_percentage")
    reset = window.get("resets_at")

    if used is None or reset is None:
        return None

    dt = datetime.fromtimestamp(reset)
    reset_fmt = dt.strftime("%a %H:%M") if include_date else dt.strftime("%H:%M")

    return f"{label}: {used:.0f}% · resets {reset_fmt}"

model = (data.get("model") or {}).get("display_name")

parts = [
    fmt_window("five_hour", "5h"),
    fmt_window("seven_day", "7d", include_date=True),
]

parts = [p for p in parts if p]

limits_str = " | ".join(parts) if parts else "limits unavailable"

print(f"{model} | {limits_str}" if model else limits_str)
