local _, ns = ...

local config = ns.config.compass
local colors = config.colors
local Geometry = ns.CompassGeometry
local Markers = ns.CompassMarkers

local Compass = ns.RegisterModule("compass", {})

-- A black band below the notch, like the compass in Elder Scrolls Online:
-- the directions and the markers ahead of the character, and the name and
-- distance of the one in the centre. It follows the character's facing, as
-- there is no API for the camera's.

local DIRECTION_NAMES = ns.isGerman and { NE = "NO", E = "O", SE = "SO" } or nil

local band, labelBox, label
local directions = {}
local markerPool = {}
local markers = {}
local visible = {}
local mapID, mapWidth, mapHeight
local fov, focusAngle

local function ColorHex(color)
	return ("%02x%02x%02x"):format(color[1] * 255, color[2] * 255, color[3] * 255)
end
local distanceHex = ColorHex(colors.distance)

-- Hangs below the notch, or from the top edge without one, centred on it.
local function UpdateGeometry()
	local left, right, height, topOffset, real = ns.GetNotchRect()
	band:ClearAllPoints()
	band:SetPoint("TOP", UIParent, "TOPLEFT", (left + right) / 2, topOffset - (real and height or 0))
end

local function CreateDirections()
	for degrees = 0, 359, config.tickStep do
		local text = Geometry.DirectionLabel(degrees, DIRECTION_NAMES)
		local region
		if text then
			region = ns.CreateFontString(band, config.letterSize, "CENTER")
			region:SetText(text)
			region:SetTextColor(unpack(degrees == 0 and colors.north or colors.letter))
		else
			region = band:CreateTexture(nil, "ARTWORK")
			region:SetColorTexture(unpack(colors.tick))
			region:SetSize(1, config.tickHeight)
		end
		directions[#directions + 1] = { degrees = degrees, region = region, tick = not text }
	end
	-- Letters on every 45 degrees, also where tickStep doesn't land.
	for degrees = 0, 315, 45 do
		if degrees % config.tickStep ~= 0 then
			local region = ns.CreateFontString(band, config.letterSize, "CENTER")
			region:SetText(Geometry.DirectionLabel(degrees, DIRECTION_NAMES))
			region:SetTextColor(unpack(degrees == 0 and colors.north or colors.letter))
			directions[#directions + 1] = { degrees = degrees, region = region }
		end
	end
end

local function UpdateDirections(facing)
	local width = band:GetWidth()
	for _, direction in ipairs(directions) do
		local angle = Geometry.DirectionAngle(direction.degrees, facing)
		local x = Geometry.BandX(angle, fov, width)
		local region = direction.region
		if x then
			-- Ticks stand on the band's bottom edge, letters in its middle.
			if direction.tick then
				region:SetPoint("BOTTOM", band, "BOTTOM", x, 0)
			else
				region:SetPoint("CENTER", band, "CENTER", x, 0)
			end
			region:SetAlpha(Geometry.EdgeAlpha(angle, fov, config.fadeStart, config.edgeAlpha))
			region:Show()
		else
			region:Hide()
		end
	end
end

local function GetMarkerTexture(index)
	local texture = markerPool[index]
	if not texture then
		texture = band:CreateTexture(nil, "ARTWORK")
		markerPool[index] = texture
	end
	return texture
end

local function Collect()
	mapID = C_Map.GetBestMapForUnit("player")
	markers = mapID and Markers.Collect(mapID) or {}
	if mapID then
		mapWidth, mapHeight = C_Map.GetMapWorldSize(mapID)
	end
end

local function DrawMarker(texture, marker, angle, x)
	local scale, alpha = 1, Geometry.EdgeAlpha(angle, fov, config.fadeStart, config.edgeAlpha)
	if marker.priority == 0 then
		scale = Geometry.DistanceFactor(marker.distance, config.near, config.far, config.farScale)
		alpha = alpha * Geometry.DistanceFactor(marker.distance, config.near, config.far, config.farAlpha)
	end
	if marker.atlas then
		texture:SetAtlas(marker.atlas)
		texture:SetVertexColor(1, 1, 1)
		texture:SetSize(config.markerSize * scale, config.markerSize * scale)
	else
		local color = marker.color
		texture:SetColorTexture(color and color.r or 1, color and color.g or 1, color and color.b or 1)
		texture:SetSize(config.groupSize * scale, config.groupSize * scale)
	end
	-- Tracked markers on top of the others.
	texture:SetDrawLayer("ARTWORK", marker.priority > 0 and 2 or 1)
	texture:SetPoint("CENTER", band, "CENTER", x, 0)
	texture:SetAlpha(alpha)
	texture:Show()
end

local function UpdateLabel(focus)
	if not focus then
		labelBox:Hide()
		return
	end
	local text = focus.name or ""
	if focus.distance then
		local distance = Geometry.FormatDistance(focus.distance)
		text = text ~= "" and ("%s  |cff%s%s|r"):format(text, distanceHex, distance) or distance
	end
	label:SetText(text)
	labelBox:SetWidth(label:GetStringWidth() + 2 * config.letterSize)
	labelBox:Show()
end

local function UpdateMarkers(facing)
	local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
	local used = 0
	wipe(visible)
	if position then
		local playerX, playerY = position:GetXY()
		local width = band:GetWidth()
		local hasSize = mapWidth and mapWidth > 0 and mapHeight > 0
		for _, marker in ipairs(markers) do
			-- Without a map size the direction still works, only the distance doesn't.
			local east, north, distance = Geometry.Offset(
				playerX,
				playerY,
				marker.x,
				marker.y,
				hasSize and mapWidth or 1,
				hasSize and mapHeight or 1
			)
			marker.distance = hasSize and distance or nil
			local tooFar = config.maxDistance > 0
				and marker.priority == 0
				and marker.distance
				and marker.distance > config.maxDistance
			marker.angle = Geometry.RelativeAngle(Geometry.Bearing(east, north), facing)
			local x = not tooFar and Geometry.BandX(marker.angle, fov, width)
			if x then
				used = used + 1
				DrawMarker(GetMarkerTexture(used), marker, marker.angle, x)
				visible[#visible + 1] = marker
			end
		end
	end
	for index = used + 1, #markerPool do
		markerPool[index]:Hide()
	end
	UpdateLabel(Geometry.PickFocus(visible, focusAngle))
end

local sinceRefresh = 0

-- Collects soon, but at most a little before the regular refresh, so bursts
-- of events (QUEST_LOG_UPDATE) don't collect on every one.
local function RequestRefresh()
	sinceRefresh = math.max(sinceRefresh, config.refreshInterval - 0.1)
end

local function OnUpdate(_, elapsed)
	local island = ns.notchIsland
	local facing = GetPlayerFacing()
	-- No facing or positions in instances; the island covers the compass.
	local shown = facing ~= nil and not IsInInstance() and not (island and island:IsShown())
	band:SetShown(shown)
	if not shown then
		return
	end
	sinceRefresh = sinceRefresh + elapsed
	if sinceRefresh >= config.refreshInterval then
		sinceRefresh = 0
		Collect()
	end
	UpdateDirections(facing)
	UpdateMarkers(facing)
end

local function CreateBand()
	-- No mouse, so clicks and camera drags pass through. Below the island's strata.
	band = CreateFrame("Frame", "StevioUI_Compass", UIParent)
	band:SetFrameStrata("HIGH")
	band:SetSize(config.width, config.height)
	band:Hide()
	local background = band:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(unpack(colors.background))

	-- A black tab below the band, only as wide as its text.
	labelBox = CreateFrame("Frame", nil, band)
	labelBox:SetPoint("TOP", band, "BOTTOM")
	labelBox:SetHeight(config.labelHeight)
	labelBox:Hide()
	local labelBackground = labelBox:CreateTexture(nil, "BACKGROUND")
	labelBackground:SetAllPoints()
	labelBackground:SetColorTexture(unpack(colors.background))
	label = ns.CreateFontString(labelBox, nil, "CENTER")
	label:SetPoint("CENTER")
	label:SetTextColor(unpack(colors.label))

	CreateDirections()
end

local REFRESH_EVENTS = {
	"PLAYER_ENTERING_WORLD",
	"ZONE_CHANGED",
	"ZONE_CHANGED_INDOORS",
	"ZONE_CHANGED_NEW_AREA",
	"QUEST_LOG_UPDATE",
	"QUEST_POI_UPDATE",
	"SUPER_TRACKING_CHANGED",
	"VIGNETTES_UPDATED",
	"VIGNETTE_MINIMAP_UPDATED",
	"USER_WAYPOINT_UPDATED",
	"GROUP_ROSTER_UPDATE",
	"PLAYER_DEAD",
	"PLAYER_ALIVE",
	"PLAYER_UNGHOST",
}

function Compass:OnEnable()
	fov = math.rad(config.fov)
	focusAngle = math.rad(config.focusAngle)
	CreateBand()
	UpdateGeometry()

	-- Same as the notch: UIParent moves below the notch only later.
	hooksecurefunc("UpdateUIParentPosition", UpdateGeometry)
	ns.RegisterEvent("UI_SCALE_CHANGED", function()
		C_Timer.After(0, UpdateGeometry)
	end)
	for _, event in ipairs(REFRESH_EVENTS) do
		ns.RegisterEvent(event, RequestRefresh)
	end

	sinceRefresh = config.refreshInterval
	local driver = CreateFrame("Frame", "StevioUI_CompassDriver", UIParent)
	driver:SetScript("OnUpdate", OnUpdate)
end
