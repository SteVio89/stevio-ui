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

print("theme tests passed")
