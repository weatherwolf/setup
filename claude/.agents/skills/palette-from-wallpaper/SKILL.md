---
name: palette-from-wallpaper
description: Build a ~/setup terminal palette from a desktop wallpaper, decide whether that wallpaper supports one chrome color or two, and swap it in. Use when adding a palette, changing the wallpaper this setup is themed against, or checking an existing palette for contrast and hue-separation problems.
---

# palette-from-wallpaper

Turn a wallpaper into the 21 colors in `~/setup/palettes/<name>.colors`, then
swap it in. The hard part is not picking pretty colors. It is deciding how many
colors the wallpaper actually supports, and keeping every one of them clear of
the six colors that carry meaning.

All the arithmetic lives in `palette.py` next to this file. Do not do it by
hand; OKLCH conversion and WCAG contrast are not eyeball-able.

## The two families

**Chrome** is backgrounds, borders, cursor, selection, tab bars, accents. It is
sampled from the wallpaper, it carries no information, and it is the only thing
a palette swap replaces. Because it carries no information it MAY be monochrome,
and often should be.

**Meaning** is pass/fail, added/removed, warnings, syntax. It is catppuccin
mocha and it is CONSTANT across palettes. `green` means "test passed" no matter
what the chrome looks like, so it is not a palette variable and does not live in
a `.colors` file.

Everything below exists to keep chrome from wandering into meaning.

## Quick start

```bash
S=~/.claude/skills/palette-from-wallpaper

python3 $S/palette.py sample ~/Pictures/wallpaper.png     # what colors are in it
python3 $S/palette.py build --name my-palette --primary 245 [--secondary 45]
$EDITOR ~/setup/palettes/my-palette.colors                # write a real header
python3 $S/palette.py check my-palette --image ~/Pictures/wallpaper.png
~/setup/update_palette.sh my-palette                      # swap
```

For a wallpaper with two real colours, prefer `tricolor.py --duo` over `build`
(Step 2a) - unless the brief wants the DOMINANT colour emphasised, in which
case the dominant colour takes the accents too (end of Step 2a). For three, see Step 2b. `build` is the plainest mapping, not the best
one. And if you edit a palette that is already live, read "Editing a palette
that is already live" first - a plain edit strands roles in the configs.

`sample` ends with a VERDICT line that gives you the exact `build` command. Take
it unless you have a reason not to.

Pass `--image` to `check` and it reports, per role, the OKLab distance to the
nearest color the photograph actually contains. Under dE 0.03 the role is a
genuine sample; above it, it was invented. That is the measurement Step 4 needs,
so do not write the header without it.

## Step 1. Decide one color or two

This is the only decision that matters and `sample` makes it for you. It runs
three tests. Know what they mean, because you will sometimes want to override.

**Test 1: are there really two colors? Gap of 45 degrees or more.**

Below 45 you have one color with variation, not two colors. This is not a close
call in practice: 45 degrees is roughly the distance from blue to teal, and
people name those differently. Anything tighter is "blue with some variation."

`glacier-wave` is the worked example. Its roles span 48 degrees of hue with a 25
degree gap in the middle, and for a while that got described as a two-color
palette. It is not. Every consecutive pair of its roles is closer than 45
degrees apart, so it is one wide band. Say it that way.

**Test 2: is the second color far enough from the signal colors?**

The six signal hues never move:

```
red 2.8    yellow 86.5    green 142.7    teal 182.7    mauve 304.8    pink 336.3
```

Chrome lives in the gaps between them, and the gaps are wildly uneven:

```
blue / indigo       182.7 -> 304.8    122 deg wide    best case 61 deg of clearance
orange / amber        2.8 ->  86.5     84             best case 42
olive / chartreuse   86.5 -> 142.7     56             best case 28
green               142.7 -> 182.7     40             best case 20
violet / magenta    304.8 -> 336.3     32             best case 16
rose / crimson      336.3 ->   2.8     27             best case 13
```

**The primary axis has an advisory floor of 13 degrees. The secondary has a
binding floor of 20.**

The asymmetry is the point. A primary is mandatory: chrome has to go somewhere,
so you accept whatever room the wallpaper's hue allows. `tea-terrace` shipped
with `text_muted` 12.8 degrees from teal, and that was the right call because
green has nowhere better to go. A secondary is optional: if it cannot be
comfortable, dropping it costs nothing, so it has to earn its place.

What the 20 floor excludes, concretely: **violet and rose can never be a
secondary color.** A sunset wallpaper is usually orange plus violet, and the
violet is wedged between mauve and pink with 16 degrees of room at best. The
skill will keep the orange and drop the violet, and you get a one-color orange
palette from a sunset photo. That is the intended behavior. Accept it or
override it knowingly.

**Test 3: is the second color actually present? 10 percent of the image.**

Weighted by saturation, not by pixel count. A small vivid region reads louder
than a large drained one, so an 8 percent sunset strip over a dark ocean counts
and a 40 percent washed-out grey sky does not. Area alone gets this backwards.

The floor exists because photographs contain small patches of unrelated color
everywhere - a single flower, a reflection, compression artifacts in the darks.
Without it, half your accent family can come from something you never noticed.

**Three or more colors.** The role vocabulary has two homes and no third.
`sample` will tell you a third axis survived the gates and has nowhere to go.
Use it for `reserve_1..4` if you want it on the record, and say so in the
header. Do not invent a role for it.

## Step 2. What `build` emits by default

`build`'s fixed seam, for reference. It is fine, but **Step 2a is the preferred
division for a two-colour palette** - it puts the coloured roles where colour
actually reads. Use this one only when you want the plainest possible mapping:

```
primary     bg  bg_surface  bg_raised  bg_selection
            text_bright  text  text_secondary  text_muted  text_dim  text_hint
            border
secondary   cursor  accent  accent_bright  accent_light  accent_soft
            accent_vivid  reserve_1..4
```

Backgrounds and the text ramp stay together on one hue because they are the
contrast ladder, and a ladder split across two hues has to be verified twice.
The highlight family carries the second color because that is where a second
color has visible payoff and where failure is survivable.

`bg` goes on the primary, which should be the wallpaper's dominant and darker
axis. That is also where the dark pixels actually are, so `bg` can be genuinely
sampled rather than invented.

## Step 2a. Two colors: the preferred division

For a two-colour wallpaper this is the division to use. `sequioa-morning` is the
worked example and one flag reproduces it:

```bash
S=~/.claude/skills/palette-from-wallpaper
python3 $S/tricolor.py --name NAME --duo MAJOR:SECONDARY --saturation 0.60
```

```
MAJOR      bg  bg_surface  bg_raised  bg_selection      the ground
     9     text_bright  text  text_secondary  text_hint    warm off-whites
   roles   accent_vivid                                  Claude's clawd_body

SECONDARY  border  cursor  accent  accent_bright         all visible chrome
    12     accent_light  accent_soft
   roles   text_muted  text_dim                          the coloured text
           reserve_1..4
```

**The split follows chroma, which is why it works.** Every role on the major
carries chroma 0.008 to 0.046, so its hue barely registers: the reading text
reads as a warm or cool off-white rather than as a colour, and it does not fight
the secondary. Every role on the secondary carries 0.040 to 0.081, where hue is
plainly visible. So the major is what the terminal *is*, and the secondary is
everything that *pops*.

Three consequences worth knowing before you deviate:

- **`text_muted` and `text_dim` are the only text roles that take the secondary**,
  because they are the only two with enough chroma for a hue to read.
  `text_bright` at 0.008 would look identical whichever colour you assigned it.
  This is what "coloured text, but not all the text" means mechanically.
- **`accent_vivid` sits on the major, not with the rest of the accent family.**
  It is `clawd_body`, and `clawd_background` is pinned to `bg`, so keeping it on
  the major gives the mascot a body that matches the ground. Override with
  `--move accent_vivid:accent` if you want it to join the highlights.
- **The reserves sit on the secondary**, so promoting one into a real role later
  is coherent rather than introducing a third colour by accident.

`--duo` is shorthand for `--ground M --leaf M --accent S --detail S --move
accent_vivid:ground`, and any explicit flag still overrides it. Use `--leaf`
separately when the major's hue had to be shifted far enough to clear a semantic
colour that the text reads as the wrong colour - see Step 2b.

Which colour should be MAJOR is not the one with the larger share. In
`sequioa-morning` green covers 56.4% of the photograph and bark only 31.0%, and
bark is still the major, because share measures how much of a picture a colour
covers, not what should carry a terminal's ground. Pick the one that reads as
substrate, and check it has dark pixels to sample.

### When the second colour must NOT be the accent

`sample`'s VERDICT and `--duo` both assume the second colour is what should
pop. That is a default, not a rule. When the brief is "emphasise the X parts"
and X is the DOMINANT colour, putting the minority colour on the accents does
the opposite of what was asked: the terminal's visible chrome ends up the
colour the wallpaper has least of.

`coal-mine-canyon` is the worked example. Rust covers 63% of the photograph
and blue-grey rock 21%; the VERDICT said `--primary 37 --secondary 222`,
which would have made a rust terminal with blue borders, cursor and file
tree. The brief was the red. So the dominant colour took BOTH the ground and
the highlight family, and the minority colour became the `detail` group:

```bash
python3 $S/tricolor.py --name NAME --ground 37 --leaf 37 --accent 33 --detail 222 \
        --saturation 1.0 --move accent_vivid:ground --move reserve_1:accent
```

```
ground/leaf  bg family, text_bright..text_secondary, text_hint, accent_vivid
accent       border cursor accent accent_bright accent_light accent_soft
             reserve_1                        the SAME colour, more chroma
detail       text_muted text_dim reserve_2..4  the minority colour
```

Three things make this work rather than turning into a one-colour palette:

- **`--accent` is the ground hue nudged a few degrees toward the brief.** Rust
  at 37 became 33 on the accents, and the ladder's per-role offsets spread the
  family across 31-42. Same colour, visibly more saturated and a touch redder
  than the ground. Do not nudge past the secondary floor of 20 from the
  nearest status hue: red sits at 2.8, so 23 is the limit for a rust family.
- **The minority colour lives on `text_muted` and `text_dim`**, exactly as in
  Step 2a, because those are the two text roles with enough chroma to read
  as a colour. It is present, it is the photograph's counterpoint, and it
  never carries chrome.
- **`--move reserve_1:accent` is mandatory here**, or folders come out in the
  minority colour against files in the dominant one (the goa-cove mistake).

Check that the dominant colour has dark pixels before doing this: it is
taking `bg`. Rust did (p05 0.29), so all four backgrounds were genuine
samples. `--duo` is still right when the dominant colour is the ground and
the second colour is what the brief wants seen.

## Step 2b. Three colors, by hand

The two-axis limit is `build`'s, not the format's. A wallpaper with three real
colors gets `tricolor.py`, which puts four hue groups on the 21 roles:

```bash
S=~/.claude/skills/palette-from-wallpaper
python3 $S/tricolor.py --name NAME --ground 115 --accent 66 --detail 206 --leaf 138
```

```
ground   bg bg_surface bg_raised bg_selection
leaf     text_bright text text_secondary text_hint
accent   border cursor accent accent_bright accent_light accent_soft accent_vivid
detail   text_muted text_dim reserve_1..4
```

`goa-cove` is the worked example and those are its exact arguments; running
them reproduces the shipped file. What each choice is for:

**The third color goes on `text_muted` and `text_dim`, not on the whole text
ramp.** Those are the only two mid-text roles carrying enough chroma for a hue
to be visible - `text_bright` sits at chroma 0.012 and `text` at 0.038, so a
third color placed there changes nothing you can see. The two that do carry it
are also the visible ones downstream: `text_muted` is Claude's `inactive`, and
`text_dim` is nvim's folder arrows, Claude's `subtle` and wezterm's
`brights[0]`.

**`leaf` exists because clearing a semantic hue can change what color the text
reads as.** goa-cove's jungle green measured at 135, 8 degrees from catppuccin
green, so the ground moved to 115 - and at 115 the text read as yellow, not
green. Splitting them keeps the backgrounds safely olive at 22 degrees of
clearance while the text carries the photograph's actual foliage hue at 138.
About 20 degrees apart shows as a tint difference, not as two colors. Leave
`--leaf` off when the ground hue did not have to move far.

**Saturation is boosted at the dark end and tapered at the light end.** The
ladder is flattest in the darks, which is what reads as drab; the near-white
text roles have to stay near-white or the whole terminal takes on a tint.
goa-cove's `bg` goes from chroma 0.034 to 0.055 while `text_bright` moves only
0.009 to 0.012. Do not scale uniformly.

**Match `--saturation` to the wallpaper, or two photographs with the same hues
produce the same palette.** The boost constants are tuned for goa-cove, whose
image has median chroma 0.051. Divide your image's median chroma by that and
pass the ratio. `sequioa-morning` shares almost exactly goa-cove's hues - ground
116 against 115, accent 65 against 66 - and is a completely different palette
only because its photograph measures 0.030 and it was built at 0.60. A hazy or
overcast image built at 1.0 does not look like itself.

Muting also improves provenance: `sequioa-morning` is the only palette here
where all 21 roles are genuine samples, because low chroma keeps every value
inside the range the photo actually covers.

**A two-color wallpaper can still use this tool.** Leave `--detail` off and it
defaults to `--ground`, so you keep the saturation control, the gamut cap, the
`border` fix and the collision check without inventing a third color the image
does not have.

**Every value is capped at 92% of the sRGB gamut ceiling for its lightness and
hue.** Without the cap a boosted dark color clips a channel to zero - goa-cove's
`bg` came out `#1B2300` - so the emitted hex is not the color requested, and it
bands. The cap is why `bg` cannot be pushed further: at that lightness it is
already at the edge.

**`border` needs both its lightness and its chroma overridden, not scaled.** At
the ladder's 0.500 and 0.020 a warm border renders as dark brown and reads as
grey. goa-cove's is 0.575 and 0.100, a visible gold at 3.7:1.

### Judge low-chroma roles by distance, not by hue

Step 1's hue floors are the wrong instrument for the text ramp. A near-white
role can sit 4 degrees from catppuccin green and be unmistakable, because it
carries a third of the chroma. `tricolor.py` reports perceptual distance
instead and flags a role only when both conditions hold:

- it is within dE 0.10 of a **status** colour - one of the six that carry
  meaning, not the eight syntax ones; a gold accent family will always sit near
  `peach`, and that is fine
- it is at least 60% as saturated as that colour, since a signal reads as a
  signal by being saturated, and a pale role cannot masquerade as one

`cursor` is exempt: it is a solid block rather than a glyph, and all three
earlier palettes already have one close to something (glacier dE 0.011 from
`sky`).

`tricolor.py` resolves a status collision itself, by walking the role's
lightness away in whichever direction is nearer until it clears, subject to
still holding 4.5:1. It reports every move it makes. Lightness is the lever
because it buys distance without touching hue, whereas cutting chroma undoes
the reason the color was placed there.

Two real catches came out of this on goa-cove, both invisible to a hue check.
`accent_bright` landed dE 0.062 from catppuccin `yellow` at matching chroma,
which matters because it now paints the whole nvim file tree while yellow means
warning - fixed by dropping its lightness to 0.820. And when a role does need
distance, **raise its lightness first**: it buys separation without touching
hue, whereas cutting chroma undoes the reason the colour was put there.

**"Raise lightness first" fails for a red or rust family.** The pastel end
of a warm family - `accent_bright` at L 0.82 and `accent_light` at 0.80 -
sits between catppuccin `red` (L 0.76, C 0.13, hue 2.8) and `pink` (L 0.87,
C 0.075, hue 336). At the ladder's chroma of about 0.07, EVERY lightness from
0.70 to 0.88 is within dE 0.10 of one of them, at any hue from 20 to 45. So
the resolver walks `accent_bright` up until it clears pink at L 0.92, where
it is a near-white that paints the whole nvim file tree the same as body
text, and `reserve_1` gets walked DOWN to clear red, leaving folders 0.25
darker than files. `--lightness` pins do not help: the resolver runs after
them and moves the role again. `coal-mine-canyon` hit all of this.

The way out is the rule's own chroma clause: a role under 60% of the status
colour's chroma is exempt, because a pale colour cannot masquerade as a
signal. Place those roles by CHROMA, at the lightness the file tree needs,
and hand-edit them into the file after the build:

```
accent_bright  L 0.820  C 0.045  hue 39   #ADDBE9   60% of pink is 0.045
accent_light   L 0.781  C 0.064  hue 38   #71CDDC
reserve_1      L 0.740  C 0.065  hue 38   #D09D8D   0.08 darker than files
```

Every one is a genuine sample (dE 0.011-0.025 from a real pixel) because
the rock's pale bands are exactly that: low-chroma rust. Verify each
candidate with `palette.status_collision(hex, role)` and `contrast(hex, bg)`
from a python one-liner rather than trusting the arithmetic; a grid over
L x C x hue takes seconds and shows the exact edge.

So the rule is: **saturated roles get distance from lightness, pastel roles
get it from chroma.** The goa-cove advice above is for the saturated ones.

### Look at it before you check it

`swatch.py` next to this file renders one or more `.colors` files as a
strip of 21 blocks, one row per file, so candidates can be compared side by
side without swapping any of them in:

```bash
python3 $S/swatch.py a.colors b.colors c.colors out.bmp
sips -s format png out.bmp --out out.png     # then Read out.png
```

It is pure stdlib (writes a BMP by hand, since there is no PIL). The
numbers decided between warm ground and cool ground for `coal-mine-canyon`
only after the strips showed the cool one reading as a stock teal theme.

### Mark it, or it will be regenerated

`tricolor.py` writes a header saying the file is hand-configured. Keep that
line. Running `palette.py build` over one of these silently replaces the whole
layout with the default two-axis seam.

## Step 3. The ladder, and the trap in it

Every palette reuses one lightness and chroma ladder, tuned so the text roles
clear 4.5:1. `build` reads it from a reference palette (`tea-terrace` by
default, because it is the deliberate narrow-band one) and remaps only the hue.

**The trap: holding lightness and chroma fixed while changing hue does NOT hold
contrast.** WCAG luminance is hue-dependent. The same OKLCH values that give
4.54:1 in blue give 4.24:1 in red. Swept across the wheel at `accent`'s
lightness and chroma, contrast ranges 4.24 to 4.62, straddling the 4.5 line.

`accent` is the only role close enough to the line to be affected, and it is the
load-bearing one - it paints the herdr accent, the wezterm split and active tab,
the starship success symbol, Claude's `claude` and `promptBorder`. Every other
role has margin.

`build` handles this: it raises lightness to whatever the new hue needs and
prints what it changed. If you are placing colors by hand instead, `accent` needs
L 0.632 to clear 4.5:1 at every hue; glacier's 0.615 only works because blue is
in the forgiving half of the wheel.

**All of these ratios are upper bounds.** wezterm renders at
`window_background_opacity = 0.8`, so the wallpaper blends in and the real
on-screen contrast is lower. 4.51:1 on paper is not safe. Look at it.

## Step 4. Write an honest header

`build` leaves a TODO in the header. Replace it. It must say which roles were
SAMPLED from the wallpaper and which were EXTRAPOLATED up the hue axis.

Check the wallpaper's lightness distribution before promising a text ramp.
`text_bright` needs lightness 0.967. The tea plantation photo's 95th percentile
was 0.629 and its maximum was 0.814, so `tea-terrace`'s entire text ramp is
invented, while its dark roles are real samples within dE 0.002 of pixels in the
image. `sample` prints this and warns when it applies.

This is the difference between "sampled from the wallpaper" being true and being
marketing. Measure it, do not assert it:

```bash
python3 $S/palette.py check <name> --image <wallpaper>
```

`sample` also prints a lightness summary, but treat it as a hint only: it is
computed before the palette exists and cannot know which pixel each role landed
nearest. `check --image` is the authority. The two can disagree - a snowfield is
near-grey, so it is invisible to the hue analysis while still being exactly what
`text_bright` samples from.

Also record the hue separations and which gaps you landed in.

## Step 5. Swap it in

```bash
~/setup/update_palette.sh <name>
```

It rewrites every hex in place across the four consuming files: `.wezterm.lua`,
`starship/.config/starship.toml`, `herdr/.config/herdr/config.toml`, and
`claude/.claude/themes/theme.json`. Only herdr needs an explicit reload, which
the script does. The others watch their own configs.

**Claude Code's shimmers are not palette values.** Each one is a lightened
variant of the color it animates, so a blind hex substitution leaves it pointing
at the old palette and the animation stops relating to what it animates.

`update_palette.sh` already handles this: after the substitution it runs
`palettes/recompute_shimmers.py`, which rewrites `claudeShimmer`,
`promptBorderShimmer`, `inactiveShimmer` and `permissionShimmer` from whatever
their bases currently hold. Hue is held, lightness is lifted by a per-key
amount, and chroma is scaled by a proportion rather than reduced by a fixed
amount, because subtracting a fixed amount from a low-chroma base leaves it grey
and the shimmer flashes instead of pulsing.

That script owns the shimmer numbers. Do not restate them here or recompute them
by hand; read it if you need them. `warningShimmer` and `autoAcceptShimmer` sit
on semantic bases and never move.

## Editing a palette that is already live

`update_palette.sh` only handles palette-to-palette swaps. It reads the OLD
palette's 21 hexes and substitutes each for the new one's, matching by exact
hex. So the moment you edit the `.colors` file of the palette that is currently
applied, the configs are holding hexes that exist in no file at all, and no
future swap can reach them. Those roles are stranded, silently: the swap
reports success and changes nothing for them.

This has happened three times in this repo. It is what left herdr's `accent`
showing a blue from a build that no longer existed, while every other consumer
had moved on.

**The rule: never edit the live palette's file without syncing.** Two ways:

```bash
# safest - swap away first, edit freely, swap back
~/setup/update_palette.sh some-other-palette
$EDITOR ~/setup/palettes/my-palette.colors
~/setup/update_palette.sh my-palette

# or edit in place, then propagate
$EDITOR ~/setup/palettes/my-palette.colors
python3 $S/palette.py sync --dry-run     # see what it will rewrite
python3 $S/palette.py sync
python3 ~/setup/palettes/recompute_shimmers.py \
        ~/setup/claude/.claude/themes/theme.json
herdr config check && herdr server reload-config
```

`sync` works by diffing the palette against `palettes/.applied.colors`, a
snapshot of the palette exactly as it was last written into the configs.
`update_palette.sh` writes that snapshot on every successful swap. If the
snapshot is missing or stale, `palette.py sync --adopt` records the current
palette as applied without touching any config - only use it when you know the
configs already match.

`palette.py check <name>` warns with **DRIFT** whenever `<name>` is the live
palette and its file no longer matches the snapshot. That warning is the signal
to run `sync`.

**Derived values are not roles and a swap cannot see them.** Claude Code's four
shimmers and its five message/panel background fills are computed from palette
roles rather than stored, so they stay behind on every swap. Both families live
in `palettes/recompute_shimmers.py`, which `update_palette.sh` runs for you -
never hand-edit them, or they will go stale again the next time.

## Gotchas

- **`update_palette.sh` pairs roles POSITIONALLY.** It reads both files with an
  `awk` field split that keeps only the value and drops the role name. Reordering a `.colors` file
  silently mismaps every color with no error. Keep the 21 roles in the canonical
  order; `check` warns if they drift. Matching by name would make this
  impossible, and that it does not is a known weakness, not a design choice.
- **`#000000` and `#FFFFFF` must never be role values.** Hex-keyed replacement
  is context-blind and will rewrite an identical color that means something
  else. It silently rewrote `.tmux.conf`'s message-style black once, which is
  why `tmux/` is now excluded from the swap. `check` fails on these.
- **`palettes/current_pallete.txt` must name a palette that actually has a
  `.colors` file.** If it does not, the swap reads zero old colors, trips the
  size-mismatch guard, and aborts leaving everything untouched. Check it before
  swapping; the failure message does not say this is the cause.
- **Work in OKLCH, never HSL.** HSL lightness is not perceptual, so even steps
  bunch at the light end and "same lightness across hues" is meaningless.
- **macOS `sed -i` needs an explicit empty suffix**: `sed -i ''`.
- **`/bin/bash` here is 3.2.57.** No associative arrays, no `mapfile`.
- **Configs mix hex case**: palette values uppercase, catppuccin and derived
  values lowercase. Substitute case-insensitively (`sed s///I`).
- **No PIL on this machine.** `sample` uses `sips` to downsample to BMP and
  parses the header itself. If sampling breaks, that is where to look.

## Reference

Existing palettes:

```
glacier-wave      hue 203.7 - 251.8   48 deg wide   min sep 24.0 (cursor to teal)     single
tea-terrace       hue 157.8 - 169.9   12 deg wide   min sep 12.8 (text_muted to teal) single
coal-mine-canyon  hue 30.9 - 43.0 + 220-225          min sep 28 (accent_vivid to red)  duo, dominant on accents
yosemite-from-above  hue 251-268 + 65-75             min sep 14 (text_muted to yellow, C 0.02)  near-grey, river as detail only
```

`yosemite-from-above` is the worked example for a near-white photograph: the
ground follows what the picture READS as, not where its dark pixels are. A
first cut put the dark river on the backgrounds (the only dark pixels, best
provenance) and through wezterm's 0.8 opacity over white the hue-70 brown
blended to khaki and read green. The rebuilt palette is the snow-shadow blue
at saturation 0.35 everywhere, with the river only on `text_muted`/`text_dim`.

`coal-mine-canyon` is the worked example for a duo where the dominant colour
takes the accents (Step 2a, "When the second colour must NOT be the accent")
and for the warm-family pastel trap ("Judge low-chroma roles by distance").

`tea-terrace` is narrow because it had to be: the green gap is 40 degrees, so a
band centered on its midpoint of 162.7 is the best available and 20 degrees is
the theoretical ceiling. `glacier-wave` is wide because it sits in the
122-degree blue gap and could afford to be.

The 21 roles, in canonical order:

```
bg  bg_surface  bg_raised  bg_selection
text_bright  text  text_secondary  text_muted  text_dim  text_hint
border  cursor  accent  accent_bright  accent_light  accent_soft  accent_vivid
reserve_1  reserve_2  reserve_3  reserve_4
```

### Which roles have hard consumers

Most roles are chrome and forgiving. These four are load-bearing, and a new
palette has to answer for them:

| Role | Consumed by | Why it constrains the palette |
|---|---|---|
| `accent_bright` | the entire nvim-tree: folder names, folder icon, file names, executables, special files, symlinks, open buffers | It paints most of a file tree, so it must be genuinely readable, not a decorative accent. It used to be the spare role; it is not spare any more. |
| `text_bright` | nvim-tree root path, wezterm `selection_fg`, `brights[8]`, starship error symbol | The brightest thing on screen. Keep it near L 0.96. |
| `text_dim` | nvim-tree folder arrows, claude `subtle`, wezterm `brights[1]` | The floor of the readable range. It replaced catppuccin `overlay0` precisely because 3.36:1 was too low, so do not let it slip back under 4.5:1. |
| `bg` | wezterm background, and claude `clawd_background` | It is a background everywhere except the Claude glyph, where it renders as the mascot's eyes. A `bg` that is not clearly darker than `accent_soft` makes those eyes vanish. |

### reserve_1 is no longer spare

It paints nvim's folder names and folder icon, one lightness step darker than
the files on `accent_bright` - 0.746 against 0.820, same hue. It was chosen over
`accent_soft`, which sits at nearly the same lightness but already paints
wezterm's `brights[5]` and Claude's `permission` and would have been overloaded.
`reserve_2..4` are still unrendered.

So a new palette has to give `reserve_1` a value that works as a folder colour,
not just an on-palette leftover. Three things must hold, and `build` gets them
right by default:

- **same hue family as `accent_bright`**, within about 25 degrees. It has to be a
  darker version of the file colour, not a different colour.
- **0.03 to 0.20 darker in lightness.** Below 0.03 the distinction is invisible;
  above 0.20 folders read as disabled rather than as folders.
- **at least 4.5:1 against `bg`**, like any other text role.

`tricolor.py` is where this goes wrong. If you park the reserves on a third
colour to record it - which Step 2b tells you to do - `reserve_1` lands on the
wrong axis and folders come out a different colour from files. goa-cove hit
exactly this: cyan folders against gold files, 146 degrees apart. The fix is
`--move reserve_1:accent`, which puts it back in the highlight family and leaves
`reserve_2..4` to carry the third colour.

### The gap table models status colors only

Step 1's gap table lists six hues, because those are the six `theme.json`
renders as status. nvim renders catppuccin's whole syntax palette, and eight
more hues live there:

```
maroon 8.8   flamingo 18.0   rosewater 30.5   peach 52.6
sky 210.3    sapphire 228.7  blue 259.9       lavender 277.3
```

Four of those sit inside what Step 1 calls the 122-degree blue gap, so that gap
is not actually empty - it is the emptiest place for *status*, which is a
different claim. With all fourteen in play the widest gap on the wheel is the
56-degree olive one between yellow and green, and nothing clears 30 degrees.

This is advisory, not a gate, and deliberately so. Measured against all
fourteen, every palette in this repo collides: glacier-wave's `cursor` is dE
0.011 from catppuccin `sky` and tea-terrace's is 0.032 from `teal`. Both look
fine, because a cursor is a block of color rather than text and nothing is lost
if it resembles a syntax color. A hard gate here would reject palettes that
demonstrably work.

Where it does matter is text-on-text adjacency, which is new: `accent_bright`
now paints a file tree sitting directly beside syntax-colored code. Judge that
role by perceptual distance rather than hue alone, since a shared hue is
harmless when lightness differs. For reference, all three palettes land between
dE 0.035 and 0.044 from their nearest catppuccin color on that role, which is
apparently the practical floor for a bright highlight - catppuccin's own bright
colors occupy the same region.

`accent_bright` deserves a second look during Step 1. nvim renders it beside
catppuccin's own syntax colors, so it is the role most exposed to a
hue-separation failure: if the palette sits near green or teal, the file tree is
where you will see it first.

Role names name a JOB, never an appearance. The moment a role is called `cyan`
or `deep_water`, only one palette can fill it. An author of a warm palette
cannot answer "what is your cyan?" but can always answer "what is your
background?"
