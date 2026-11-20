local _, ns = ...

-- Collects what the compass shows into a plain list, with every position on
-- the player's current map. Only what the game reveals to addons: the
-- minimap's gathering nodes and NPC dots have no API.

local Markers = {}
ns.CompassMarkers = Markers

local config = ns.config.compass
local enabled = config.markers

-- Pins, corpses and tracked vignettes keep their full size and show beyond
-- maxDistance. Quests are all alike, tracked or not.
local TRACKED, NORMAL = 1, 0

-- Atlases Blizzard uses for the same things (WaypointLocationDataProvider.lua,
-- SuperTrackedFrame.lua, the quest POI pins, QuestUtils.lua and MapLegendFrame.lua).
Markers.ATLAS = {
	mapPin = "Waypoint-MapPin-Tracked",
	corpse = "Navigation-Tombstone-Icon",
	quest = "QuestNormal",
	questTurnIn = "QuestTurnin",
	worldQuest = "Worldquest-icon",
	bonusObjective = "Bonus-Objective-Star",
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

local function QuestAtlas(questID)
	return C_QuestLog.ReadyForTurnIn(questID) and Markers.ATLAS.questTurnIn or Markers.ATLAS.quest
end

-- The quests the game puts on the map: the ones in the objective tracker.
-- There is no API for where the other quests in the log are.
local function AddQuests(list, mapID, seen)
	if not enabled.quests then
		return
	end
	-- The super-tracked quest's next step (portal, flight path, ...) when its
	-- objective lies elsewhere, so it doesn't drop off the compass.
	local tracked = C_SuperTrack.GetSuperTrackedQuestID()
	if tracked and tracked > 0 then
		local wayMap, wayX, wayY = C_QuestLog.GetNextWaypoint(tracked)
		if wayMap then
			local x, y = ToMap(wayMap, wayX, wayY, mapID)
			if x then
				seen[tracked] = true
				Add(list, "quest", C_QuestLog.GetTitleForQuestID(tracked), x, y, NORMAL, QuestAtlas(tracked))
			end
		end
	end
	for _, quest in ipairs(C_QuestLog.GetQuestsOnMap(mapID) or {}) do
		local id = quest.questID
		if not seen[id] and not quest.isMapIndicatorQuest then
			seen[id] = true
			Add(list, "quest", C_QuestLog.GetTitleForQuestID(id), quest.x, quest.y, NORMAL, QuestAtlas(id))
		end
	end
end

-- World quests and bonus objectives in the zone (not those of its sub-maps,
-- as on the world map).
local function AddWorldQuests(list, mapID, seen)
	if not enabled.worldQuests then
		return
	end
	for _, task in ipairs(C_TaskQuest.GetQuestsOnMap(mapID) or {}) do
		local id = task.questID
		local name = C_QuestLog.GetTitleForQuestID(id)
		if not seen[id] and name and task.mapID == mapID then
			seen[id] = true
			local atlas = C_QuestLog.IsWorldQuest(id) and Markers.ATLAS.worldQuest or Markers.ATLAS.bonusObjective
			Add(list, "worldQuest", name, task.x, task.y, NORMAL, atlas)
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
-- Quests run before world quests, so a quest is listed only once.
local SOURCES = { AddQuests, AddWorldQuests, AddMapPin, AddVignettes, AddGroup, AddCorpse }

function Markers.Collect(mapID)
	local list, seen = {}, {}
	for _, source in ipairs(SOURCES) do
		ns.SafeCall(source, list, mapID, seen)
	end
	return list
end
