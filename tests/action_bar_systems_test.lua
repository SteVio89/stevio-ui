-- Run with: lua tests/action_bar_systems_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")

-- Enum.EditModeActionBarSystemIndices as the client defines it
-- (Blizzard_APIDocumentationGenerated/EditModeManagerConstantsDocumentation.lua).
local indices = {
	MainBar = 1,
	Bar2 = 2,
	Bar3 = 3,
	RightBar1 = 4,
	RightBar2 = 5,
	ExtraBar1 = 6,
	ExtraBar2 = 7,
	ExtraBar3 = 8,
	StanceBar = 11,
	PetActionBar = 12,
	PossessActionBar = 13,
}

local ns = loadAddonFile("Modules/ActionBars/ActionBars.lua", {
	config = { actionBars = {}, style = {} },
	RegisterModule = function()
		return {}
	end,
})
local systems = ns.actionBarSystems

-- Every bar name maps to an index that exists; a wrong name silently left
-- the bar at Blizzard's default position.
local expected = { MainBar = 1, Bar2 = 2, Bar3 = 3, Bar4 = 4, Bar5 = 5, Bar6 = 6, Bar7 = 7, Bar8 = 8 }
for bar, index in pairs(expected) do
	check(systems[bar], bar .. " is known")
	check(indices[systems[bar].index] == index, bar .. " maps to Edit Mode index " .. index)
end

-- Every bar the layout places is known.
local layoutNs = loadAddonFile("Core/Layout.lua")
for _, entry in ipairs(layoutNs.layout.actionBars) do
	check(systems[entry.bar], "layout bar " .. entry.bar .. " is known")
end

-- The action sets' first slot of each bar follows Blizzard's bar pages
-- (Blizzard_ActionBar/Shared/MultiActionBars.lua: RIGHT_ACTIONBAR_PAGE = 3, ...).
local pages = { Bar4 = 3, Bar5 = 4, Bar3 = 5, Bar2 = 6, Bar6 = 13, Bar7 = 14, Bar8 = 15 }
local Sets = loadAddonFile("Modules/ActionBars/Sets.lua").ActionSets
for bar, slot in pairs(Sets.BAR_FIRST_SLOT) do
	check(systems[bar], "action set bar " .. bar .. " is known")
	check(pages[bar] and slot == (pages[bar] - 1) * 12 + 1, bar .. " starts at its page's first slot")
end
for bar in pairs(pages) do
	check(Sets.BAR_FIRST_SLOT[bar], bar .. " has a first slot")
end

-- The bars every set leaves alone exist; a typo would share nothing.
local configNs = loadAddonFile("Modules/ActionBars/Config.lua", { config = {} })
for _, bar in ipairs(configNs.config.actionBars.sharedBars) do
	check(Sets.BAR_FIRST_SLOT[bar], "shared bar " .. bar .. " is known")
end

print("action bar systems tests passed")
