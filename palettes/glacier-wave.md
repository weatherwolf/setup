# glacier-wave

The palette this environment renders in, and the index of every place a color
is written down. Read this instead of opening five config files.

**Maintained by hand.** Nothing generates these tables and nothing checks them.
If you change a color in any config listed in the Consumers column, update this
file in the same commit. Making that mechanical is
[issue #1](https://github.com/weatherwolf/setup/issues/1).

glacier-wave is deliberately **two families, not one**:

- **glacier** owns the chrome. Backgrounds, borders, cursors, tab bars,
  selection, the prompt. Icy blues sampled from the desktop wallpaper.
- **catppuccin mocha** owns meaning. Pass/fail, added/removed, warnings,
  syntax. Anything where the color IS the information.

That split is the whole design. Chrome can be monochrome because it carries no
information; meaning cannot, because hue is what makes it readable at a glance.
See "How this was chosen" at the bottom for the four options it was picked from.

## Reading the contrast column

Ratios are WCAG 2.1, computed against the `#0B222C` background **at full
opacity**. Real rendering is lighter than that, in two different ways:

- Cells with no explicit background go through `window_background_opacity =
  0.8`, so 20% of what you see is blurred wallpaper, rising to 38% on unfocused
  windows.
- Cells that DO set a background - the `fill` rows below, nvim floats, visual
  selections, herdr chrome - are fully opaque, because
  `window_background_opacity` only governs cells carrying no explicit
  background. Those render at exactly the hex below.

So the two halves of this document have different error bars. The text-on-fill
pairs are accurate as written. Everything measured against `#0B222C` is an
upper bound, and the real figure is lower by an amount that depends on the
wallpaper and on whether the window has focus.

**Treat these as upper bounds.** A value at 4.6:1 here is not guaranteed to
clear 4.5:1 on screen.

Rows marked `fill` are backgrounds, not text. Low contrast against the terminal
background is correct for them; what matters is the text drawn on top, which is
checked separately at the bottom.

## Glacier - chrome

| Hex | Name | Contrast | Live | Consumers |
|---|---|---|---|---|
| `#EDF6F8` | ice_bright | 14.96:1 | yes | wezterm `selection_fg`, `active_tab.fg`; starship `read_only_style`, `error_symbol` |
| `#CEE6EC` | ice | 12.63:1 | yes | wezterm `foreground`, `inactive_tab_hover.fg`, `new_tab_hover.fg`; claude `text`; starship (defined, unused) |
| `#ADDBE9` | accent_bright | 11.01:1 | yes | claude `promptBorder` |
| `#93DCE6` | cyan_light | 10.65:1 | yes | wezterm `cursor_bg`, `cursor_border`; starship `directory`; herdr `overlay0` (commented) |
| `#71CDDC` | cyan | 8.96:1 | yes | wezterm `inactive_tab.fg`, `new_tab.fg`; herdr `mauve`; claude `suggestion`; starship `vicmd_symbol` |
| `#54BFC9` | cyan_deep | 7.56:1 | no | starship palette only, nothing renders it |
| `#97B0C9` | muted_blue | 7.32:1 | yes | claude `permission` |
| `#2DBCD3` | wave | 7.23:1 | yes | claude `clawd_body`, `briefLabelClaude` |
| `#8CA4BF` | grey_water | 6.39:1 | yes | claude `inactive` |
| `#41AECD` | azure | 6.38:1 | no | starship palette only, nothing renders it |
| `#5599D5` | azure_deep | 5.40:1 | no | starship palette only, nothing renders it |
| `#5E93A6` | steel | 4.85:1 | yes | claude `subtle` |
| `#3490B5` | teal_deep | 4.54:1 | yes | wezterm `split`, `active_tab.bg`; herdr `accent`; claude `claude`; starship `success_symbol` |
| `#24576B` | selection | 2.07:1 `fill` | yes | wezterm `selection_bg`, `scrollbar_thumb`, `*_hover.bg`; claude `selectionBg` |
| `#10303C` | surface | 1.18:1 `fill` | yes | wezterm `inactive_tab.bg`, `new_tab.bg` |
| `#0B222C` | deep_water | 1.00:1 `fill` | yes | wezterm `background`, `cursor_fg`, `tab_bar.background`; starship (defined, unused) |

`#ADDBE9` was herdr's accent historically and is now the Claude Code
`promptBorder`. At 11.01:1 it is the brightest value in regular use, which is
why it sits on the border wrapping the prompt rather than on anything that
needs to recede.

## Glacier - greys

Neutrals on the same hue axis as the chrome ramp, so they belong to the family
instead of sitting next to it. Derived rather than sampled: hue 221.5 (the
chroma-weighted mean of the chrome ramp above), chroma held at 0.020, lightness
stepped in OKLab so the spacing is perceptually even rather than even in hex.

Chroma 0.020 is inside the range the palette already spans - `ice_bright` is
0.010 and `surface` is 0.043 - so these read as grey without reading as foreign.
A true neutral (chroma 0) would look dirty beside `#71CDDC`.

| Hex | Name | OKLab L | Contrast | Live | Intended role |
|---|---|---|---|---|---|
| `#A4B4BA` | mist | 0.759 | 7.67:1 | no | secondary text |
| `#88989E` | silt | 0.669 | 5.50:1 | no | dim text, comments, hints |
| `#57666B` | scree | 0.499 | 2.75:1 `fill` | no | borders, separators, inactive chrome |
| `#324045` | till | 0.361 | 1.53:1 `fill` | no | raised surface, a panel above the background |

Nothing consumes these yet. They are defined in `starship.toml` so the ramp is
carried somewhere machine-readable, and listed here as the menu.

Two of them fill genuine lightness gaps: `scree` sits in the empty stretch
between `selection` (L 0.431) and `teal_deep` (L 0.615), and `till` between
`surface` (L 0.291) and `selection`. The other two fill a *chroma* gap - above
L 0.61 every other color in this palette is saturated, so before these there was
no neutral text option at all.

`silt` is at L 0.67 rather than a tidier L 0.64 deliberately. L 0.64 gives
4.91:1, which clears the threshold on paper but not necessarily once the
wallpaper blends in; dim text is the role where that margin matters most.

These do not solve the two Known issues below. Text on the `#3490B5` accent
needs to be dark, not neutral: `mist` on accent is 1.69:1 and `till` on accent
is 2.97:1, while `deep_water` is 4.54:1.

## Catppuccin mocha - meaning

nvim renders catppuccin mocha unmodified (`flavour = "auto"` resolves to mocha
on a dark background), so it consumes this whole family for syntax and UI. The
Claude Code theme borrows the semantic subset. herdr uses catppuccin as its
theme base but overrides `mauve` to glacier cyan and clears the surfaces.

| Hex | Name | Contrast | Live | Consumers |
|---|---|---|---|---|
| `#f9e2af` | yellow | 12.92:1 | yes | claude `warning`; nvim |
| `#cdd6f4` | text | 11.35:1 | yes | nvim |
| `#a6e3a1` | green | 11.04:1 | yes | claude `success`, `diffAddedWord`; nvim |
| `#94e2d5` | teal | 11.02:1 | yes | claude `planMode`; nvim |
| `#f5c2e7` | pink | 10.75:1 | yes | claude `bashBorder`; nvim |
| `#fab387` | peach | 9.27:1 | yes | nvim |
| `#b4befe` | lavender | 9.17:1 | yes | nvim |
| `#cba6f7` | mauve | 8.08:1 | yes | nvim. herdr overrides its `mauve` token to `#71CDDC` |
| `#89b4fa` | blue | 7.79:1 | yes | nvim |
| `#a6adc8` | subtext0 | 7.37:1 | yes | nvim |
| `#f38ba8` | red | 7.09:1 | yes | claude `error`, `diffRemovedWord`; nvim |
| `#6c7086` | overlay0 | 3.36:1 LOW | yes | nvim dim/hint text |
| `#45475a` | surface1 | 1.80:1 `fill` | yes | nvim. herdr sets its `surface1` to `reset` |
| `#313244` | surface0 | 1.31:1 `fill` | yes | nvim. herdr sets its `surface0` to `reset` |
| `#1e1e2e` | base | 1.00:1 `fill` | no | catppuccin's own background, never painted: nvim runs `transparent_background = true` |

## Legacy

| Hex | Name | Contrast | Live | Consumers |
|---|---|---|---|---|
| `#00e68a` | tmux green | 9.92:1 | no | herdr `green`, commented out. The old tmux accent, kept as the record of what the theme replaced |
| `#FFFFFF` | white | 16.41:1 | no | herdr `overlay1`, commented out |

## Derived

Values that exist only in the Claude Code theme, computed from the two families
above rather than sampled. Shimmers are lightened variants of the color they
animate; the rest are fills.

| Hex | Key | Contrast | Derived from |
|---|---|---|---|
| `#fbebc7` | warningShimmer | 13.92:1 | catppuccin yellow, lightened |
| `#c6e6f0` | promptBorderShimmer | 12.49:1 | `#ADDBE9` +0.041 L |
| `#B4CDE9` | inactiveShimmer | 10.04:1 | `#8CA4BF` +0.129 L |
| `#dbc1f9` | autoAcceptShimmer | 10.17:1 | catppuccin mauve, lightened |
| `#B9CAD9` | permissionShimmer | 9.78:1 | `#97B0C9`, lightened |
| `#71b1cb` | claudeShimmer | 6.92:1 | `#3490B5` +0.112 L |
| `#3c5f48` | diffAddedDimmed | 2.28:1 `fill` | catppuccin green, darkened |
| `#6c3d4a` | diffRemovedDimmed | 1.88:1 `fill` | catppuccin red, darkened |
| `#1e3a2f` | diffAdded | 1.33:1 `fill` | catppuccin green, darkened |
| `#462730` | diffRemoved | 1.25:1 `fill` | catppuccin red, darkened |
| `#16303d` | userMessageBackgroundHover | 1.19:1 `fill` | glacier, above the background |
| `#132b36` | memoryBackgroundColor | 1.11:1 `fill` | glacier, above the background |
| `#16262f` | bashMessageBackgroundColor | 1.06:1 `fill` | glacier, above the background |
| `#132631` | userMessageBackground | 1.05:1 `fill` | glacier, above the background |
| `#0f2630` | composerSidebarBackground | 1.05:1 `fill` | glacier, just above the background |

## Text drawn on fills

The check the fill rows above do not answer.

| Pair | Ratio | |
|---|---|---|
| `#CEE6EC` on `#132631` userMessageBackground | 11.97:1 | ok |
| `#CEE6EC` on `#462730` diffRemoved | 10.14:1 | ok |
| `#CEE6EC` on `#1e3a2f` diffAdded | 9.49:1 | ok |
| `#71CDDC` on `#10303C` inactive tab | 7.59:1 | ok |
| `#EDF6F8` on `#24576B` selection | 7.22:1 | ok |
| `#CEE6EC` on `#24576B` tab hover | 6.09:1 | ok |
| `#0B222C` on `#3490B5` wezterm active tab | 4.54:1 | ok |
| `#24576B` on `#3490B5` herdr active tab title | 2.19:1 | **fails** |

## Where each config reads from

| Config | Palette name | Reads |
|---|---|---|
| `.wezterm.lua` | `glacier_wave` | glacier only. The 16 ANSI slots are deliberately NOT set |
| `starship/.config/starship.toml` | `glacier_wave` | glacier only, 13 entries defined and 4 rendered. Carries the greys so the full ramp exists in a config, not just in this doc |
| `herdr/.config/herdr/config.toml` | (none; `catppuccin` base) | catppuccin base, glacier overrides, surfaces cleared to `reset` |
| `claude/.claude/themes/glacier_wave.json` | `glacier_wave` | both families plus the derived values |
| `nvim/.config/nvim/init.lua` | (none; catppuccin mocha) | catppuccin only. Paints no background |

Nothing in this repo reads this file. Each config holds its own literal hex.

## Constraints

**Never map the 16 ANSI slots to glacier.** This was tried and reverted. Every
slot became a shade of blue, which left `git diff`, test pass/fail and `ls` file
types separated by lightness alone - and separated badly: red and green landed
on adjacent rungs at 1.185:1 contrast, 8 degrees of hue apart. Gauges with no
text fallback (btop, disk bars) lost their meaning entirely. wezterm's defaults
are kept instead, so red stays red and green stays green.

The known cost: those defaults are tuned for a black background. Against
`#0B222C`, default blue is 2.77:1 and default red is 3.91:1, both under 4.5:1;
bright black (dim text, shell autosuggestions) is 2.20:1. Directory names in
`ls` are the most affected. Fixing it properly means respecifying all 16 with
conventional hues but glacier-tuned lightness, computed against the blended
background rather than against `#0B222C`.

**Transparency is owned by the terminal.** wezterm sets the opacity and the
macOS blur; every tool inside it paints as little background as possible so the
wallpaper shows through. herdr sets `panel_bg` and the `surface*` family to
`reset`; nvim sets `transparent_background = true`. Do not give any of them a
solid background.

**`surface_dim` in herdr must stay a real color.** `panel_contrast_fg` falls
back to it when `panel_bg` is `Reset` (`ui/widgets.rs:32`), so clearing both
makes the active tab title fall through to the terminal foreground and land at
1.15:1 on the accent.

## Known issues

**`#3490B5` is carrying a lot at 4.54:1.** The wezterm split and active tab
background, the herdr accent, the starship success symbol, and Claude Code's
`claude`. 4.54:1 is nominal; the real figure is lower wherever it renders as
text on the terminal background.

**herdr active tab title, 2.19:1.** `surface_dim` (`#24576B`) on `accent`
(`#3490B5`). The comment in `herdr/config.toml` claims 5.31:1, which was correct
when the accent was `#ADDBE9` (11.01/2.07 = 5.32) and was not updated when the
accent changed to `#3490B5`. The comment is stale; the color is genuinely
unreadable. Tracked as
[issue #2](https://github.com/weatherwolf/setup/issues/2), which lays out why
`surface_dim` cannot simply be darkened.


**The Claude Code icon fell to 4.54:1.** The same swap put `claude` - the
six-pointed asterisk glyph, the `Claude Code` banner, the plugin marketplace
marks - onto
`#3490B5`, down from 11.01:1. That clears WCAG AA for normal text by 0.04, and
the real figure is lower once the wallpaper blends through
`window_background_opacity`. `#3490B5` is also `active_tab.bg`, already listed
above as failing, so the accent now carries both the least readable chrome and
a foreground glyph.

**There is a third family, at hue 248-251.** `#97B0C9`, `#8CA4BF`, `#355675`
and `#2DBCD3` are in neither the glacier ramp nor catppuccin mocha, and the
first three sit past the chrome ramp's upper hue bound of 247.1, leaning violet
relative to everything else.

This is less arbitrary than it looks. A k-means pass over the wallpaper in
OKLab finds its muted blues cluster at exactly 248-250, distinct from the
saturated cyans at 221 - so the palette has always had two blue axes and only
one of them was written down. `#97B0C9` was sampled from that cluster, which is
16.3% of the image.

What remains true is that the two-families-not-one split at the top of this
document no longer describes every color in use. `permission` is the pointed
case: it is a state signal, which the split says catppuccin owns, and it sits
on a sampled blue instead. That is defensible for this key - Claude Code's own
dark default for it is `#B1B9F9`, a blue, and `#97B0C9` is the closest sample
in the wallpaper to it at dE 0.079 - but it is a deviation and should be a
deliberate one.

`#355675` is still unconsumed, and at dE 0.026 from `selection` it is close
enough to be hard to tell apart in place.

Every base/shimmer pair in the theme now lightens its own base, with under 4
degrees of hue drift. The lift per key follows what Claude Code's own dark
defaults do for that key rather than one global rule: they range from +0.024
lightness on `warning` to +0.129 on `inactive`, because an already-light base
needs less lift than a mid one to read as the same color brightening.

## How this was chosen

Condensed from the design document this replaces. Four anchors were considered.

**A. herdr's model: glacier chrome plus catppuccin semantics.** Chosen.
Glacier owns the chrome, catppuccin owns meaning. Matches herdr, the tool most
structurally similar to Claude Code, and keeps hue separation on everything
that carries information. Against it: a hybrid matches nothing 1:1, and two
palette families coexist in one file.

**B. Pure glacier.** Rejected. Total visual unity, one rule to state - but
success, warning and error would then differ by lightness alone. This is
exactly the configuration tried and reverted at the ANSI level, for exactly the
same reason.

**C. Pure catppuccin mocha.** Rejected. Claude Code and nvim become
indistinguishable, which is the simplest rule to maintain, but it drops the
glacier tie entirely: the wezterm frame would no longer match anything inside
it, and herdr would be the only tool still carrying the accent.

**D. Glacier chrome, stock Claude semantics.** Rejected. Smallest diff, fewest
keys, and the semantics track whatever Anthropic tunes them to - but Claude's
stock red and green differ noticeably from catppuccin's, so diffs in Claude
Code and diffs in nvim would not match. With diffview.nvim in regular use, that
is a real cost.

Three problems the document raised have since been resolved:

- **Opaque fills.** Claude Code has no `reset`/transparent equivalent to
  herdr's, so its background keys would punch opaque rectangles through the
  blur. Resolved as tint-not-panel: the five background values in Derived are
  pulled close to `#0B222C` so they read as a lift rather than a slab.
- **Collisions.** `planMode` shared a value with `suggestion`, and `bashBorder`
  with `permission`. Both pairs appear on screen simultaneously, so both were
  split.
- **`subtle` at 3.36:1.** It sat on catppuccin `overlay0`, which was picked
  against catppuccin's lighter `base` rather than against `#0B222C`. It is now
  glacier `steel` at 4.85:1.

The last of those is only resolved for Claude Code. nvim still renders dim text
in `overlay0`; the derived grey `silt` (`#88989E`, 5.50:1, hue 222) is the
on-palette replacement if that is ever overridden.

How custom Claude Code themes resolve, verified against the 2.1.220 binary: the
themes directory is scanned at startup, the slug is the **filename** rather than
the `name` field, `base` picks which built-in palette unlisted keys inherit
from, and a partial file is legal and usually looks better than overriding
everything. The directory is file-watched with a 300ms debounce, so edits
hot-reload; changing the setting in `settings.json` still needs a restart.
