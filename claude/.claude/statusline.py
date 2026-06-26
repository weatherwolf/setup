#!/usr/bin/env python3
import sys, json
from datetime import datetime

data = json.load(sys.stdin)
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

parts = [
    fmt_window("five_hour", "5h"),
    fmt_window("seven_day", "7d", include_date=True),
]

parts = [p for p in parts if p]

print(" | ".join(parts) if parts else "limits unavailable")
