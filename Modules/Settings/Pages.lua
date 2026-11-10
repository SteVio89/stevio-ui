local _, ns = ...

-- The module pages of the options panel (Panel.lua). Kept free of WoW API
-- calls so it can be tested outside the game.

local Pages = {}
ns.ConfigPages = Pages

-- Module pages in sidebar order: config key and the Layout.lua positions the
-- module places, shown on its page below its options. The title is the
-- module's config label (Labels.lua) unless `title` names one.
Pages.MODULES = {
	{ "units", layout = { "player", "target", "focus", "targetAuras" } },
	-- Labels.group is "Group", which is too vague for a page of its own.
	{ "group", title = { "Group grid", "Gruppenraster" }, layout = { "group" } },
	{ "keyboardHealing" },
	{ "actionBars", layout = { "actionBars", "actionSets", "stanceBar", "petBar", "menubar", "bags" } },
	{ "minimap", layout = { "minimap" } },
	{ "tooltip" },
	{ "auras", layout = { "buffs", "debuffs" } },
	{ "tracker", layout = { "tracker", "trackerBadge" } },
	{ "chat", layout = { "chat", "chatBadge" } },
	{ "lootTicker", layout = { "lootTicker" } },
	{ "notch" },
	{ "questRewards" },
	{ "accessibility" },
	{ "settings" },
}

function Pages.Title(module)
	if module.title then
		return ns.T(module.title[1], module.title[2])
	end
	return (ns.ConfigLabel(module[1]))
end

-- Layout.lua positions no module page shows; they stay on the General page.
-- A safety net for future layout keys: today every position has a page.
function Pages.UnclaimedLayout(layout)
	local claimed = {}
	for _, module in ipairs(Pages.MODULES) do
		for _, key in ipairs(module.layout or {}) do
			claimed[key] = true
		end
	end
	local keys = {}
	for key in pairs(layout) do
		if not claimed[key] then
			keys[#keys + 1] = key
		end
	end
	table.sort(keys)
	return keys
end
