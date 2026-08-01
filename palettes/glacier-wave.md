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
See `glacier-wave-rationale.txt` for the four options this was chosen from.

## Reading the contrast column

Ratios are WCAG 2.1, computed against the `#0B222C` background **at full
opacity**. Real rendering is lighter than that, in two different ways:

- Cells with no explicit background go through `window_background_opacity =
  0.8`, so 20% of what you see is blurred wallpaper, rising to 38% on unfocused
  windows.
- Cells that DO set a background - the `fill` rows below, nvim floats, visual
  selections, herdr chrome - go through `text_background_opacity = 0.9` instead,
  so 10% wallpaper.

Actual contrast is therefore **lower** than every number below, including the
text-on-fill pairs.

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
| `#ADDBE9` | accent_bright | 11.01:1 | yes | claude `promptBorder` only |
| `#93DCE6` | cyan_light | 10.65:1 | yes | wezterm `cursor_bg`, `cursor_border`; starship `directory`; herdr `overlay0` (commented) |
| `#71CDDC` | cyan | 8.96:1 | yes | wezterm `inactive_tab.fg`, `new_tab.fg`; herdr `mauve`; claude `suggestion`; starship `vicmd_symbol` |
| `#54BFC9` | cyan_deep | 7.56:1 | no | starship palette only, nothing renders it |
| `#2DBCD3` | wave | 7.23:1 | yes | claude `permission`, `clawd_body`, `briefLabelClaude` |
| `#8CA4BF` | grey_water | 6.39:1 | yes | claude `inactive` |
| `#41AECD` | azure | 6.38:1 | no | starship palette only, nothing renders it |
| `#5599D5` | azure_deep | 5.40:1 | no | starship palette only, nothing renders it |
| `#5E93A6` | steel | 4.85:1 | yes | claude `subtle` |
| `#3490B5` | teal_deep | 4.54:1 | yes | wezterm `split`, `active_tab.bg`; herdr `accent`; claude `claude`; starship `success_symbol` |
| `#24576B` | selection | 2.07:1 `fill` | yes | wezterm `selection_bg`, `scrollbar_thumb`, `*_hover.bg`; claude `selectionBg` |
| `#10303C` | surface | 1.18:1 `fill` | yes | wezterm `inactive_tab.bg`, `new_tab.bg` |
| `#0B222C` | deep_water | 1.00:1 `fill` | yes | wezterm `background`, `cursor_fg`, `tab_bar.background`; starship (defined, unused) |

`#ADDBE9` was herdr's accent historically. It still appears in exactly one
place, now the Claude Code `promptBorder` key. See Known issues.

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
| `#c6e6f0` | claudeShimmer | 12.49:1 | `#ADDBE9`, lightened |
| `#9cdce6` | inactiveShimmer | 10.78:1 | `#71CDDC`, lightened |
| `#dbc1f9` | autoAcceptShimmer | 10.17:1 | catppuccin mauve, lightened |
| `#4DDCE3` | permissionShimmer | 9.90:1 | `#2DBCD3`, lightened |
| `#71b1cb` | promptBorderShimmer | 6.92:1 | `#3490B5`, lightened |
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
| `#EDF6F8` on `#3490B5` active tab | 3.30:1 | **fails** |
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

**wezterm active tab, 3.30:1.** `#EDF6F8` on `#3490B5` is under the threshold,
and the real figure is lower once the wallpaper blends in. Either darken
`active_tab.bg` or drop the fg toward `#0B222C`, which is 4.54:1 on the same
background.

**herdr active tab title, 2.19:1.** `surface_dim` (`#24576B`) on `accent`
(`#3490B5`). The comment in `herdr/config.toml` claims 5.31:1, which was correct
when the accent was `#ADDBE9` (11.01/2.07 = 5.32) and was not updated when the
accent changed to `#3490B5`. The comment is stale; the color is genuinely
unreadable.

**`#ADDBE9` is nearly orphaned.** Still one consumer, but the swap moved it
from the Claude Code `claude` key to `promptBorder`. That relocated the color
rather than retiring it, so the question stands: it is either the accent this
palette should be using more widely, or it should be dropped for `#3490B5`.

**The Claude Code icon fell to 4.54:1.** The same swap put `claude` - the
six-pointed asterisk glyph, the `Claude Code` banner, the plugin marketplace
marks - onto
`#3490B5`, down from 11.01:1. That clears WCAG AA for normal text by 0.04, and
the real figure is lower once the wallpaper blends through
`window_background_opacity`. `#3490B5` is also `active_tab.bg`, already listed
above as failing, so the accent now carries both the least readable chrome and
a foreground glyph.

**`#2DBCD3` is a third family.** `clawd_body`, `briefLabelClaude` and
`permission` use a hex that is in neither the glacier ramp nor catppuccin
mocha - it comes from the rationale file's "full wave blue". It measures fine
at 7.23:1, but the two-families-not-one split at the top of this document no
longer describes every color in use. `permission` is the pointed case: it is a
state signal, which the split says catppuccin owns, and it moved to glacier.

**The two shimmer derivations are crossed.** `claudeShimmer` (`#c6e6f0`) is
still a lightened `#ADDBE9`, but `#ADDBE9` is now `promptBorder`, not `claude`.
`promptBorderShimmer` (`#71b1cb`) is a lightened `#3490B5`, which is now
`claude`. Each shimmer animates the other key's base color. Nothing renders
wrong, but the derived values no longer track what they animate.

---

Why this palette and not another: `glacier-wave-rationale.txt`.
