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

print("action bar systems tests passed")
