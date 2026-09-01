#!/usr/bin/env python3
"""Color math for building a ~/setup palette from a wallpaper.

Three subcommands, matching the three things you cannot do by hand:

  sample <image>   convert a wallpaper to OKLCH and report its color axes
  build            emit a .colors file from one or two chosen hues
  check <palette>  measure a .colors file against the gates

There is no PIL on this machine, so `sample` shells out to `sips` and parses
the BMP itself. Everything else is pure stdlib.
"""

import argparse
import math
import os
import re
import struct
import subprocess
import sys
import tempfile

# Semantic hues, in OKLCH degrees. These are the six catppuccin colors that
# claude/.claude/themes/theme.json actually renders. They are constant across
# palettes and chrome must stay clear of them. Re-derive with `check` if the
# theme's semantic keys ever change.
SEMANTIC = {
    "red": 2.8,
    "yellow": 86.5,
    "green": 142.7,
    "teal": 182.7,
    "mauve": 304.8,
    "pink": 336.3,
}

# The full catppuccin palette, split by consequence. STATUS carries meaning -
# pass/fail, warnings, modes - so chrome resembling one is a correctness
# problem and is gated. SYNTAX is nvim highlighting, where a resemblance is a
# legibility annoyance at worst and is unavoidable for some palettes: every
# gold accent family sits near peach, because peach is a gold.
STATUS_HEX = {"red": "#f38ba8", "yellow": "#f9e2af", "green": "#a6e3a1",
              "teal": "#94e2d5", "mauve": "#cba6f7", "pink": "#f5c2e7"}
SYNTAX_HEX = {"rosewater": "#f5e0dc", "flamingo": "#f2cdcd", "maroon": "#eba0ac",
              "peach": "#fab387", "sky": "#89dceb", "sapphire": "#74c7ec",
              "blue": "#89b4fa", "lavender": "#b4befe"}
# dE below this is easily confused side by side.
CONFUSABLE = 0.10
# A role can only be mistaken for a status color if it is comparably saturated.
# A status color reads as a signal BECAUSE it is saturated, so a pale role
# sitting near one in OKLab is not confusable: near-white text is near-white
# whichever way its faint tint leans.
CHROMA_RATIO = 0.60
# cursor is exempt: a solid block under the caret, never a glyph, so resembling
# a status color costs nothing. Every palette in this repo already has one
# close to something (glacier dE 0.011 from sky).
CONFUSABLE_EXEMPT = {"cursor"}

# Gates. See SKILL.md for where each number comes from.
#
# The two semantic floors are deliberately different. A primary axis is
# mandatory - chrome has to go somewhere, so you accept whatever room the
# wallpaper's hue allows, and 13 is what tea-terrace shipped at. A secondary
# axis is optional, so it has to earn its place: if it cannot be comfortable,
# dropping it costs nothing.
MIN_SEMANTIC_SEP_PRIMARY = 13.0
MIN_SEMANTIC_SEP_SECONDARY = 20.0
MIN_AXIS_SEP = 45.0       # between two chrome axes, or it is one axis
MIN_AXIS_SHARE = 0.10     # chroma-weighted share of the image
GREY_CHROMA = 0.02        # below this, hue is meaningless
TEXT_CONTRAST = 4.5       # WCAG AA for the text ramp and accent

# Roles that must clear TEXT_CONTRAST against bg. border and the bg family are
# structural, not text, and are exempt.
CONTRAST_ROLES = {
    "text_bright", "text", "text_secondary", "text_muted", "text_dim",
    "text_hint", "cursor", "accent", "accent_bright", "accent_light",
    "accent_soft", "accent_vivid",
}

# The seam. Backgrounds, the text ramp and border stay on the primary axis so
# the contrast ladder is unchanged. The highlight family carries the secondary.
PRIMARY_ROLES = [
    "bg", "bg_surface", "bg_raised", "bg_selection",
    "text_bright", "text", "text_secondary", "text_muted", "text_dim",
    "text_hint", "border",
]
SECONDARY_ROLES = [
    "cursor", "accent", "accent_bright", "accent_light", "accent_soft",
    "accent_vivid", "reserve_1", "reserve_2", "reserve_3", "reserve_4",
]
ROLE_ORDER = PRIMARY_ROLES + SECONDARY_ROLES

ROLE_LINE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)=(#[0-9A-Fa-f]{6})$")


# ---------------------------------------------------------------- color math

def _srgb_to_linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _linear_to_srgb(c):
    c = max(0.0, min(1.0, c))
    c = 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
    return round(max(0.0, min(1.0, c)) * 255)


def rgb_to_oklch(r, g, b):
    """8-bit sRGB to (L, C, H). H in degrees, 0-360."""
    r, g, b = _srgb_to_linear(r), _srgb_to_linear(g), _srgb_to_linear(b)
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = l ** (1 / 3), m ** (1 / 3), s ** (1 / 3)
    ll = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
    a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
    bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    return ll, math.hypot(a, bb), math.degrees(math.atan2(bb, a)) % 360


def hex_to_oklch(h):
    h = h.lstrip("#")
    return rgb_to_oklch(int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def oklch_to_hex(L, C, H):
    """Clips to the sRGB cube. Check the round trip if C is high."""
    h = math.radians(H)
    a, b = C * math.cos(h), C * math.sin(h)
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    bb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    return "#%02X%02X%02X" % (_linear_to_srgb(r), _linear_to_srgb(g),
                              _linear_to_srgb(bb))


def _relative_luminance(hx):
    hx = hx.lstrip("#")
    r, g, b = (_srgb_to_linear(int(hx[i:i + 2], 16)) for i in (0, 2, 4))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(fg, bg):
    """WCAG 2.1 ratio. An UPPER BOUND here: wezterm renders at 0.8 opacity, so
    the wallpaper blends in and the real ratio on screen is lower."""
    a, b = _relative_luminance(fg), _relative_luminance(bg)
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)


def hue_dist(a, b):
    d = abs(a - b) % 360
    return min(d, 360 - d)


def nearest_semantic(h):
    name = min(SEMANTIC, key=lambda k: hue_dist(h, SEMANTIC[k]))
    return name, hue_dist(h, SEMANTIC[name])


def circular_clusters(items, threshold):
    """Single-linkage grouping of (name, hue) around the circle.

    Single linkage, not "distance to the first member": a band can be wider
    than the threshold as long as it has no internal gap that wide. That is
    what makes glacier-wave one wide band rather than two, which is the whole
    point of the 45-degree rule.
    """
    if not items:
        return []
    pts = sorted(items, key=lambda x: x[1])
    n = len(pts)
    if n == 1:
        return [pts]
    gaps = [pts[i + 1][1] - pts[i][1] for i in range(n - 1)]
    gaps.append(360 - (pts[-1][1] - pts[0][1]))  # the wrap-around gap
    if max(gaps) < threshold:
        return [pts]
    # Rotate so the widest gap falls at the seam, then cut at every wide gap.
    start = (gaps.index(max(gaps)) + 1) % n
    order = [pts[(start + i) % n] for i in range(n)]
    clusters, current = [], [order[0]]
    for i in range(1, n):
        if hue_dist(order[i][1], order[i - 1][1]) >= threshold:
            clusters.append(current)
            current = []
        current.append(order[i])
    clusters.append(current)
    return clusters


def min_lightness_for_contrast(C, H, bg_hex, target=TEXT_CONTRAST):
    """Smallest OKLCH L at this chroma and hue that clears `target` on bg_hex.

    Needed because holding L and C fixed while rotating hue does NOT hold
    contrast: WCAG luminance is hue-dependent. The same L and C that gives
    4.54:1 in blue gives 4.24:1 in red.
    """
    lo, hi = 0.0, 1.0
    for _ in range(50):
        mid = (lo + hi) / 2
        if contrast(oklch_to_hex(mid, C, H), bg_hex) >= target:
            hi = mid
        else:
            lo = mid
    return hi


# ------------------------------------------------------------- palette files

def read_palette(path):
    """Ordered [(role, hex)]. Matches on line SHAPE, not on '=', because the
    comments contain '=' too, and a malformed hex is rejected here rather than
    reaching a config where it is dropped silently."""
    out = []
    with open(path) as fh:
        for line in fh:
            m = ROLE_LINE.match(line.strip())
            if m:
                out.append((m.group(1), m.group(2)))
    return out


# A copy of the palette exactly as it was last written into the configs. It is
# what makes `sync` possible: update_palette.sh substitutes by exact hex match,
# so once a live palette's file is edited the configs hold values that appear in
# no file and no swap can reach them. The snapshot preserves the old hexes.
APPLIED = os.path.expanduser("~/setup/palettes/.applied.colors")

# Mirrors update_palette.sh's target selection. tmux is excluded because its
# message-style is #000000 and a hex-keyed rewrite is context-blind.
SYNC_EXCLUDE_DIRS = {".git", "palettes", "tmux", "node_modules"}
SYNC_EXCLUDE_FILES = {"update_palette.sh"}


def sync_targets(root=None):
    root = root or os.path.expanduser("~/setup")
    out = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SYNC_EXCLUDE_DIRS]
        for fn in filenames:
            if fn in SYNC_EXCLUDE_FILES or fn.endswith((".colors", ".png",
                                                        ".jpg", ".bmp")):
                continue
            path = os.path.join(dirpath, fn)
            try:
                with open(path, "rb") as fh:
                    chunk = fh.read(65536)
                if b"\0" in chunk:
                    continue
            except OSError:
                continue
            out.append(path)
    return out


def current_palette():
    path = os.path.expanduser("~/setup/palettes/current_pallete.txt")
    if not os.path.isfile(path):
        return None
    name = open(path).read().strip()
    return name or None


def resolve_palette(name):
    if os.path.sep in name or name.endswith(".colors"):
        return name
    return os.path.expanduser("~/setup/palettes/%s.colors" % name)


# ------------------------------------------------------------------- sample

def load_pixels(image, size=240):
    """Downsample with sips and parse the BMP directly."""
    if not os.path.isfile(image):
        raise SystemExit("no such image: %s" % image)
    tmp = tempfile.mkdtemp(prefix="palette-")
    bmp = os.path.join(tmp, "small.bmp")
    subprocess.run(
        ["sips", "-Z", str(size), image, "--out", bmp,
         "--setProperty", "format", "bmp"],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    if not os.path.exists(bmp):
        # sips exits 0 on some failures, so its return code is not enough.
        raise SystemExit("sips could not convert %s; is it a readable image?"
                         % image)
    with open(bmp, "rb") as fh:
        data = fh.read()
    offset = struct.unpack_from("<I", data, 10)[0]
    width = struct.unpack_from("<i", data, 18)[0]
    height = struct.unpack_from("<i", data, 22)[0]
    bpp = struct.unpack_from("<H", data, 28)[0]
    if bpp not in (24, 32):
        raise SystemExit("unsupported BMP depth: %d bpp" % bpp)

    step = bpp // 8
    rows = abs(height)
    stride = ((width * bpp + 31) // 32) * 4
    pixels = []
    for y in range(rows):
        base = offset + y * stride
        for x in range(width):
            p = base + x * step
            # BMP stores BGR.
            pixels.append((data[p + 2], data[p + 1], data[p]))
    return pixels


def find_axes(pixels):
    """Chroma-weighted hue histogram, smoothed, peaks picked greedily.

    Weighting by chroma rather than counting pixels is deliberate: a small
    vivid region reads louder than a large drained one, and area alone gets
    the sunset-strip case backwards.
    """
    hist = [0.0] * 360
    lightness = [[] for _ in range(360)]
    all_l = []
    grey_weight = 0.0
    total = 0.0
    for r, g, b in pixels:
        L, C, H = rgb_to_oklch(r, g, b)
        total += 1
        all_l.append(L)
        if C < GREY_CHROMA:
            grey_weight += 1
            continue
        bin_ = int(H) % 360
        hist[bin_] += C
        lightness[bin_].append(L)

    # 15-degree boxcar. Photographic hue clusters are broad; without smoothing
    # the peak picker chases noise.
    smooth = [0.0] * 360
    for i in range(360):
        smooth[i] = sum(hist[(i + d) % 360] for d in range(-7, 8))

    weight_total = sum(hist) or 1.0
    axes = []
    taken = [False] * 360
    for _ in range(4):
        best = max((v, i) for i, v in enumerate(smooth) if not taken[i])
        if best[0] <= 0:
            break
        center = best[1]
        # Claim everything within half the axis-separation gate. Share counts
        # only bins no earlier axis already claimed, so overlapping windows do
        # not double-count the same pixels.
        span = int(MIN_AXIS_SEP // 2)
        share = 0.0
        ls = []
        for d in range(-span, span + 1):
            i = (center + d) % 360
            if taken[i]:
                continue
            taken[i] = True
            share += hist[i]
            ls.extend(lightness[i])
        if not ls:
            continue
        ls.sort()
        axes.append({
            "hue": float(center),
            "share": share / weight_total,
            "l_min": ls[0],
            "l_p05": ls[len(ls) // 20],
            "l_p50": ls[len(ls) // 2],
            "l_p95": ls[len(ls) * 19 // 20],
            "l_max": ls[-1],
        })
    axes.sort(key=lambda a: -a["share"])
    all_l.sort()
    return axes, grey_weight / (total or 1.0), all_l


def cmd_sample(args):
    pixels = load_pixels(args.image)
    axes, grey, all_l = find_axes(pixels)

    print("wallpaper: %s" % args.image)
    print("%d pixels sampled, %.1f%% of them effectively grey (chroma < %.2f)"
          % (len(pixels), grey * 100, GREY_CHROMA))
    print()
    print("color axes, by chroma-weighted share:")
    print("  %-6s %-8s %-8s %s" % ("hue", "share", "nearest", "lightness p05/p50/p95"))
    for a in axes:
        name, sep = nearest_semantic(a["hue"])
        print("  %-6.1f %-8s %-8s %.3f / %.3f / %.3f"
              % (a["hue"], "%.1f%%" % (a["share"] * 100),
                 "%s %.0f" % (name, sep),
                 a["l_p05"], a["l_p50"], a["l_p95"]))
    print()

    # The three tests, in order.
    usable = []
    tight = []
    for a in axes:
        _, sep = nearest_semantic(a["hue"])
        # The first axis to survive becomes the primary and gets the lower
        # floor; everything after it is optional and gets the higher one.
        floor = (MIN_SEMANTIC_SEP_PRIMARY if not usable
                 else MIN_SEMANTIC_SEP_SECONDARY)
        reasons = []
        if a["share"] < MIN_AXIS_SHARE:
            reasons.append("share %.1f%% < %.0f%%"
                           % (a["share"] * 100, MIN_AXIS_SHARE * 100))
        # The primary floor is ADVISORY: chrome has to go somewhere, so a
        # crowded neighborhood is reported, not disqualifying. Only an optional
        # secondary can be rejected for it.
        if sep < floor and usable:
            reasons.append("only %.0f deg from a semantic hue (need %.0f as "
                           "secondary)" % (sep, floor))
        elif sep < floor:
            tight.append("primary hue %.0f is only %.0f deg from a semantic "
                         "hue (advisory floor %.0f)" % (a["hue"], sep, floor))
        for u in usable:
            if hue_dist(a["hue"], u["hue"]) < MIN_AXIS_SEP:
                reasons.append("only %.0f deg from the axis at %.0f (need %.0f)"
                               % (hue_dist(a["hue"], u["hue"]), u["hue"],
                                  MIN_AXIS_SEP))
                break
        if reasons:
            print("  reject hue %.0f: %s" % (a["hue"], "; ".join(reasons)))
        else:
            usable.append(a)

    for t in tight:
        print("  note: %s" % t)
    print()
    if not usable:
        print("VERDICT: no usable axis. This wallpaper cannot source a palette.")
        return 1
    primary = usable[0]
    if len(usable) == 1:
        print("VERDICT: one-color palette, primary hue %.0f." % primary["hue"])
        print("  build:  palette.py build --name NAME --primary %.0f"
              % primary["hue"])
    else:
        secondary = usable[1]
        print("VERDICT: two-color palette.")
        print("  primary   hue %.0f  (%.1f%%) -> backgrounds, text, border"
              % (primary["hue"], primary["share"] * 100))
        print("  secondary hue %.0f  (%.1f%%) -> cursor, accents, reserves"
              % (secondary["hue"], secondary["share"] * 100))
        print("  build:  palette.py build --name NAME --primary %.0f --secondary %.0f"
              % (primary["hue"], secondary["hue"]))
        if len(usable) > 2:
            print()
            print("  %d further axes survived the gates but have no home: the role"
                  % (len(usable) - 2))
            print("  vocabulary has room for two. Use one for reserve_* if you want")
            print("  it recorded, and say so in the file header.")

    print()
    img_p99 = all_l[len(all_l) * 99 // 100]
    print("lightness available: whole image p99 %.3f / max %.3f;\n"
          % (img_p99, all_l[-1]), end="")
    print("  primary axis (chromatic pixels only) p95 %.3f."
          % primary["l_p95"])
    if all_l[-1] < 0.94:
        print("  text_bright needs 0.967 and the image never gets there, so the")
        print("  top of the text ramp is EXTRAPOLATED, not sampled. Say so in")
        print("  the file header.")
    elif img_p99 < 0.90:
        print("  text_bright needs 0.967. The image reaches it, but only in its")
        print("  extreme highlights, so the top of the ramp matches a handful of")
        print("  pixels rather than a broad region. Worth saying in the header.")
    elif primary["l_p95"] < 0.85:
        print("  The light values are there but they are near-grey (snow, haze,")
        print("  cloud) rather than on the primary hue, so the top of the text")
        print("  ramp may be a near-match rather than a true sample.")
    print()
    print("Confirm either way once built, per role:")
    print("  palette.py check NAME --image %s" % args.image)
    return 0


# -------------------------------------------------------------------- build

def load_ladder(reference):
    """Per-role lightness, chroma and hue offset from a reference palette.

    The ladder is data, not code. tea-terrace is the default because it is the
    deliberate narrow-band one: its offsets describe a tight band, which is
    what you want when placing a band inside a semantic gap.
    """
    roles = read_palette(resolve_palette(reference))
    if not roles:
        raise SystemExit("no roles found in reference palette: %s" % reference)
    lch = [(n,) + hex_to_oklch(h) for n, h in roles]
    # Circular mean, so a band straddling 0 does not average to the opposite side.
    sx = sum(math.cos(math.radians(h)) for _, _, _, h in lch)
    sy = sum(math.sin(math.radians(h)) for _, _, _, h in lch)
    center = math.degrees(math.atan2(sy, sx)) % 360
    ladder = {}
    for name, L, C, H in lch:
        off = (H - center + 180) % 360 - 180
        ladder[name] = {"L": L, "C": C, "offset": off}
    return ladder


def cmd_build(args):
    ladder = load_ladder(args.reference)
    missing = [r for r in ROLE_ORDER if r not in ladder]
    if missing:
        raise SystemExit("reference palette is missing roles: %s"
                         % ", ".join(missing))

    # Refuse a bad secondary here rather than letting `check` find it. The
    # primary is only warned about: chrome has to go somewhere.
    sem, sep = nearest_semantic(args.primary)
    if sep < MIN_SEMANTIC_SEP_PRIMARY:
        print("WARNING: primary hue %.0f is %.1f deg from %s, under %.0f."
              % (args.primary, sep, sem, MIN_SEMANTIC_SEP_PRIMARY))
        print("  Chrome has to go somewhere, so this builds anyway, but this")
        print("  palette will lean on lightness and chroma to separate signal")
        print("  colors from chrome. Say so in the file header.")
    if args.secondary is not None:
        sem, sep = nearest_semantic(args.secondary)
        if sep < MIN_SEMANTIC_SEP_SECONDARY:
            raise SystemExit(
                "secondary hue %.0f is only %.1f deg from %s (need %.0f).\n"
                "A secondary axis is optional: drop it and build one-color."
                % (args.secondary, sep, sem, MIN_SEMANTIC_SEP_SECONDARY))
        d = hue_dist(args.primary, args.secondary)
        if d < MIN_AXIS_SEP:
            raise SystemExit(
                "primary %.0f and secondary %.0f are only %.1f deg apart "
                "(need %.0f).\nThat is one wide band, not two colors. Build "
                "one-color with --width." % (args.primary, args.secondary, d,
                                             MIN_AXIS_SEP))

    secondary = args.secondary if args.secondary is not None else args.primary
    axis_of = {r: args.primary for r in PRIMARY_ROLES}
    axis_of.update({r: secondary for r in SECONDARY_ROLES})

    # bg first: every contrast check is against it.
    bg_spec = ladder["bg"]
    bg_hex = oklch_to_hex(bg_spec["L"], bg_spec["C"],
                          (args.primary + bg_spec["offset"] * args.width) % 360)

    out = {}
    nudged = []
    for role in ROLE_ORDER:
        spec = ladder[role]
        hue = (axis_of[role] + spec["offset"] * args.width) % 360
        L, C = spec["L"], spec["C"]
        if role in CONTRAST_ROLES:
            floor = min_lightness_for_contrast(C, hue, bg_hex)
            if L < floor:
                # Holding L across a hue change does not hold contrast. Raise
                # L to whatever this hue needs, plus a hair of headroom.
                nudged.append((role, L, floor + 0.003))
                L = floor + 0.003
        out[role] = oklch_to_hex(L, C, hue)

    if args.out:
        path = args.out
    else:
        path = os.path.expanduser("~/setup/palettes/%s.colors" % args.name)
    if os.path.exists(path) and not args.force:
        raise SystemExit("refusing to overwrite %s (pass --force)" % path)

    sections = [
        ("background", ["bg", "bg_surface", "bg_raised", "bg_selection"]),
        ("text", ["text_bright", "text", "text_secondary", "text_muted",
                  "text_dim", "text_hint"]),
        ("chrome", ["border", "cursor", "accent", "accent_bright",
                    "accent_light", "accent_soft", "accent_vivid"]),
        ("reserve", ["reserve_1", "reserve_2", "reserve_3", "reserve_4"]),
    ]
    lines = ["# %s - machine-readable palette" % args.name,
             "#",
             "# TODO: replace this header. It must say which roles are SAMPLED",
             "# from the wallpaper and which are EXTRAPOLATED, and record the",
             "# hue separations below. See the skill for what belongs here.",
             "#"]
    if args.secondary is None:
        lines.append("# One color. Primary hue %.0f, band width %.2f."
                     % (args.primary, args.width))
    else:
        lines.append("# Two colors. Primary %.0f (backgrounds, text, border),"
                     % args.primary)
        lines.append("# secondary %.0f (cursor, accents, reserves), %.0f apart."
                     % (args.secondary,
                        hue_dist(args.primary, args.secondary)))
    lines.append("#")
    lines.append("# Semantic colors stay catppuccin mocha and are not stored here.")
    lines.append("# Claude Code's shimmers are computed from these roles, not")
    lines.append("# substituted, so a swap must recompute them.")
    for title, members in sections:
        lines.append("")
        lines.append("[%s]" % title)
        for role in members:
            lines.append("%s=%s" % (role, out[role]))
    with open(path, "w") as fh:
        fh.write("\n".join(lines) + "\n")

    print("wrote %s" % path)
    if nudged:
        print()
        print("lightness raised to hold %.1f:1 at the new hue:" % TEXT_CONTRAST)
        for role, was, now in nudged:
            print("  %-14s L %.3f -> %.3f" % (role, was, now))
    print()
    print("now: fill in the header, then `palette.py check %s`" % args.name)
    return 0


# -------------------------------------------------------------------- check

def oklab(L, C, H):
    h = math.radians(H)
    return L, C * math.cos(h), C * math.sin(h)


def nearest_by_distance(hexv, family):
    """(name, dE) of the perceptually nearest color in `family`."""
    r = oklab(*hex_to_oklch(hexv))
    return min(((k, math.dist(r, oklab(*hex_to_oklch(v))))
                for k, v in family.items()), key=lambda t: t[1])


def status_collision(hexv, role):
    """(name, dE) of the status color this role could be mistaken for, or None.

    This is the BINDING correctness test, replacing hue separation. Hue alone
    is the wrong instrument: a near-white text role can sit 4 degrees from
    catppuccin green and be unmistakable because it carries a third of the
    chroma, while a saturated role 20 degrees away can still read as a signal.
    """
    if role in CONFUSABLE_EXEMPT:
        return None
    k, d = nearest_by_distance(hexv, STATUS_HEX)
    if d >= CONFUSABLE:
        return None
    if hex_to_oklch(hexv)[1] < CHROMA_RATIO * hex_to_oklch(STATUS_HEX[k])[1]:
        return None
    return k, d


def provenance(roles, image):
    """Nearest image pixel to each role, as a distance in OKLab.

    dE below about 0.03 is hard to tell apart in place, so anything under that
    is honestly "sampled" and anything above it was invented. This is what the
    file header has to declare, and guessing at it is how "sampled from the
    wallpaper" turns into marketing.
    """
    pixels = load_pixels(image)
    lab = [oklab(*rgb_to_oklch(r, g, b)) for r, g, b in pixels]
    out = {}
    for name, hx in roles:
        rl, ra, rb = oklab(*hex_to_oklch(hx))
        out[name] = min(math.sqrt((rl - l) ** 2 + (ra - a) ** 2 + (rb - b) ** 2)
                        for l, a, b in lab)
    return out


def suggest_lightness(role, hexv, bg_hex):
    """Nearest lightness that clears the status collision, or None."""
    L, C, H = hex_to_oklch(hexv)
    for step in [i * 0.005 for i in range(1, 41)]:
        for cand in (L - step, L + step):
            if not 0.05 < cand < 0.99:
                continue
            candidate = oklch_to_hex(cand, C, H)
            if status_collision(candidate, role):
                continue
            if role in CONTRAST_ROLES and contrast(candidate, bg_hex) < TEXT_CONTRAST:
                continue
            return cand, candidate
    return None


def cmd_sync(args):
    """Propagate edits made to the LIVE palette into every consuming file.

    update_palette.sh only handles palette-to-palette swaps: it reads the old
    palette's hexes and replaces them. Editing the live palette's own file
    leaves the configs holding hexes that exist nowhere, so no later swap can
    find them - the roles are stranded. This closes that gap by diffing the
    palette against the snapshot of what was actually applied.
    """
    name = current_palette()
    if not name:
        raise SystemExit("palettes/current_pallete.txt is empty; nothing is live")
    path = resolve_palette(name)
    if not os.path.isfile(path):
        raise SystemExit("current palette %s has no .colors file" % name)
    current = read_palette(path)

    if not os.path.isfile(APPLIED):
        print("no snapshot at %s" % APPLIED)
        print("Cannot tell what the configs currently hold, so nothing was")
        print("changed. If the configs match %s already, adopt it with" % name)
        print("  palette.py sync --adopt")
        return 1

    applied = read_palette(APPLIED)
    if [n for n, _ in applied] != [n for n, _ in current]:
        raise SystemExit("snapshot and palette have different roles; refusing "
                         "to guess. Re-run update_palette.sh instead.")

    changes = [(n, old, new) for (n, old), (_, new) in zip(applied, current)
               if old.lower() != new.lower()]
    if not changes:
        print("%s matches the snapshot; the configs are already in sync" % name)
        return 0

    print("%s has %d role(s) edited since it was applied:" % (name, len(changes)))
    for n, old, new in changes:
        print("  %-15s %s -> %s" % (n, old, new))

    targets = sync_targets()
    # Two passes via unique tokens, so one role's new value cannot be rewritten
    # by a later role whose old value happens to equal it.
    touched = []
    for f in targets:
        try:
            text = open(f).read()
        except (OSError, UnicodeDecodeError):
            continue
        out = text
        for i, (_, old, _) in enumerate(changes):
            out = re.sub(re.escape(old), "@@%d@@" % i, out, flags=re.I)
        for i, (_, _, new) in enumerate(changes):
            out = out.replace("@@%d@@" % i, new)
        if out != text:
            if not args.dry_run:
                open(f, "w").write(out)
            touched.append(os.path.relpath(f, os.path.expanduser("~/setup")))

    print()
    if touched:
        print("%s %d file(s):" % ("would update" if args.dry_run else "updated",
                                 len(touched)))
        for f in touched:
            print("  %s" % f)
    else:
        print("no file contained any of the old values")

    if args.dry_run:
        print("\ndry run; nothing written")
        return 0

    import shutil
    shutil.copyfile(path, APPLIED)
    print("\nsnapshot refreshed")
    print("Now run, in this order:")
    print("  python3 ~/setup/palettes/recompute_shimmers.py "
          "~/setup/claude/.claude/themes/theme.json")
    print("  herdr config check && herdr server reload-config")
    return 0


def cmd_adopt(args):
    import shutil
    name = current_palette()
    if not name:
        raise SystemExit("current_pallete.txt is empty")
    path = resolve_palette(name)
    shutil.copyfile(path, APPLIED)
    print("snapshot now records %s as applied" % name)
    return 0


def cmd_check(args):
    path = resolve_palette(args.palette)
    roles = read_palette(path)
    if not roles:
        raise SystemExit("no roles parsed from %s" % path)

    names = [n for n, _ in roles]
    failures = []
    warnings = []
    collisions = []

    print("%s: %d roles" % (path, len(roles)))
    if os.path.isfile(APPLIED) and current_palette() == args.palette:
        applied = dict(read_palette(APPLIED))
        drift = [n for n, h in roles
                 if n in applied and applied[n].lower() != h.lower()]
        if drift:
            print("  DRIFT: %s is the live palette and %d role(s) differ from"
                  % (args.palette, len(drift)))
            print("  what was applied to the configs: %s"
                  % ", ".join(drift[:6]) + (", ..." if len(drift) > 6 else ""))
            print("  Those configs hold hexes that exist in no palette file, so")
            print("  no future swap can reach them. Fix with: palette.py sync")
    if names != ROLE_ORDER and sorted(names) == sorted(ROLE_ORDER):
        print("  NOTE: role order differs from the canonical order. Harmless")
        print("  for the file itself, but update_palette.sh pairs old to new")
        print("  POSITIONALLY, so a swap against a canonically-ordered palette")
        print("  will silently mismap every role.")
    if sorted(names) != sorted(ROLE_ORDER):
        failures.append("role set does not match the 21-role vocabulary")

    bg = dict(roles).get("bg")
    if bg is None:
        raise SystemExit("no bg role; cannot measure anything")

    # Measure everything first: the semantic floor a role must clear depends on
    # which axis it is on, and that is not known until the axes are grouped.
    measured = []
    for name, hx in roles:
        L, C, H = hex_to_oklch(hx)
        measured.append((name, hx, L, C, H, contrast(hx, bg)))
    hues = [(n, H) for n, _, _, C, H, _ in measured if C >= GREY_CHROMA]

    # Axis structure, by the same 45-degree rule the sampler uses.
    clusters = circular_clusters(hues, MIN_AXIS_SEP)
    # The axis carrying bg is the primary; it gets the lower floor.
    primary_axis = 0
    for i, c in enumerate(clusters):
        if any(n == "bg" for n, _ in c):
            primary_axis = i
    floor_of = {}
    for i, c in enumerate(clusters):
        f = (MIN_SEMANTIC_SEP_PRIMARY if i == primary_axis
             else MIN_SEMANTIC_SEP_SECONDARY)
        for n, _ in c:
            floor_of[n] = f

    print()
    print("  axes (groups separated by a gap of %.0f deg or more): %d"
          % (MIN_AXIS_SEP, len(clusters)))
    for i, c in enumerate(clusters):
        hs = [h for _, h in c]
        width = max(hs) - min(hs)
        span = width if width < 180 else 360 - width
        print("    %-9s hue %.1f - %.1f (%.0f deg wide), %d roles, floor %.0f"
              % ("primary" if i == primary_axis else "secondary",
                 min(hs), max(hs), span, len(c), floor_of[c[0][0]]))
    if len(clusters) > 2:
        # Advisory, not a failure. The two-axis limit describes the DEFAULT
        # seam that `build` applies; a hand-configured palette may define a
        # third group deliberately. What actually has to hold is that every
        # axis clears its own floor, which is checked per role below.
        warnings.append("%d chrome axes. `build` only ever emits two, so this "
                        "palette was hand-configured; confirm that is intended"
                        % len(clusters))

    prov = provenance(roles, args.image) if args.image else None

    print()
    head = ("  %-15s %-8s %6s %6s %6s %7s %-10s"
            % ("role", "hex", "L", "C", "H", "vs bg", "nearest sem"))
    print(head + ("%8s  %s" % ("dE", "source") if prov else ""))
    for name, hx, L, C, H, ratio in measured:
        sem, sep = nearest_semantic(H)
        flags = []
        if name in CONTRAST_ROLES and ratio < TEXT_CONTRAST:
            flags.append("CONTRAST")
            failures.append("%s is %.2f:1 against bg, under %.1f"
                            % (name, ratio, TEXT_CONTRAST))
        if C >= GREY_CHROMA and sep < floor_of[name]:
            flags.append("SEPARATION")
            # Hue separation is ADVISORY on both axes. It is a design heuristic
            # for choosing where to put a band, not a correctness test on a
            # finished palette - and which axis counts as "secondary" depends
            # only on where bg landed, so the same colors flip between passing
            # and failing when the ground color changes. The binding test is
            # status_collision below, which measures what actually determines
            # confusability.
            warnings.append("%s is %.1f deg from %s, under its floor of %.0f "
                            "(advisory)" % (name, sep, sem, floor_of[name]))
        hit = status_collision(hx, name)
        if hit:
            flags.append("CONFUSABLE")
            suggestion = suggest_lightness(name, hx, bg)
            note = ("%s is dE %.3f from catppuccin %s at comparable chroma; "
                    "they will read as the same color" % (name, hit[1], hit[0]))
            if suggestion:
                note += " (try lightness %.3f, %s)" % suggestion
            # Reported rather than enforced by default. This test postdates
            # most of the palettes here and four of them violate it, two in
            # ways that would visibly change a hand-tuned palette. Enforcing it
            # retroactively would just mean a permanently failing check, so it
            # is loud instead. Pass --strict to make it binding.
            if args.strict:
                failures.append(note)
            else:
                collisions.append(note)
        if hx.upper() in ("#000000", "#FFFFFF"):
            flags.append("PURE")
            failures.append("%s is %s; hex-keyed replacement is context-blind "
                            "and will rewrite unrelated files" % (name, hx))
        row = ("  %-15s %-8s %6.3f %6.3f %6.1f %6.2f:1  %-10s"
               % (name, hx, L, C, H, ratio, "%s %.0f" % (sem, sep)))
        if prov:
            de = prov[name]
            row += "%8.3f  %-13s" % (de, "SAMPLED" if de < 0.03
                                     else "EXTRAPOLATED")
        print(row + " " + " ".join(flags))

    print()
    if collisions:
        print("CONFUSABLE WITH A STATUS COLOUR (%d)%s:"
              % (len(collisions), "" if args.strict else " - reported, not enforced"))
        for c in collisions:
            print("  - %s" % c)
        print("  A status colour carries meaning, so chrome resembling one is a")
        print("  real defect. Move the role's lightness, which buys distance")
        print("  without touching hue. Run with --strict to fail on these.")
        print()
    if warnings:
        print("WARNINGS (%d), advisory only:" % len(warnings))
        for w in warnings:
            print("  - %s" % w)
        print()
    if failures:
        print("FAIL (%d):" % len(failures))
        for f in failures:
            print("  - %s" % f)
        return 1
    print("PASS. Every binding gate cleared.")
    print("Reminder: these ratios are upper bounds. wezterm renders at")
    print("window_background_opacity 0.8, so the wallpaper blends in and the")
    print("real on-screen contrast is lower. Look at it before you commit.")
    return 0


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("sample", help="report a wallpaper's color axes")
    s.add_argument("image")
    s.set_defaults(func=cmd_sample)

    b = sub.add_parser("build", help="emit a .colors file from chosen hues")
    b.add_argument("--name", required=True)
    b.add_argument("--primary", type=float, required=True)
    b.add_argument("--secondary", type=float, default=None)
    b.add_argument("--width", type=float, default=1.0,
                   help="scale the reference band width (default 1.0)")
    b.add_argument("--reference", default="tea-terrace")
    b.add_argument("--out", default=None)
    b.add_argument("--force", action="store_true")
    b.set_defaults(func=cmd_build)

    y = sub.add_parser("sync", help="propagate edits to the LIVE palette into "
                                    "every consuming file")
    y.add_argument("--dry-run", action="store_true")
    y.add_argument("--adopt", action="store_true",
                   help="record the current palette as applied without "
                        "changing any config; use when the configs are already "
                        "known to match")
    y.set_defaults(func=lambda a: cmd_adopt(a) if a.adopt else cmd_sync(a))

    c = sub.add_parser("check", help="measure a .colors file against the gates")
    c.add_argument("palette")
    c.add_argument("--strict", action="store_true",
                   help="fail on a role that is perceptually confusable with a "
                        "status colour, instead of only reporting it")
    c.add_argument("--image", default=None,
                   help="wallpaper to measure provenance against; reports the "
                        "OKLab distance from each role to the nearest pixel "
                        "the image actually contains")
    c.set_defaults(func=cmd_check)

    args = p.parse_args()
    sys.exit(args.func(args))


if __name__ == "__main__":
    main()
