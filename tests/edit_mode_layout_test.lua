-- Run with: lua tests/edit_mode_layout_test.lua  (from the repo root)
-- Core/EditModeLayout.lua against a fake C_EditMode: when the layout is
-- applied, how it is saved, the layout limit and the callbacks afterwards.
local check, loadAddonFile = dofile("tests/helpers.lua")

_G.Enum = {
	EditModeLayoutType = { Preset = 0, Account = 1, Character = 2 },
	EditModeSystem = { ActionBar = 0 },
}
_G.Constants = { EditModeConsts = { EditModeMaxLayoutsPerType = 5 } }
function _G.CopyTable(source)
	local copy = {}
	for key, value in pairs(source) do
		copy[key] = type(value) == "table" and _G.CopyTable(value) or value
	end
	return copy
end
function _G.tAppendAll(list, other)
	for _, value in ipairs(other) do
		list[#list + 1] = value
	end
end

local function System(index)
	return {
		system = 0,
		systemIndex = index,
		anchorInfo = { point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = 0, offsetY = 0 },
		isInDefaultPosition = true,
		settings = { { setting = 0, value = 0 } },
	}
end
local function Preset(name)
	return { layoutName = name, layoutType = 0, systems = { System(1) } }
end
_G.EditModePresetLayoutManager = {
	GetCopyOfPresetLayouts = function()
		return { Preset("Modern"), Preset("Classic") }
	end,
}

-- Loads the file fresh with `saved` as the server's layouts; returns the
-- event handlers, what was saved and activated, and the notices.
local function Load(saved, initialized)
	local handlers, calls, notices = {}, { saves = {}, active = {} }, {}
	_G.C_EditMode = {
		GetLayouts = function()
			return CopyTable(saved)
		end,
		SaveLayouts = function(info)
			calls.saves[#calls.saves + 1] = info
		end,
		SetActiveLayout = function(index)
			calls.active[#calls.active + 1] = index
		end,
	}
	_G.EditModeManagerFrame = {
		IsInitialized = function()
			return initialized
		end,
	}
	local ns = {
		T = function(english)
			return english
		end,
		Notify = function(text)
			notices[#notices + 1] = text
		end,
		RegisterEvent = function(event, handler)
			handlers[event] = handler
		end,
		UnregisterEvent = function(event)
			handlers[event] = nil
		end,
		RunAfterCombat = function(fn)
			fn()
		end,
		SafeCall = function(fn, ...)
			return pcall(fn, ...)
		end,
	}
	loadAddonFile("Core/EditModeSystems.lua", ns)
	loadAddonFile("Core/EditModeLayout.lua", ns)
	ns.SetEditModeSystem(0, 1, { point = "BOTTOM", y = 40 }, { [0] = 1 })
	local function Fire(event)
		if handlers[event] then
			handlers[event](event)
		end
	end
	return ns, calls, notices, Fire, handlers
end

-- First time: our layout is added in front of the custom ones and activated.
local mine = { layoutName = "Mine", layoutType = 2, systems = { System(1) } }
local ns, calls, _, Fire = Load({ layouts = { mine }, activeLayout = 3 }, true)
local ran = 0
ns.OnEditModeLayoutApplied(function()
	ran = ran + 1
end)
Fire("EDIT_MODE_LAYOUTS_UPDATED")
check(#calls.saves == 0 and ran == 0, "waits for the modules")
ns.ApplyEditModeLayout()
check(#calls.saves == 1, "saved once")
local layouts = calls.saves[1].layouts
check(
	#layouts == 4 and layouts[3].layoutName == "stevio-ui" and layouts[4].layoutName == "Mine",
	"presets, ours, then the player's"
)
check(layouts[3].layoutType == 1, "ours is an account layout")
check(calls.saves[1].activeLayout == 3 and calls.active[#calls.active] == 3, "ours is activated")
local system = layouts[3].systems[1]
check(system.anchorInfo.offsetY == 40 and not system.isInDefaultPosition, "position written")
check(system.settings[1].value == 1, "setting written")
check(ran == 1, "callback after applying")
local late = 0
ns.OnEditModeLayoutApplied(function()
	late = late + 1
end)
check(late == 1, "a callback registered afterwards runs at once")
Fire("EDIT_MODE_LAYOUTS_UPDATED")
check(#calls.saves == 1, "applied only once per session")
print("first apply ok")

-- Already in place and active: nothing is saved.
local ours = CopyTable(layouts[3])
ns, calls, _, Fire = Load({ layouts = { ours, mine }, activeLayout = 3 }, true)
ns.ApplyEditModeLayout()
Fire("PLAYER_ENTERING_WORLD")
check(#calls.saves == 0 and #calls.active == 0, "unchanged layout left alone")
print("unchanged ok")

-- Active but changed: saved, then left and re-entered so it applies now.
ours.systems[1].anchorInfo.offsetY = 10
ns, calls, _, Fire = Load({ layouts = { ours, mine }, activeLayout = 3 }, true)
ns.ApplyEditModeLayout()
Fire("EDIT_MODE_LAYOUTS_UPDATED")
check(#calls.saves == 1 and calls.active[1] == 1 and calls.active[2] == 3, "re-entered after saving")
print("changed ok")

-- Entering the world before Blizzard has the layouts: wait for them.
ns, calls, _, Fire = Load({ layouts = {}, activeLayout = 1 }, false)
ns.ApplyEditModeLayout()
Fire("PLAYER_ENTERING_WORLD")
check(#calls.saves == 0, "no save before the layouts arrived")
Fire("EDIT_MODE_LAYOUTS_UPDATED")
check(#calls.saves == 1, "saved once they arrived")
print("waiting for layouts ok")

-- No room for ours: nothing saved, a notice, and callbacks still run.
local full = {}
for i = 1, 5 do
	full[i] = { layoutName = "A" .. i, layoutType = 1, systems = { System(1) } }
end
full[6] = mine
local notices
ns, calls, notices, Fire = Load({ layouts = full, activeLayout = 3 }, true)
ran = 0
ns.OnEditModeLayoutApplied(function()
	ran = ran + 1
end)
ns.ApplyEditModeLayout()
Fire("EDIT_MODE_LAYOUTS_UPDATED")
check(#calls.saves == 0 and #calls.active == 0, "nothing saved without room")
check(#notices == 1 and notices[1]:find("5 account layouts", 1, true), "the player is told")
check(ran == 1, "callbacks still run")
print("layout limit ok")

-- HasRoomForOwnLayout counts account layouts only.
local Systems = ns.EditModeSystems
check(Systems.HasRoomForOwnLayout({ mine, mine, mine, mine, mine, mine }, 5), "character layouts don't count")
check(not Systems.HasRoomForOwnLayout(full, 5), "five account layouts")
print("edit mode layout tests passed")
