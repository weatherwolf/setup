#!/usr/bin/env python3
"""Recompute Claude Code's shimmer values from their bases.

Shimmers are lightened variants of the colour they animate, not independent
values, so a hex-for-hex palette swap leaves them pointing at the old palette.
This rewrites each shimmer from whatever its base currently holds.

The lift and chroma factor per key are measured from Claude Code's own dark
theme, not invented: an already-light base needs less lift than a mid one to
read as the same colour brightening, so there is no single global rule. Chroma
is applied as a proportion, never as a subtraction - taking a fixed amount off
a low-chroma base leaves it grey, and the shimmer flashes rather than pulses.

Hue is held constant. The reference pairs drift up to 3 degrees, but that is
rounding in the originals rather than intent.

Usage: recompute_shimmers.py <theme.json>
Writes in place, touching only the four shimmer values. Prints what changed.
"""

import math
import re
import sys

# base key -> (shimmer key, lightness lift, chroma multiplier)
PAIRS = {
    "claude": ("claudeShimmer", 0.100, 0.79),
    "promptBorder": ("promptBorderShimmer", 0.112, 0.75),
    "inactive": ("inactiveShimmer", 0.129, 1.00),
    "permission": ("permissionShimmer", 0.083, 0.62),
}


# The message and panel fills are the same kind of derived value: bg plus a
# small lightness lift, on bg's hue. They are listed separately from PAIRS
# because they all share one base, and a dict cannot key five entries off it.
# clawd_background is used as the base because it is the only key in theme.json
# that holds the palette's bg.
#
# Without this they went stale the same way the shimmers did: a hex-keyed swap
# rewrites a role, but these are not roles, so they kept glacier's blue while
# bg moved to green and then to brown. Fixed by hand twice before this.
#
#           base                derived key                  lift   chroma x
PANELS = [
    ("clawd_background", "userMessageBackground",       0.019, 0.95),
    ("clawd_background", "userMessageBackgroundHover",  0.056, 1.05),
    ("clawd_background", "composerSidebarBackground",   0.016, 1.00),
    ("clawd_background", "memoryBackgroundColor",       0.036, 1.02),
    ("clawd_background", "bashMessageBackgroundColor",  0.020, 0.85),
]


def srgb_to_lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lin_to_srgb(c):
    v = 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055
    return max(0, min(255, round(v * 255)))


def to_oklab(r, g, b):
    R, G, B = srgb_to_lin(r), srgb_to_lin(g), srgb_to_lin(b)
    l = 0.4122214708 * R + 0.5363325363 * G + 0.0514459929 * B
    m = 0.2119034982 * R + 0.6806995451 * G + 0.1073969566 * B
    s = 0.0883024619 * R + 0.2817188376 * G + 0.6299787005 * B
    l_, m_, s_ = (v ** (1 / 3) if v > 0 else 0.0 for v in (l, m, s))
    return (
        0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
        1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
        0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
    )


def to_rgb(L, a, b):
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    return (
        lin_to_srgb(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
        lin_to_srgb(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
        lin_to_srgb(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s),
    )


def shimmer_of(base_hex, lift, chroma_mult):
    rgb = tuple(int(base_hex[i:i + 2], 16) for i in (1, 3, 5))
    L, a, b = to_oklab(*rgb)
    C, H = math.hypot(a, b), math.atan2(b, a)
    L = min(1.0, L + lift)
    C *= chroma_mult
    return "#%02X%02X%02X" % to_rgb(L, C * math.cos(H), C * math.sin(H))


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: recompute_shimmers.py <theme.json>")
    path = sys.argv[1]
    text = open(path).read()

    def value_of(key):
        m = re.search(r'"%s"\s*:\s*"(#[0-9A-Fa-f]{6})"' % re.escape(key), text)
        return m.group(1) if m else None

    changed = 0
    for base, (shimmer, lift, mult) in PAIRS.items():
        base_hex = value_of(base)
        if base_hex is None:
            print("  skip %s: base not overridden in this theme" % shimmer)
            continue
        old = value_of(shimmer)
        new = shimmer_of(base_hex, lift, mult)
        if old is None:
            print("  skip %s: key not present in this theme" % shimmer)
            continue
        if old.lower() == new.lower():
            continue
        text = re.sub(
            r'("%s"\s*:\s*")#[0-9A-Fa-f]{6}(")' % re.escape(shimmer),
            r"\g<1>%s\g<2>" % new,
            text,
        )
        print("  %s %s -> %s (from %s %s)" % (shimmer, old, new, base, base_hex))
        changed += 1

    for base, derived, lift, mult in PANELS:
        base_hex = value_of(base)
        if base_hex is None:
            print("  skip %s: base %s not overridden in this theme"
                  % (derived, base))
            continue
        old = value_of(derived)
        if old is None:
            print("  skip %s: key not present in this theme" % derived)
            continue
        new = shimmer_of(base_hex, lift, mult)
        if old.lower() == new.lower():
            continue
        text = re.sub(
            r'("%s"\s*:\s*")#[0-9A-Fa-f]{6}(")' % re.escape(derived),
            r"\g<1>%s\g<2>" % new,
            text,
        )
        print("  %s %s -> %s (from %s %s)" % (derived, old, new, base, base_hex))
        changed += 1

    if changed:
        open(path, "w").write(text)
    else:
        print("  shimmers already match their bases")


if __name__ == "__main__":
    main()
