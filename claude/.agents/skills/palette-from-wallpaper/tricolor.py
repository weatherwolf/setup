#!/usr/bin/env python3
"""Hand-configured multi-axis palette, for wallpapers with three real colors.

`palette.py build` emits a fixed two-axis seam. This is the escape hatch: it
puts four hue groups on the 21 roles and boosts saturation, then re-solves
lightness so contrast still holds. The defaults below are goa-cove's, which is
the worked example the skill documents.

Usage:

    tricolor.py --name NAME --ground 115 --accent 66 --detail 206 --leaf 138

  ground   backgrounds. The darkest, largest color in the photograph.
  leaf     the near-neutral text ramp. Defaults to ground; give it its own
           hue when the ground hue had to be shifted so far to clear a
           semantic color that the text reads as the wrong color.
  accent   border, cursor and the whole accent family.
  detail   text_muted, text_dim and the reserves. The third color.

Everything it emits still has to pass `palette.py check`. Read the tri-color
section of SKILL.md before changing the constants; each one is there for a
reason that is recorded.
"""

import argparse
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from palette import (CHROMA_RATIO, CONFUSABLE, CONFUSABLE_EXEMPT,
                     CONTRAST_ROLES, ROLE_ORDER, STATUS_HEX, SYNTAX_HEX,
                     contrast, hex_to_oklch, min_lightness_for_contrast, oklab,
                     oklch_to_hex, read_palette, resolve_palette,
                     status_collision)

# Only these two mid-text roles carry enough chroma for a hue to be visible.
# text_bright and text sit near white by design, so putting a third color on
# them changes nothing you can see.
DETAIL_TEXT = ["text_muted", "text_dim"]

GROUP = {
    "ground": ["bg", "bg_surface", "bg_raised", "bg_selection"],
    "leaf": ["text_bright", "text", "text_secondary", "text_hint"],
    "accent": ["border", "cursor", "accent", "accent_bright", "accent_light",
               "accent_soft", "accent_vivid"],
    "detail": DETAIL_TEXT + ["reserve_1", "reserve_2", "reserve_3", "reserve_4"],
}

# Per-role hue offset inside its band, so a band is not one flat hue. Keep the
# spread small on any band that sits near a catppuccin hue.
OFFSET = {"bg": 6, "bg_surface": 3, "bg_raised": 0, "bg_selection": 4,
          "text_bright": -2, "text": -3, "text_secondary": 1, "text_hint": 0,
          "text_muted": 3, "text_dim": -2,
          "border": -1, "cursor": -8, "accent": 5, "accent_bright": -8,
          "accent_light": -7, "accent_soft": 7, "accent_vivid": -6,
          "reserve_1": -2, "reserve_2": 0, "reserve_3": 3, "reserve_4": 1}

# Saturation multiplier over the reference ladder. Largest at the dark end,
# which is where the ladder is flattest, and tapering to almost nothing at the
# near-white text roles - those have to stay near-white or the whole terminal
# takes on a tint.
BOOST = {"bg": 1.85, "bg_surface": 1.85, "bg_raised": 1.9, "bg_selection": 1.7,
         "text_bright": 1.3, "text": 1.4, "text_secondary": 1.6,
         "text_hint": 1.6, "text_muted": 1.35, "text_dim": 1.3,
         "border": 1.0,
         "cursor": 1.2, "accent": 1.25, "accent_bright": 1.60,
         "accent_light": 1.2, "accent_soft": 1.5, "accent_vivid": 1.15,
         "reserve_1": 1.2, "reserve_2": 1.2, "reserve_3": 1.2,
         "reserve_4": 1.7}

# border is the one role the ladder gets wrong for a colored palette. At
# lightness 0.500 and chroma 0.020 a warm border renders as dark brown and
# reads as grey. Both values are overridden outright rather than scaled.
LIGHTNESS = {"border": 0.575,
             # accent_bright at the ladder's 0.864 lands dE 0.062 from
             # catppuccin yellow at matching chroma, and it now paints the
             # whole nvim file tree while yellow means "warning". Dropping it
             # to 0.820 puts it at 0.107, clear, and still 9.3:1 against bg.
             "accent_bright": 0.820}
CHROMA = {"border": 0.100}

# The confusability model lives in palette.py so `check` and this tool
# cannot drift apart. STATUS/SYNTAX split, the dE threshold, the
# saturation guard and the cursor exemption are all defined there.
STATUS = STATUS_HEX
SYNTAX = SYNTAX_HEX
CATPPUCCIN = dict(STATUS, **SYNTAX)

SECTIONS = [
    ("background", ["bg", "bg_surface", "bg_raised", "bg_selection"]),
    ("text", ["text_bright", "text", "text_secondary", "text_muted",
              "text_dim", "text_hint"]),
    ("chrome", ["border", "cursor", "accent", "accent_bright", "accent_light",
                "accent_soft", "accent_vivid"]),
    ("reserve", ["reserve_1", "reserve_2", "reserve_3", "reserve_4"]),
]


def max_chroma(L, H, margin=0.92):
    """Largest chroma at this lightness and hue that survives the sRGB round trip.

    Without this cap a boosted dark color clips a channel to zero: the emitted
    hex is not the color that was asked for, and it bands on screen. goa-cove's
    bg came out #1B2300 before the cap and #2A1C09 after.
    """
    lo, hi = 0.0, 0.4
    for _ in range(40):
        mid = (lo + hi) / 2
        if abs(hex_to_oklch(oklch_to_hex(L, mid, H))[1] - mid) < 0.002:
            lo = mid
        else:
            hi = mid
    return lo * margin


def nearest_catppuccin(hexv, family=CATPPUCCIN):
    r = oklab(*hex_to_oklch(hexv))
    return min(((k, math.dist(r, oklab(*hex_to_oklch(v))))
                for k, v in family.items()), key=lambda t: t[1])





def resolve_collision(role, L, C, H, bg_hex):
    """Walk lightness away from the status color until the role is distinct.

    Lightness is the lever because it buys distance without touching hue;
    cutting chroma would undo the reason the color was placed there. Both
    directions are tried and the smaller move wins, subject to still clearing
    4.5:1 for any role that has to.
    """
    best = None
    for step in [i * 0.005 for i in range(1, 41)]:
        for cand in (L - step, L + step):
            if not 0.05 < cand < 0.99:
                continue
            c = min(C, max_chroma(cand, H))
            hexv = oklch_to_hex(cand, c, H)
            if status_collision(hexv, role):
                continue
            if role in CONTRAST_ROLES and contrast(hexv, bg_hex) < 4.5:
                continue
            best = (cand, c, hexv)
            break
        if best:
            return best
    return None


def build(hues, reference, saturation=1.0, moves=None,
          lightness=None):
    ladder = {n: hex_to_oklch(h)
              for n, h in read_palette(resolve_palette(reference))}
    axis = {}
    for group, roles in GROUP.items():
        for r in roles:
            axis[r] = hues[group]
    for role, group in (moves or {}).items():
        axis[role] = hues[group]

    def value(role, bg_hex):
        L, C, _ = ladder[role]
        L = (lightness or {}).get(role, LIGHTNESS.get(role, L))
        hue = (axis[role] + OFFSET[role]) % 360
        C = min(CHROMA.get(role, C * BOOST[role]) * saturation,
                max_chroma(L, hue))
        raised = None
        if role in CONTRAST_ROLES and bg_hex is not None:
            floor = min_lightness_for_contrast(C, hue, bg_hex)
            if L < floor:
                raised = (L, floor + 0.003)
                L = floor + 0.003
                C = min(C, max_chroma(L, hue))
        return oklch_to_hex(L, C, hue), raised

    out = {}
    raises = []
    moved = []
    out["bg"], _ = value("bg", None)
    for role in ROLE_ORDER:
        if role == "bg":
            continue
        out[role], raised = value(role, out["bg"])
        if raised:
            raises.append((role, raised[0], raised[1]))
        hit = status_collision(out[role], role)
        if hit:
            L, C, H = hex_to_oklch(out[role])
            fixed = resolve_collision(role, L, C, H, out["bg"])
            if fixed:
                moved.append((role, hit[0], hit[1], L, fixed[0]))
                out[role] = fixed[2]
    return out, raises, moved


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--name", required=True)
    p.add_argument("--duo", metavar="MAJOR:SECONDARY", default=None,
                   help="the preferred two-colour division. MAJOR takes the "
                        "backgrounds, the near-neutral text ramp and "
                        "accent_vivid; SECONDARY takes every role that visibly "
                        "carries colour. Equivalent to --ground M --leaf M "
                        "--accent S --detail S --move accent_vivid:ground. "
                        "sequioa-morning is the worked example.")
    p.add_argument("--ground", type=float, default=None)
    p.add_argument("--accent", type=float, default=None)
    p.add_argument("--detail", type=float, default=None,
                   help="third-color hue for text_muted, text_dim and the "
                        "reserves; defaults to --ground, which makes this a "
                        "two-color palette that still gets the saturation, "
                        "gamut and border handling")
    p.add_argument("--saturation", type=float, default=1.0,
                   help="scale every chroma boost. 1.0 is the vibrant default "
                        "tuned for goa-cove. Match it to the wallpaper: divide "
                        "the image's median chroma by goa-cove's 0.051. A "
                        "hazy, desaturated photo wants roughly 0.55, and "
                        "building it at 1.0 misrepresents the image.")
    p.add_argument("--leaf", type=float, default=None,
                   help="text ramp hue; defaults to --ground")
    p.add_argument("--reference", default="tea-terrace")
    p.add_argument("--out", default=None)
    p.add_argument("--force", action="store_true")
    p.add_argument("--lightness", action="append", default=[],
                   metavar="ROLE:VALUE",
                   help="override one role's OKLCH lightness, repeatable. "
                        "Shift the whole bg family together rather than bg "
                        "alone, or the step to bg_surface widens visibly.")
    p.add_argument("--move", action="append", default=[], metavar="ROLE:GROUP",
                   help="reassign one role to another hue group, repeatable. "
                        "e.g. --move accent_vivid:detail. Use it when the "
                        "default seam parks a color the image is full of on "
                        "roles nothing renders - the reserves in particular.")
    args = p.parse_args()

    duo_move = {}
    if args.duo:
        if ":" not in args.duo:
            raise SystemExit("--duo wants MAJOR:SECONDARY, got %r" % args.duo)
        try:
            major, secondary = (float(v) for v in args.duo.split(":", 1))
        except ValueError:
            raise SystemExit("--duo hues must be numbers, got %r" % args.duo)
        for name, val in (("ground", major), ("leaf", major),
                          ("accent", secondary), ("detail", secondary)):
            if getattr(args, name) is None:
                setattr(args, name, val)
        # accent_vivid is Claude Code's clawd_body. It sits on the MAJOR colour
        # so the mascot matches the ground rather than the highlights; an
        # explicit --move for it still wins.
        duo_move["accent_vivid"] = "ground"
    if args.ground is None or args.accent is None:
        raise SystemExit("give either --duo MAJOR:SECONDARY, or both --ground "
                         "and --accent")

    lightness = {}
    for spec in args.lightness:
        if ":" not in spec:
            raise SystemExit("--lightness wants ROLE:VALUE, got %r" % spec)
        role, val = spec.split(":", 1)
        if role not in ROLE_ORDER:
            raise SystemExit("no such role: %s" % role)
        try:
            lightness[role] = float(val)
        except ValueError:
            raise SystemExit("--lightness value must be a number, got %r" % val)
        if not 0.02 < lightness[role] < 0.99:
            raise SystemExit("lightness out of range: %s" % val)

    moves = {}
    for spec in args.move:
        if ":" not in spec:
            raise SystemExit("--move wants ROLE:GROUP, got %r" % spec)
        role, group = spec.split(":", 1)
        if role not in ROLE_ORDER:
            raise SystemExit("no such role: %s" % role)
        if group not in GROUP:
            raise SystemExit("no such group: %s (pick from %s)"
                             % (group, ", ".join(sorted(GROUP))))
        moves[role] = group
    for role, group in duo_move.items():
        moves.setdefault(role, group)

    hues = {"ground": args.ground, "accent": args.accent,
            "detail": args.detail if args.detail is not None else args.ground,
            "leaf": args.leaf if args.leaf is not None else args.ground}
    out, raises, moved = build(hues, args.reference, args.saturation,
                               moves, lightness)

    path = args.out or os.path.expanduser(
        "~/setup/palettes/%s.colors" % args.name)
    if os.path.exists(path) and not args.force:
        raise SystemExit("refusing to overwrite %s (pass --force)" % path)

    lines = ["# %s - machine-readable palette" % args.name, "#",
             "# HAND-CONFIGURED by tricolor.py. Do NOT regenerate with",
             "# `palette.py build` - that emits the fixed two-axis seam and",
             "# would silently discard the layout below.", "#",
             "# ground %.0f, leaf %.0f, accent %.0f, detail %.0f, "
             "saturation %.2f."
             % (hues["ground"], hues["leaf"], hues["accent"], hues["detail"],
                args.saturation),
             "#",
             "# TODO: replace this header. Record which roles are SAMPLED and",
             "# which are EXTRAPOLATED, the hue shifts and why each was made,",
             "# and any warning you accepted deliberately."]
    for title, members in SECTIONS:
        lines.append("")
        lines.append("[%s]" % title)
        for r in members:
            lines.append("%s=%s" % (r, out[r]))
    with open(path, "w") as fh:
        fh.write("\n".join(lines) + "\n")
    print("wrote %s" % path)

    if moved:
        print("\nlightness moved to stay distinct from a status color:")
        for role, k, d, was, now in moved:
            print("  %-15s %.3f -> %.3f  (was dE %.3f from %s)"
                  % (role, was, now, d, k))
    if raises:
        print("\nlightness raised to hold 4.5:1 at the new hue:")
        for role, was, now in raises:
            print("  %-15s %.3f -> %.3f" % (role, was, now))

    print("\n  %-15s %-9s %6s %6s %6s %8s  %s"
          % ("role", "hex", "L", "C", "H", "vs bg", "nearest catppuccin"))
    risky = []
    for title, members in SECTIONS:
        for r in members:
            L, C, H = hex_to_oklch(out[r])
            k, d = nearest_catppuccin(out[r])
            sk, sd = nearest_catppuccin(out[r], STATUS)
            flag = ""
            role_c = hex_to_oklch(out[r])[1]
            status_c = hex_to_oklch(STATUS[sk])[1]
            if (sd < CONFUSABLE and r not in CONFUSABLE_EXEMPT
                    and role_c >= CHROMA_RATIO * status_c):
                flag = "  <-- confusable with a STATUS color"
                risky.append((r, sk, sd))
            print("  %-15s %-9s %6.3f %6.3f %6.1f %7.2f:1  %-10s dE %.3f%s"
                  % (r, out[r], L, C, H, contrast(out[r], out["bg"]), k, d,
                     flag))

    if risky:
        print("\n%d role(s) within dE %.2f of a STATUS color, which carries"
              % (len(risky), CONFUSABLE))
        print("meaning and must stay distinct:")
        for r, k, d in risky:
            print("  %-15s dE %.3f from %s" % (r, d, k))
        print("Raise that role's lightness first - it buys distance without")
        print("costing hue. Cutting chroma also works but undoes the point of")
        print("having put a color there.")
    else:
        print("\nNo role is within dE %.2f of a status color. Proximity to a"
              % CONFUSABLE)
        print("syntax color is shown above and is advisory only.")
    print("\nnow: write a real header, then `palette.py check %s`" % args.name)


if __name__ == "__main__":
    main()
