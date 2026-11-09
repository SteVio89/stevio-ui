-- Run with: lua tests/settings_pages_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")

local ns = { config = {} }
function ns.T(english, german)
	return ns.isGerman and german or english
end
loadAddonFile("Core/Layout.lua", ns)
loadAddonFile("Modules/Settings/Labels.lua", ns)
loadAddonFile("Modules/Settings/Pages.lua", ns)
local Pages = ns.ConfigPages

-- The page titles as they were spelled out before they came from Labels.lua.
local TITLES = {
	units = { "Unit frames", "Einheitenfenster" },
	group = { "Group grid", "Gruppenraster" },
	keyboardHealing = { "Keyboard healing", "Tastaturheilung" },
	actionbars = { "Action bars", "Aktionsleisten" },
	minimap = { "Minimap", "Minikarte" },
	tooltip = { "Tooltip", "Tooltip" },
	auras = { "Auras", "Auren" },
	tracker = { "Objective tracker", "Questverfolgung" },
	chat = { "Chat", "Chat" },
	lootTicker = { "Loot ticker", "Beuteticker" },
	notch = { "Notch", "Notch" },
	questRewards = { "Quest rewards", "Questbelohnungen" },
	accessibility = { "Quickjump", "Schnellsprung" },
	settings = { "Profile", "Profil" },
}

local count = 0
for _, module in ipairs(Pages.MODULES) do
	local expected = TITLES[module[1]]
	check(expected ~= nil, "unexpected module " .. module[1])
	ns.isGerman = false
	check(Pages.Title(module) == expected[1], "English title of " .. module[1])
	check(select("#", Pages.Title(module)) == 1, "a single title value for " .. module[1])
	ns.isGerman = true
	check(Pages.Title(module) == expected[2], "German title of " .. module[1])
	count = count + 1
end
check(count == 14, "all module pages")
print("module titles ok")

-- Every Layout.lua position is shown on exactly one module page.
local claims = {}
for _, module in ipairs(Pages.MODULES) do
	for _, key in ipairs(module.layout or {}) do
		check(ns.layout[key] ~= nil, "claimed position exists: " .. key)
		check(claims[key] == nil, key .. " claimed by " .. tostring(claims[key]) .. " and " .. module[1])
		claims[key] = module[1]
	end
end
for key in pairs(ns.layout) do
	check(claims[key] ~= nil, "position on no module page: " .. key)
end
check(#Pages.UnclaimedLayout(ns.layout) == 0, "nothing left for the General page")
local unclaimed = Pages.UnclaimedLayout({ chat = {}, zeta = {}, alpha = {} })
check(#unclaimed == 2 and unclaimed[1] == "alpha" and unclaimed[2] == "zeta", "unclaimed positions, sorted")
print("layout claims ok")

print("settings pages tests passed")
