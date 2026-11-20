-- Run with: lua tests/compass_markers_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")

local ns = { config = {} }
function ns.T(english)
	return english
end
function ns.SafeCall(fn, ...)
	return true, fn(...)
end
loadAddonFile("Modules/Compass/Config.lua", ns)

-- Fake game API; names and shapes as in Blizzard_APIDocumentationGenerated.
local function Vector(x, y)
	return {
		x = x,
		y = y,
		GetXY = function(self)
			return self.x, self.y
		end,
	}
end
_G.CreateVector2D = Vector

local game = {}
local function Reset()
	game.tracked = 101
	game.trackedVignette = nil
	game.nextWaypoint = nil
	game.quests = { { questID = 101, x = 0.1, y = 0.2 }, { questID = 102, x = 0.3, y = 0.4 } }
	game.turnIn = { [102] = true }
	game.tasks = {}
	game.worldQuests = {}
	game.waypoint = nil
	game.vignettes = {}
	game.group = nil
	game.ghost = false
end

_G.C_SuperTrack = {
	GetSuperTrackedQuestID = function()
		return game.tracked
	end,
	GetSuperTrackedVignette = function()
		return game.trackedVignette
	end,
}
_G.C_QuestLog = {
	GetTitleForQuestID = function(id)
		return "Quest " .. id
	end,
	GetNextWaypoint = function()
		if game.nextWaypoint then
			return unpack(game.nextWaypoint)
		end
	end,
	GetQuestsOnMap = function()
		return game.quests
	end,
	ReadyForTurnIn = function(id)
		return game.turnIn[id] or false
	end,
	IsWorldQuest = function(id)
		return game.worldQuests[id] or false
	end,
}
_G.C_TaskQuest = {
	GetQuestsOnMap = function()
		return game.tasks
	end,
}
-- Two maps on continent 1: map 2 covers the right half of map 1.
_G.C_Map = {
	GetUserWaypoint = function()
		return game.waypoint
	end,
	GetWorldPosFromMapPos = function(mapID, position)
		if mapID == 3 then
			return 9, Vector(position.x, position.y)
		end
		local x = mapID == 2 and 0.5 + position.x / 2 or position.x
		return 1, Vector(x, position.y)
	end,
	GetMapPosFromWorldPos = function(_, world, mapID)
		local x = mapID == 2 and (world.x - 0.5) * 2 or world.x
		return mapID, Vector(x, world.y)
	end,
	GetPlayerMapPosition = function(_, unit)
		local member = game.group and game.group[unit]
		return member and Vector(member.x, member.y)
	end,
}
_G.C_VignetteInfo = {
	GetVignettes = function()
		local guids = {}
		for guid in pairs(game.vignettes) do
			guids[#guids + 1] = guid
		end
		table.sort(guids)
		return guids
	end,
	GetVignetteInfo = function(guid)
		return game.vignettes[guid].info
	end,
	GetVignettePosition = function(guid)
		return game.vignettes[guid].position
	end,
}
_G.C_DeathInfo = {
	GetCorpseMapPosition = function()
		return Vector(0.9, 0.9)
	end,
}
_G.C_ClassColor = {
	GetClassColor = function(class)
		return { r = 1, g = 0, b = 0, class = class }
	end,
}
function _G.IsInGroup()
	return game.group ~= nil
end
function _G.IsInRaid()
	return false
end
function _G.GetNumGroupMembers()
	return 3
end
function _G.UnitIsUnit(a, b)
	return a == b
end
function _G.UnitClass()
	return "Mage", "MAGE"
end
function _G.UnitName(unit)
	return "Name of " .. unit
end
function _G.UnitIsGhost()
	return game.ghost
end

loadAddonFile("Modules/Compass/Markers.lua", ns)
local Markers = ns.CompassMarkers

local function ByKind(list)
	local byKind = {}
	for _, marker in ipairs(list) do
		byKind[marker.kind] = byKind[marker.kind] or {}
		table.insert(byKind[marker.kind], marker)
	end
	return byKind
end

-- Pinned: these atlases are Blizzard's (WaypointLocationDataProvider.lua,
-- SuperTrackedFrame.lua, QuestUtils.lua, MapLegendFrame.lua).
check(Markers.ATLAS.mapPin == "Waypoint-MapPin-Tracked", "map pin atlas")
check(Markers.ATLAS.corpse == "Navigation-Tombstone-Icon", "corpse atlas")
check(Markers.ATLAS.quest == "QuestNormal" and Markers.ATLAS.questTurnIn == "QuestTurnin", "quest atlases")
check(Markers.ATLAS.worldQuest == "Worldquest-icon", "world quest atlas")
check(Markers.ATLAS.bonusObjective == "Bonus-Objective-Star", "bonus objective atlas")

-- The super-tracked quest is a quest like the others.
Reset()
local kinds = ByKind(Markers.Collect(1))
check(#kinds.quest == 2, "all quests on the map")
check(kinds.quest[1].name == "Quest 101" and kinds.quest[1].x == 0.1, "tracked quest from the quests on the map")
check(kinds.quest[1].priority == 0 and kinds.quest[1].atlas == "QuestNormal", "tracked quest not preferred")
check(kinds.quest[2].atlas == "QuestTurnin" and kinds.quest[2].priority == 0, "ready to turn in")
check(not kinds.group and not kinds.corpse and not kinds.mapPin, "nothing else")

-- Map indicator quests are left out, as on the world map.
Reset()
game.quests[2].isMapIndicatorQuest = true
kinds = ByKind(Markers.Collect(1))
check(#kinds.quest == 1 and kinds.quest[1].name == "Quest 101", "map indicator quest skipped")

-- The next step on another map of the same continent is moved onto the player's map.
Reset()
game.nextWaypoint = { 2, 0.5, 0.6 }
kinds = ByKind(Markers.Collect(1))
check(#kinds.quest == 2, "tracked quest only once")
check(kinds.quest[1].x == 0.75 and kinds.quest[1].y == 0.6, "next step converted")
check(kinds.quest[1].priority == 0, "next step not preferred")
-- On another continent the quest's own position is used.
game.nextWaypoint = { 3, 0.5, 0.6 }
kinds = ByKind(Markers.Collect(1))
check(#kinds.quest == 2 and kinds.quest[1].x == 0.1, "next step on another continent")

Reset()
game.tracked = nil
game.waypoint = { uiMapID = 2, position = Vector(0, 0.5) }
kinds = ByKind(Markers.Collect(1))
check(#kinds.quest == 2, "nothing tracked: all quests")
check(kinds.mapPin[1].x == 0.5 and kinds.mapPin[1].priority == 1, "map pin")

-- World quests and bonus objectives of this map, each quest only once.
Reset()
game.tasks = {
	{ questID = 201, mapID = 1, x = 0.6, y = 0.6 },
	{ questID = 202, mapID = 1, x = 0.7, y = 0.7 },
	{ questID = 203, mapID = 2, x = 0.8, y = 0.8 },
	{ questID = 101, mapID = 1, x = 0.9, y = 0.9 },
}
game.worldQuests = { [201] = true }
kinds = ByKind(Markers.Collect(1))
check(#kinds.worldQuest == 2, "tasks of sub-maps and quests already listed are skipped")
check(kinds.worldQuest[1].name == "Quest 201" and kinds.worldQuest[1].atlas == "Worldquest-icon", "world quest")
check(kinds.worldQuest[2].atlas == "Bonus-Objective-Star", "bonus objective")
check(kinds.worldQuest[1].priority == 0, "world quests not preferred")

Reset()
game.vignettes = {
	a = { info = { name = "Rare", atlasName = "VignetteKill", isDead = false }, position = Vector(0.2, 0.2) },
	b = { info = { name = "Dead", atlasName = "VignetteKill", isDead = true }, position = Vector(0.2, 0.2) },
	c = { info = { name = "Nowhere", atlasName = "VignetteLoot", isDead = false } },
	d = { info = { name = "Chest", atlasName = "VignetteLoot", isDead = false }, position = Vector(0.4, 0.2) },
}
game.trackedVignette = "d"
kinds = ByKind(Markers.Collect(1))
check(#kinds.vignette == 2, "dead and unplaced vignettes are skipped")
check(kinds.vignette[1].name == "Rare" and kinds.vignette[1].atlas == "VignetteKill", "vignette with its atlas")
check(kinds.vignette[2].priority == 1, "super-tracked vignette wins")

Reset()
game.group = { party1 = { x = 0.5, y = 0.5 } }
kinds = ByKind(Markers.Collect(1))
check(#kinds.group == 1 and kinds.group[1].name == "Name of party1", "group members with a position")
check(kinds.group[1].color.class == "MAGE" and kinds.group[1].atlas == nil, "in class colour")

Reset()
game.ghost = true
kinds = ByKind(Markers.Collect(1))
check(kinds.corpse[1].x == 0.9 and kinds.corpse[1].priority == 1, "corpse while a ghost")

-- Switched off kinds are left out.
Reset()
game.nextWaypoint = { 2, 0.5, 0.6 }
game.tasks = { { questID = 201, mapID = 1, x = 0.6, y = 0.6 } }
ns.config.compass.markers.quests = false
ns.config.compass.markers.worldQuests = false
kinds = ByKind(Markers.Collect(1))
check(not kinds.quest and not kinds.worldQuest, "quests switched off")
ns.config.compass.markers.quests = true
ns.config.compass.markers.worldQuests = true

print("compass markers tests passed")
