# glacier-wave

Source of truth for every color in this environment: what it is, and where it
is written down. Read this instead of opening five config files.

**Maintained by hand.** Nothing generates these tables and nothing checks them.
If you change a color in a config listed under Consumers, update this file in
the same commit. Making that mechanical is
[issue #1](https://github.com/weatherwolf/setup/issues/1).

Two families, not one:

- **glacier** owns the chrome - backgrounds, borders, cursors, tab bars,
  selection, the prompt. Icy blues sampled from the desktop wallpaper.
- **catppuccin mocha** owns meaning - pass/fail, added/removed, warnings,
  syntax. Anything where the color IS the information.

Chrome can be monochrome because it carries no information; meaning cannot,
because hue is what makes it readable at a glance.

**Contrast** is WCAG 2.1 against `#0B222C` at full opacity. Cells with no
explicit background render through `window_background_opacity = 0.8`, so the
real ratio is lower - treat these as upper bounds. Rows marked `fill` are
backgrounds, not text; what matters for them is the text drawn on top, checked
at the bottom.

## Glacier - chrome

| Hex | Name | Contrast | Live | Consumers |
|---|---|---|---|---|
| `#EDF6F8` | ice_bright | 14.96:1 | yes | wezterm `selection_fg`, `brights[8]`; starship `read_only_style`, `error_symbol`; nvim `NvimTreeRootFolder` |
| `#CEE6EC` | ice | 12.63:1 | yes | wezterm `foreground`, tab hover fg; claude `text`; starship (defined, unused) |
| `#ADDBE9` | accent_bright | 11.01:1 | yes | nvim `NvimTreeFolderName`, `NvimTreeFolderIcon` and the opened/empty/symlink variants |
| `#93DCE6` | cyan_light | 10.65:1 | yes | wezterm `cursor_bg`, `cursor_border`; herdr `mauve`; starship `directory` |
| `#71CDDC` | cyan | 8.96:1 | yes | wezterm `inactive_tab.fg`, `new_tab.fg`, `brights[7]`; claude `suggestion`; starship `vicmd_symbol` |
| `#54BFC9` | cyan_deep | 7.56:1 | no | starship palette only |
| `#2DBCD3` | wave | 7.23:1 | yes | claude `clawd_body`, `briefLabelClaude` |
| `#8FADCF` | muted_blue | 7.07:1 | yes | claude `permission`; wezterm `brights[5]`, which paints markdown inline code |
| `#8CA4BF` | grey_water | 6.39:1 | yes | claude `inactive` |
| `#41AECD` | azure | 6.38:1 | no | starship palette only |
| `#5599D5` | azure_deep | 5.40:1 | no | starship palette only |
| `#5E93A6` | steel | 4.85:1 | yes | claude `subtle`; wezterm `brights[1]` (bright black); nvim folder arrows |
| `#3490B5` | teal_deep | 4.54:1 | yes | wezterm `split`, `active_tab.bg`; herdr `accent`; claude `claude` and `promptBorder`; starship `success_symbol` |
| `#24576B` | selection | 2.07:1 `fill` | yes | wezterm `selection_bg`, `scrollbar_thumb`, `*_hover.bg`; claude `selectionBg` |
| `#10303C` | surface | 1.18:1 `fill` | yes | wezterm `inactive_tab.bg`, `new_tab.bg` |
| `#0B222C` | deep_water | 1.00:1 `fill` | yes | wezterm `background`, `cursor_fg`, `tab_bar.background`, `active_tab.fg` |

## Glacier - greys

Neutrals derived on the chrome ramp's own hue axis (221.5) at chroma 0.020, so
they read as grey without reading as foreign. Defined in `starship.toml` so the
ramp lives somewhere machine-readable; nothing renders them yet.

| Hex | Name | OKLab L | Contrast | Live | Intended role |
|---|---|---|---|---|---|
| `#A4B4BA` | mist | 0.759 | 7.67:1 | no | secondary text |
| `#88989E` | silt | 0.669 | 5.50:1 | no | dim text, comments, hints |
| `#57666B` | scree | 0.499 | 2.75:1 `fill` | no | borders, separators, inactive chrome |
| `#324045` | till | 0.361 | 1.53:1 `fill` | no | raised surface, a panel above the background |

## Catppuccin mocha - meaning

nvim renders mocha unmodified, so it consumes this whole family for syntax and
UI. The Claude Code theme borrows the semantic subset. herdr uses catppuccin as
its theme base but overrides `mauve` and clears the surfaces.

| Hex | Name | Contrast | Live | Consumers |
|---|---|---|---|---|
| `#f9e2af` | yellow | 12.92:1 | yes | claude `warning`; nvim; wezterm `brights[4]` |
| `#cdd6f4` | text | 11.35:1 | yes | nvim |
| `#a6e3a1` | green | 11.04:1 | yes | claude `success`, `diffAddedWord`; nvim; wezterm `brights[3]` |
| `#94e2d5` | teal | 11.02:1 | yes | claude `planMode`; nvim |
| `#f5c2e7` | pink | 10.75:1 | yes | claude `bashBorder`; nvim |
| `#fab387` | peach | 9.27:1 | yes | nvim |
| `#b4befe` | lavender | 9.17:1 | yes | nvim |
| `#cba6f7` | mauve | 8.08:1 | yes | nvim; claude `autoAccept`; wezterm `brights[6]`. herdr overrides its own `mauve` to `#93DCE6` |
| `#89b4fa` | blue | 7.79:1 | yes | nvim |
| `#a6adc8` | subtext0 | 7.37:1 | yes | nvim |
| `#f38ba8` | red | 7.09:1 | yes | claude `error`, `diffRemovedWord`; nvim; wezterm `brights[2]` |
| `#6c7086` | overlay0 | 3.36:1 LOW | yes | nvim dim/hint text |
| `#45475a` | surface1 | 1.80:1 `fill` | yes | nvim. herdr sets its `surface1` to `reset` |
| `#313244` | surface0 | 1.31:1 `fill` | yes | nvim. herdr sets its `surface0` to `reset` |
| `#1e1e2e` | base | 1.00:1 `fill` | no | catppuccin's background, never painted: nvim is `transparent_background` |

## Derived

Claude Code only, computed from the two families above. Shimmers are lightened
variants of the color they animate; the rest are fills, pulled close to
`#0B222C` so they read as a tint rather than an opaque slab over the wallpaper.

| Hex | Key | Contrast | Derived from |
|---|---|---|---|
| `#fbebc7` | warningShimmer | 13.92:1 | catppuccin yellow, lightened |
| `#c6e6f0` | claudeShimmer | 12.49:1 | `#ADDBE9` +0.041 L - **crossed**, see Known issues |
| `#dbc1f9` | autoAcceptShimmer | 10.17:1 | catppuccin mauve, lightened |
| `#B4CDE9` | inactiveShimmer | 10.04:1 | `#8CA4BF` +0.129 L |
| `#B4C6DC` | permissionShimmer | 9.42:1 | `#8FADCF` +0.084 L, chroma x0.61 |
| `#71b1cb` | promptBorderShimmer | 6.92:1 | `#3490B5` +0.112 L |
| `#3c5f48` | diffAddedDimmed | 2.28:1 `fill` | catppuccin green, darkened |
| `#6c3d4a` | diffRemovedDimmed | 1.88:1 `fill` | catppuccin red, darkened |
| `#1e3a2f` | diffAdded | 1.33:1 `fill` | catppuccin green, darkened |
| `#462730` | diffRemoved | 1.25:1 `fill` | catppuccin red, darkened |
| `#16303d` | userMessageBackgroundHover | 1.19:1 `fill` | glacier, above the background |
| `#132b36` | memoryBackgroundColor | 1.11:1 `fill` | glacier, above the background |
| `#16262f` | bashMessageBackgroundColor | 1.06:1 `fill` | glacier, above the background |
| `#132631` | userMessageBackground | 1.05:1 `fill` | glacier, above the background |
| `#0f2630` | composerSidebarBackground | 1.05:1 `fill` | glacier, just above the background |

## Legacy

Unused, kept as the record of what the theme replaced (the old tmux colors).

| Hex | Name | Contrast | Consumers |
|---|---|---|---|
| `#FFFFFF` | white | 16.41:1 | herdr `overlay1`, commented out |
| `#00e68a` | tmux green | 9.92:1 | herdr `green`, commented out |
| `#8B949E` | tmux fg | 5.34:1 | named in the herdr header comment only |
| `#30363D` | tmux border | 1.34:1 `fill` | same comment |
| `#13161D` | tmux bg | 1.10:1 `fill` | same comment. Opaque, which is why `panel_bg` is `reset` now |

## Text drawn on fills

The check the `fill` rows do not answer.

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

Nothing reads this file. Each config holds its own literal hex.

| Config | Palette name | Reads |
|---|---|---|
| `.wezterm.lua` | `active` | glacier for the chrome, plus all 8 `brights`. The 8 normal ANSI slots are deliberately unset. Owns the transparency (`window_background_opacity = 0.8`, `macos_window_background_blur = 50`) and is the only config that paints a background |
| `starship/.config/starship.toml` | `active` | glacier only: 13 entries defined, 4 rendered. Carries the greys so the full ramp exists in a config |
| `herdr/.config/herdr/config.toml` | (none; `catppuccin` base) | catppuccin base; overrides `accent` `#3490B5` and `mauve` `#93DCE6`; `panel_bg` and the `surface*` family cleared to `reset` |
| `claude/.claude/themes/theme.json` | `theme` | both families plus Derived, for 34 of 72 keys. `base: dark-ansi` sends the other 39 to the terminal's 16 slots |
| `nvim/.config/nvim/init.lua` | (none; catppuccin mocha) | catppuccin for syntax and UI, `transparent_background = true`. Sets glacier hex in `custom_highlights` for the nvim-tree folder groups only |

### ANSI brights (wezterm)

| Slot | Hex | Contrast | Borrowed from |
|---|---|---|---|
| `brights[8]` white | `#EDF6F8` | 14.96:1 | glacier `ice_bright` |
| `brights[4]` yellow | `#f9e2af` | 12.92:1 | theme `warning` |
| `brights[3]` green | `#a6e3a1` | 11.04:1 | theme `success` |
| `brights[7]` cyan | `#71CDDC` | 8.96:1 | theme `suggestion` |
| `brights[6]` magenta | `#cba6f7` | 8.08:1 | theme `autoAccept` |
| `brights[2]` red | `#f38ba8` | 7.09:1 | theme `error` |
| `brights[5]` blue | `#8FADCF` | 7.07:1 | theme `permission`, and markdown inline code |
| `brights[1]` black | `#5E93A6` | 4.85:1 | glacier `steel` |

## Palette geometry

Every glacier value in OKLCH - the numbers to work from when adding or
adjusting a color, because hex tells you nothing about how two colors relate.
Chroma-weighted mean hue is 221.5; chroma ranges 0.010 to 0.118.

| Hex | Name | L | Chroma | Hue |
|---|---|---|---|---|
| `#EDF6F8` | ice_bright | 0.967 | 0.010 | 212.5 |
| `#CEE6EC` | ice | 0.909 | 0.027 | 214.4 |
| `#ADDBE9` | accent_bright | 0.864 | 0.052 | 218.3 |
| `#93DCE6` | cyan_light | 0.850 | 0.074 | 206.7 |
| `#71CDDC` | cyan | 0.797 | 0.090 | 209.2 |
| `#54BFC9` | cyan_deep | 0.746 | 0.098 | 203.7 |
| `#8FADCF` | muted_blue | 0.737 | 0.060 | 251.8 |
| `#2DBCD3` | wave | 0.733 | 0.118 | 211.3 |
| `#8CA4BF` | grey_water | 0.710 | 0.048 | 251.5 |
| `#41AECD` | azure | 0.702 | 0.107 | 220.3 |
| `#5599D5` | azure_deep | 0.664 | 0.113 | 247.1 |
| `#5E93A6` | steel | 0.633 | 0.063 | 222.7 |
| `#3490B5` | teal_deep | 0.615 | 0.101 | 228.7 |
| `#355675` | dark_gray | 0.442 | 0.064 | 248.0 |
| `#24576B` | selection | 0.431 | 0.063 | 226.9 |
| `#10303C` | surface | 0.291 | 0.043 | 225.9 |
| `#0B222C` | deep_water | 0.239 | 0.035 | 229.1 |

The wallpaper has **two blue axes**: the cyan axis at hue 204-230, high chroma
(the lit ice, where the chrome ramp was sampled), and a muted-blue axis at hue
248-252, low chroma (atmosphere and shadow: `#8FADCF`, `#8CA4BF`, `#355675`).
They are coupled in the source - saturated areas of the photo are cyan, blue
areas are desaturated - so there is no saturated blue at hue 250 to be had.

## Constraints

- **Never flatten the ANSI slots onto one hue.** Tried and reverted: `git
  diff`, test pass/fail and `ls` types ended up separated by lightness alone,
  and gauges with no text fallback (btop, disk bars) lost their meaning. The
  rule is about hue, not about whether the slots are set - the brights are set,
  and each still reads as the color its name promises.
- **Transparency is owned by the terminal.** wezterm sets opacity and blur;
  every tool inside paints as little background as possible. Do not give herdr
  or nvim a solid background.
- **`surface_dim` in herdr must stay a real color.** `panel_contrast_fg` falls
  back to it when `panel_bg` is `Reset` (`ui/widgets.rs:32`), so clearing both
  drops the active tab title to the terminal foreground at 1.15:1 on the accent.
- **Claude Code theme gotchas.** The slug is the filename, not the `name`
  field. Do not edit via `/theme` - it would replace the symlink. Duplicate
  keys, unknown keys and malformed values are all silently dropped.
  `base: dark-ansi` is load-bearing: markdown inline code resolves `permission`
  from the *base* palette, never the override, so only under `dark-ansi` can
  wezterm's `brights[5]` reach it.
- **Shimmers lighten their own base**, by the amount Claude Code's own dark
  theme uses for that key (+0.024 L on `warning` to +0.129 on `inactive`), with
  chroma scaled proportionally rather than subtracted absolutely.

## Known issues

- **`claude` and `promptBorder` are both `#3490B5`.** They draw adjacent, so
  they are indistinguishable. `#ADDBE9` held `promptBorder` before and would
  restore the separation at 11.01:1, but it is no longer free - it now paints
  nvim's folder names. The two never share a surface, so it can serve both.
- **`claudeShimmer` is crossed.** `#c6e6f0` is a lightened `#ADDBE9` but
  `claude` is `#3490B5`, a +0.290 L jump that flashes rather than pulses.
  `#71b1cb` (currently `promptBorderShimmer`) is the correct value; swapped.
- **`#3490B5` is carrying a lot at 4.54:1** - wezterm split and active tab,
  herdr accent, starship success symbol, claude `claude` and `promptBorder`.
- **herdr active tab title fails, and every alternative is also wrong.** Only
  `deep_water` clears 4.5:1 as a title, and it is invisible as a separator. One
  token fills three roles with opposite lightness requirements:
  [issue #2](https://github.com/weatherwolf/setup/issues/2).
- **`permission` is a state signal on a sampled blue**, which the two-families
  split says catppuccin should own. Deliberate (Claude Code's own default for
  it is a blue) but a deviation.
- **`#355675` is unconsumed** and at dE 0.026 from `selection` is hard to tell
  apart in place.

## Method

- **Contrast**: WCAG 2.1 relative luminance, `(lighter + 0.05) / (darker + 0.05)`.
- **Perceptual work in OKLab / OKLCH**, never HSL. dE is Euclidean distance in
  OKLab; under about 0.03 is hard to tell apart in place.
- **Sampling**: downsample, convert to OKLCH, filter to the target band,
  k-means in OKLab, then snap each centroid to a color the image contains.
- **Judging a candidate** means looking at it in the terminal:

```sh
python3 palettes/preview.py                       # the current candidates
python3 palettes/preview.py '#8FADCF' '#81ADC9'   # arbitrary hexes
```

- **Reading a Claude Code default**:

```sh
strings -a ~/.local/share/claude/versions/<v> | grep -oE '<key>:"rgb\([0-9,]+\)"'
```
