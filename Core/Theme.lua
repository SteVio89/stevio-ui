local _, ns = ...

-- The color theme: style.theme picks one of style.themes, whose colors land in
-- style.palette, the only place modules read theme colors from.

local style = ns.config.style

-- Fills `palette` (a new table if nil) with the colors of `style.theme`.
-- Unknown names (a typo in the options panel) fall back to themes.dusk; the
-- other theme is themes.violet. The table is filled in place, so code holding
-- on to it sees the colors chosen after the saved overrides load. Pure, tested
-- in tests/theme_test.lua.
function ns.ResolveTheme(styleConfig, palette)
	local theme = styleConfig.themes[styleConfig.theme] or styleConfig.themes.dusk
	palette = palette or {}
	for key in pairs(palette) do
		palette[key] = nil
	end
	for key, color in pairs(theme) do
		palette[key] = color
	end
	return palette
end

-- "|cffRRGGBB" for colored parts of a text, e.g. a muted separator.
function ns.Hex(color)
	local function Byte(value)
		return math.floor(value * 255 + 0.5)
	end
	return ("|cff%02x%02x%02x"):format(Byte(color[1]), Byte(color[2]), Byte(color[3]))
end

function ns.ApplyTheme()
	style.palette = ns.ResolveTheme(style, style.palette)
	style.backgroundColor = style.palette.panel
end

ns.ApplyTheme()

-- The options panel's overrides (Core/Overrides.lua, registered earlier, so it
-- runs first) may change the theme or its colors; modules read the palette
-- only once they are enabled at PLAYER_LOGIN.
if ns.RegisterEvent then
	local function OnAddonLoaded(_, loadedName)
		if loadedName == ns.name then
			ns.UnregisterEvent("ADDON_LOADED", OnAddonLoaded)
			ns.ApplyTheme()
		end
	end
	ns.RegisterEvent("ADDON_LOADED", OnAddonLoaded)
end
