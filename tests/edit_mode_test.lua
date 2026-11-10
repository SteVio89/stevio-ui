-- Run with: lua tests/edit_mode_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")

-- The game globals Core/EditModeSystems.lua uses.
_G.Enum = { EditModeLayoutType = { Preset = 0, Account = 1, Character = 2 } }
function _G.CopyTable(source)
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = type(value) == "table" and _G.CopyTable(value) or value
	end
	return copy
end

local ns = loadAddonFile("Core/EditModeSystems.lua")
local Systems = ns.EditModeSystems

-- EditModeStep: steps above a minimum.
check(ns.EditModeStep(80, 50, 10) == 3, "icon size 80% is step 3")
check(ns.EditModeStep(50, 50, 10) == 0, "the minimum is step 0")
check(ns.EditModeStep(450, 400, 10) == 5, "tracker height")
check(ns.EditModeStep(85, 50, 10) == 3.5, "between steps")
print("steps ok")

-- FindOwnLayout: by name, and only as an account layout.
local layouts = {
	{ layoutName = "stevio-ui", layoutType = Enum.EditModeLayoutType.Character },
	{ layoutName = "Other", layoutType = Enum.EditModeLayoutType.Account },
	{ layoutName = "stevio-ui", layoutType = Enum.EditModeLayoutType.Account },
}
local index, layout = Systems.FindOwnLayout(layouts, "stevio-ui")
check(index == 3 and layout == layouts[3], "own account layout")
check(Systems.FindOwnLayout(layouts, "missing") == nil, "no own layout")
check(Systems.FindOwnLayout({}, "stevio-ui") == nil, "no layouts")
print("own layout ok")

-- Find: by system and index.
local function Layout()
	return {
		systems = {
			{
				system = 0,
				systemIndex = 1,
				anchorInfo = {
					point = "BOTTOM",
					relativeTo = "UIParent",
					relativePoint = "BOTTOM",
					offsetX = 0,
					offsetY = 38,
				},
				isInDefaultPosition = false,
				settings = { { setting = 0, value = 1 }, { setting = 3, value = 3 } },
			},
			{
				system = 0,
				systemIndex = 2,
				anchorInfo = {
					point = "BOTTOM",
					relativeTo = "UIParent",
					relativePoint = "BOTTOM",
					offsetX = 0,
					offsetY = 0,
				},
				isInDefaultPosition = true,
				settings = {},
			},
			{ system = 1, systemIndex = nil, anchorInfo = {}, settings = {} },
		},
	}
end
local layoutInfo = Layout()
check(Systems.Find(layoutInfo, 0, 2) == layoutInfo.systems[2], "system by index")
check(Systems.Find(layoutInfo, 1, nil) == layoutInfo.systems[3], "system without an index")
check(Systems.Find(layoutInfo, 0, 3) == nil, "missing system")
print("find ok")

-- ApplyAnchor: changed only when the position differs or was Blizzard's default.
local same = { point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = 0, offsetY = 38 }
local systemInfo = layoutInfo.systems[1]
check(Systems.ApplyAnchor(systemInfo, same) == false, "same anchor is no change")
check(systemInfo.anchorInfo ~= same and systemInfo.anchorInfo.offsetY == 38, "anchor copied")
local moved = { point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = 0, offsetY = 40 }
check(Systems.ApplyAnchor(systemInfo, moved) == true, "moved anchor")
check(systemInfo.anchorInfo.offsetY == 40, "new anchor written")
check(Systems.ApplyAnchor(systemInfo, moved) == false, "applying again is no change")

systemInfo = layoutInfo.systems[2]
local defaultAnchor = { point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = 0, offsetY = 0 }
check(Systems.ApplyAnchor(systemInfo, defaultAnchor) == true, "leaving the default position is a change")
check(systemInfo.isInDefaultPosition == false, "no longer in the default position")

systemInfo = layoutInfo.systems[1]
systemInfo.anchorInfo2 = { point = "TOP" }
check(Systems.ApplyAnchor(systemInfo, moved) == true, "a second anchor is a change")
check(systemInfo.anchorInfo2 == nil, "second anchor dropped")
print("anchors ok")

-- ApplySettings: only settings the system carries, changed only on a new value.
systemInfo = Layout().systems[1]
check(Systems.ApplySettings(systemInfo, { [0] = 1, [3] = 3 }) == false, "same settings")
check(Systems.ApplySettings(systemInfo, { [99] = 5 }) == false, "unknown setting ignored")
check(#systemInfo.settings == 2, "unknown setting not added")
check(Systems.ApplySettings(systemInfo, { [3] = 4 }) == true, "changed setting")
check(systemInfo.settings[2].value == 4 and systemInfo.settings[1].value == 1, "only that setting written")
check(Systems.ApplySettings(systemInfo, {}) == false, "no settings")
print("settings ok")

print("edit mode tests passed")
