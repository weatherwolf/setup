local wezterm = require("wezterm")

local config = wezterm.config_builder()

-- "glacier_wave": an icy blue scheme sampled from the desktop wallpaper (pale
-- ice highlights through to deep water shadow). Indexed, with every consumer
-- and every contrast ratio, in palettes/glacier-wave.md.
--
-- Only the non-ANSI slots are set below: default fg/bg, cursor, selection, the
-- split divider, the scrollbar thumb, and the tab bar. Those account for most
-- of the screen (background plus default-colored text), so the terminal still
-- reads as glacier even though the 16-color palette proper is untouched.
--
-- The 16 ANSI slots are deliberately NOT set, so they fall back to wezterm's
-- built-in defaults and keep their conventional hues: red stays red, green
-- stays green. An earlier version of this scheme mapped all 16 to shades of
-- blue, which left `git diff`, test pass/fail, and `ls` file types separated by
-- lightness alone -- and separated badly, since red and green landed on
-- adjacent rungs of the ladder at 1.185:1 contrast and 8 degrees of hue apart,
-- i.e. indistinguishable. Gauges with no text fallback (btop, disk usage bars)
-- lost their meaning entirely.
--
-- Known cost of the fallback: wezterm's defaults are tuned for a black
-- background, not this one. Measured against #1F1102, default blue (#5455cb) is
-- 2.77:1 and default red (#cc5555) is 3.91:1, both under the 4.5:1 readability
-- threshold; bright black (#555555, used for dim/hint text such as fish
-- autosuggestions) is 2.20:1. Directory names in `ls` are the most affected.
-- Fixing it properly means re-specifying all 16 with conventional hues but
-- glacier-tuned lightness, computed against the blended background that
-- transparency actually produces rather than against #1F1102.
config.color_schemes = {
	active = {
		foreground = "#EDDED2", -- pale ice
		background = "#1F1102", -- deep water, nearly black
		cursor_bg = "#C6D4AE",
		cursor_fg = "#1F1102",
		cursor_border = "#C6D4AE",
		selection_bg = "#5A3D1B",
		selection_fg = "#F8F3EF",
		scrollbar_thumb = "#5A3D1B",
		split = "#6F9062",

		-- Claude Code's dark-ansi base maps `permission` (inline code) to
		-- blueBright, which is brights[5]. Defining brights here is the only
		-- way to control that color: the custom-theme override never reaches
		-- the markdown renderer, which re-derives the built-in palette from
		-- the base name and drops the overrides. Values reuse hues already
		-- present in the glacier theme rather than introducing new ones.
		brights = {
			"#819171", -- bright black, theme subtle
			"#f38ba8", -- bright red, theme error
			"#a6e3a1", -- bright green, theme success
			"#f9e2af", -- bright yellow, theme warning
			"#99B392", -- bright blue, theme permission (inline code)
			"#cba6f7", -- bright magenta, theme autoAccept
			"#B5C799", -- bright cyan, theme suggestion
			"#F8F3EF", -- bright white, ice
		},

		tab_bar = {
			background = "#1F1102",
			-- fg is deep_water, not ice: #F8F3EF on this bg is only 3.30:1,
			-- under the 4.5:1 threshold and lower still once the wallpaper
			-- blends in. #1F1102 is 4.54:1. teal_deep sits mid-lightness, so
			-- readable text on it has to go dark rather than light.
			active_tab = { bg_color = "#6F9062", fg_color = "#1F1102" },
			inactive_tab = { bg_color = "#2F1C05", fg_color = "#B5C799" },
			inactive_tab_hover = { bg_color = "#5A3D1B", fg_color = "#EDDED2" },
			new_tab = { bg_color = "#2F1C05", fg_color = "#B5C799" },
			new_tab_hover = { bg_color = "#5A3D1B", fg_color = "#EDDED2" },
		},
	},
}
config.color_scheme = "active"
config.font = wezterm.font("Hack Nerd Font")
config.font_size = 15.0
config.window_background_opacity = 0.8
config.macos_window_background_blur = 50
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"

-- Fullscreen kills the blur, so prefer maximizing.
--
-- macos_window_background_blur does not blur the window; it makes macOS blur
-- whatever is BEHIND the window, seen through the 0.8 background opacity. A
-- fullscreen window has nothing behind it: macOS native fullscreen moves the
-- window to its own Space, where the desktop wallpaper is not composited, so
-- there is nothing left to sample and the transparency falls through to the
-- Space's flat black backdrop. Same reason applies to wezterm's own
-- (non-native) fullscreen, which covers the whole display.
--
-- CMD+CTRL+Enter therefore toggles maximize instead: the window fills the screen
-- but stays an ordinary window in the current Space, so the wallpaper stays
-- behind it and the blur survives. ALT+Enter still does real fullscreen when it
-- is wanted (accepting the loss of blur).
config.native_macos_fullscreen_mode = false

-- window:maximize()/restore() have no "is maximized" query, so track per window.
local maximized = {}

config.keys = {
	{
		key = "Enter",
		mods = "CMD|CTRL",
		action = wezterm.action_callback(function(window)
			local id = window:window_id()
			if maximized[id] then
				window:restore()
				maximized[id] = nil
			else
				window:maximize()
				maximized[id] = true
			end
		end),
	},
}

-- Dim unfocused windows so the focused one is obvious at a glance.
local UNFOCUSED_FOREGROUND_TEXT_HSB = { hue = 1.0, saturation = 0.25, brightness = 0.45 }
local UNFOCUSED_WINDOW_BACKGROUND_OPACITY = 0.62

-- get_config_overrides() hands back a copy, so the current value is never the
-- same table we last stored; compare the fields instead of the identity.
local function same_text_hsb(actual, expected)
	if actual == nil or expected == nil then
		return actual == expected
	end
	return actual.hue == expected.hue
		and actual.saturation == expected.saturation
		and actual.brightness == expected.brightness
end

wezterm.on("window-focus-changed", function(window)
	local overrides = window:get_config_overrides() or {}
	local text_hsb, opacity
	if not window:is_focused() then
		text_hsb = UNFOCUSED_FOREGROUND_TEXT_HSB
		opacity = UNFOCUSED_WINDOW_BACKGROUND_OPACITY
	end

	-- Only write when one of the two values we own actually changes; a redundant
	-- set_config_overrides() call would trigger another config reload.
	if same_text_hsb(overrides.foreground_text_hsb, text_hsb) and overrides.window_background_opacity == opacity then
		return
	end

	overrides.foreground_text_hsb = text_hsb
	overrides.window_background_opacity = opacity
	window:set_config_overrides(overrides)
end)

return config
