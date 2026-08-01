local wezterm = require("wezterm")

local config = wezterm.config_builder()

-- "glacier": an icy blue scheme sampled from the desktop wallpaper (pale ice
-- highlights through to deep water shadow).
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
-- background, not this one. Measured against #0B222C, default blue (#5455cb) is
-- 2.77:1 and default red (#cc5555) is 3.91:1, both under the 4.5:1 readability
-- threshold; bright black (#555555, used for dim/hint text such as fish
-- autosuggestions) is 2.20:1. Directory names in `ls` are the most affected.
-- Fixing it properly means re-specifying all 16 with conventional hues but
-- glacier-tuned lightness, computed against the blended background that
-- transparency actually produces rather than against #0B222C.
config.color_schemes = {
	glacier = {
		foreground = "#CEE6EC", -- pale ice
		background = "#0B222C", -- deep water, nearly black
		cursor_bg = "#93DCE6",
		cursor_fg = "#0B222C",
		cursor_border = "#93DCE6",
		selection_bg = "#24576B",
		selection_fg = "#EDF6F8",
		scrollbar_thumb = "#24576B",
		split = "#3490B5",

		tab_bar = {
			background = "#0B222C",
			active_tab = { bg_color = "#3490B5", fg_color = "#EDF6F8" },
			inactive_tab = { bg_color = "#10303C", fg_color = "#71CDDC" },
			inactive_tab_hover = { bg_color = "#24576B", fg_color = "#CEE6EC" },
			new_tab = { bg_color = "#10303C", fg_color = "#71CDDC" },
			new_tab_hover = { bg_color = "#24576B", fg_color = "#CEE6EC" },
		},
	},
}
config.color_scheme = "glacier"
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
