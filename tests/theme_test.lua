-- Run with: lua tests/theme_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")

_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
local ns = { config = {} }
loadAddonFile("Core/Config.lua", ns)
loadAddonFile("Core/Theme.lua", ns)
local style = ns.config.style

-- Loading resolves the default theme right away.
check(style.theme == "dusk", "dusk is the default")
check(style.palette.accent == style.themes.dusk.accent, "palette holds the dusk colors")
check(style.backgroundColor == style.themes.dusk.panel, "background is the panel color")

-- Both themes define the same colors.
for key in pairs(style.themes.dusk) do
	check(style.themes.violet[key] ~= nil, "violet defines " .. key)
end
for key in pairs(style.themes.violet) do
	check(style.themes.dusk[key] ~= nil, "dusk defines " .. key)
end
print("themes ok")

-- ResolveTheme picks the named theme and fills the table in place.
local palette = style.palette
style.theme = "violet"
ns.ApplyTheme()
check(style.palette == palette, "same table after a change")
check(palette.accent == style.themes.violet.accent, "violet accent")
check(style.backgroundColor == style.themes.violet.panel, "violet background")

-- Unknown names fall back to dusk; keys of the old theme don't linger.
local themes = {
	dusk = { accent = 1 },
	other = { accent = 2, extra = 3 },
}
local resolved = ns.ResolveTheme({ theme = "other", themes = themes })
check(resolved.accent == 2 and resolved.extra == 3, "named theme")
ns.ResolveTheme({ theme = "typo", themes = themes }, resolved)
check(resolved.accent == 1, "unknown theme falls back to dusk")
check(resolved.extra == nil, "old keys are cleared")
print("resolve ok")

-- Hex: color codes for text, rounded to the nearest byte.
check(ns.Hex({ 1, 0, 0 }) == "|cffff0000", "red")
check(ns.Hex({ 0.54, 0.56, 0.60, 0.5 }) == "|cff8a8f99", "muted, alpha ignored")
print("hex ok")

-- Luminance: dark names go on priest, rogue and hunter (above 0.5), not on
-- the other class colors.
local CLASS_COLORS = {
	PRIEST = { 1, 1, 1 },
	ROGUE = { 1, 0.96, 0.41 },
	HUNTER = { 0.67, 0.83, 0.45 },
	MAGE = { 0.25, 0.78, 0.92 },
	DRUID = { 1, 0.49, 0.04 },
	PALADIN = { 0.96, 0.55, 0.73 },
	WARRIOR = { 0.78, 0.61, 0.43 },
	WARLOCK = { 0.53, 0.53, 0.93 },
	SHAMAN = { 0, 0.44, 0.87 },
}
local BRIGHT = { PRIEST = true, ROGUE = true, HUNTER = true }
for class, color in pairs(CLASS_COLORS) do
	local bright = ns.Luminance(color[1], color[2], color[3]) > 0.5
	check(bright == (BRIGHT[class] or false), "luminance of " .. class)
end
check(ns.Luminance(0, 0, 0) == 0, "black")
check(math.abs(ns.Luminance(1, 1, 1) - 1) < 1e-9, "white")
print("luminance ok")

print("theme tests passed")
