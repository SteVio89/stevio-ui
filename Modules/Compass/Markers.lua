local _, ns = ...

-- Collects what the compass shows into a plain list, with every position on
-- the player's current map. Only what the game reveals to addons: the
-- minimap's gathering nodes and NPC dots have no API.

local Markers = {}
ns.CompassMarkers = Markers

local config = ns.config.compass
local enabled = config.markers

-- Tracked things win the focus and keep their full size.
local TRACKED, NORMAL = 1, 0

-- Atlases Blizzard uses for the same things (SuperTrackedFrame.lua,
-- WaypointLocationDataProvider.lua and the quest POI pins).
Markers.ATLAS = {
	trackedQuest = "Navigation-Tracked-Icon",
	mapPin = "Waypoint-MapPin-Tracked",
	corpse = "Navigation-Tombstone-Icon",
	quest = "QuestNormal",
	questTurnIn = "QuestTurnin",
}

local L = {
	mapPin = ns.T("Map pin", "Kartenmarkierung"),
	corpse = ns.T("Corpse", "Leichnam"),
}

-- A point on `fromMap` as a position on `toMap`, through world coordinates
-- when the maps differ. Nil when it lies on another continent.
local function ToMap(fromMap, x, y, toMap)
	if fromMap == toMap then
		return x, y
	end
	local continent, world = C_Map.GetWorldPosFromMapPos(fromMap, CreateVector2D(x, y))
	local playerContinent = C_Map.GetWorldPosFromMapPos(toMap, CreateVector2D(0.5, 0.5))
	if not continent or continent ~= playerContinent then
		return nil
	end
	local _, position = C_Map.GetMapPosFromWorldPos(continent, world, toMap)
	if not position then
		return nil
	end
	return position:GetXY()
end

local function Add(list, kind, name, x, y, priority, atlas, color)
	if not x then
		return
	end
	list[#list + 1] = { kind = kind, name = name, x = x, y = y, priority = priority, atlas = atlas, color = color }
end

local function AddQuests(list, mapID)
	local tracked = C_SuperTrack.GetSuperTrackedQuestID()
	if enabled.trackedQuest and tracked and tracked > 0 then
		local name = C_QuestLog.GetTitleForQuestID(tracked)
		-- The next step (portal, flight path, ...) when the objective lies elsewhere.
		local wayMap, wayX, wayY = C_QuestLog.GetNextWaypoint(tracked)
		if wayMap then
			local x, y = ToMap(wayMap, wayX, wayY, mapID)
			Add(list, "trackedQuest", name, x, y, TRACKED, Markers.ATLAS.trackedQuest)
		else
			for _, quest in ipairs(C_QuestLog.GetQuestsOnMap(mapID) or {}) do
				if quest.questID == tracked then
					Add(list, "trackedQuest", name, quest.x, quest.y, TRACKED, Markers.ATLAS.trackedQuest)
					break
				end
			end
		end
	end
	if not enabled.quests then
		return
	end
	for _, quest in ipairs(C_QuestLog.GetQuestsOnMap(mapID) or {}) do
		if quest.questID ~= tracked then
			local atlas = C_QuestLog.ReadyForTurnIn(quest.questID) and Markers.ATLAS.questTurnIn or Markers.ATLAS.quest
			Add(list, "quest", C_QuestLog.GetTitleForQuestID(quest.questID), quest.x, quest.y, NORMAL, atlas)
		end
	end
end

local function AddMapPin(list, mapID)
	local point = enabled.mapPin and C_Map.GetUserWaypoint()
	if point then
		local x, y = ToMap(point.uiMapID, point.position.x, point.position.y, mapID)
		Add(list, "mapPin", L.mapPin, x, y, TRACKED, Markers.ATLAS.mapPin)
	end
end

local function AddVignettes(list, mapID)
	if not enabled.vignettes then
		return
	end
	local tracked = C_SuperTrack.GetSuperTrackedVignette()
	for _, guid in ipairs(C_VignetteInfo.GetVignettes() or {}) do
		local info = C_VignetteInfo.GetVignetteInfo(guid)
		if info and not info.isDead and info.atlasName and info.atlasName ~= "" then
			local position = C_VignetteInfo.GetVignettePosition(guid, mapID)
			if position then
				local x, y = position:GetXY()
				Add(list, "vignette", info.name, x, y, guid == tracked and TRACKED or NORMAL, info.atlasName)
			end
		end
	end
end

local function AddGroup(list, mapID)
	if not enabled.group or not IsInGroup() then
		return
	end
	local prefix, count = "party", GetNumGroupMembers() - 1
	if IsInRaid() then
		prefix, count = "raid", GetNumGroupMembers()
	end
	for index = 1, count do
		local unit = prefix .. index
		if not UnitIsUnit(unit, "player") then
			local position = C_Map.GetPlayerMapPosition(mapID, unit)
			if position then
				local x, y = position:GetXY()
				local color = C_ClassColor.GetClassColor(select(2, UnitClass(unit)) or "")
				Add(list, "group", UnitName(unit), x, y, NORMAL, nil, color)
			end
		end
	end
end

local function AddCorpse(list, mapID)
	if not enabled.corpse or not UnitIsGhost("player") then
		return
	end
	local position = C_DeathInfo.GetCorpseMapPosition(mapID)
	if position then
		local x, y = position:GetXY()
		Add(list, "corpse", L.corpse, x, y, TRACKED, Markers.ATLAS.corpse)
	end
end

-- Each source runs protected, so one failing API doesn't empty the compass.
local SOURCES = { AddQuests, AddMapPin, AddVignettes, AddGroup, AddCorpse }

function Markers.Collect(mapID)
	local list = {}
	for _, source in ipairs(SOURCES) do
		ns.SafeCall(source, list, mapID)
	end
	return list
end
