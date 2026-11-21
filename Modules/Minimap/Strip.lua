local addonName, ns = ...

local config = ns.config.minimap.strip
local colors = config.colors
local Geometry = ns.MinimapGeometry

-- The band below the notch that holds the minimap in the strip view
-- (Minimap.lua moves the map in and out): black like the notch, clipping the
-- map and anything on it to the band, with the direction letters along its
-- top edge. There is only one minimap, so the strip is the real one, masked
-- (Media/StripMask.tga) and rotating with the character.

local Strip = {}
ns.MinimapStrip = Strip

Strip.MASK = ("Interface\\AddOns\\%s\\Media\\StripMask"):format(addonName)

local DIRECTION_NAMES = ns.isGerman and { NE = "NO", E = "O", SE = "SO" } or nil

local band, letters
local directions = {}

-- Hangs below the notch, or from the top edge without one, centred on it.
local function UpdateGeometry()
	local left, right, height, topOffset, real = ns.GetNotchRect()
	band:ClearAllPoints()
	band:SetPoint("TOP", UIParent, "TOPLEFT", (left + right) / 2, topOffset - (real and height or 0))
end

local function CreateDirections()
	for _, degrees in ipairs(Geometry.DirectionDegrees(config.tickStep)) do
		local text = Geometry.DirectionLabel(degrees, DIRECTION_NAMES)
		local region
		if text then
			region = ns.CreateFontString(letters, config.letterSize, "CENTER")
			region:SetText(text)
			region:SetTextColor(unpack(degrees == 0 and colors.north or colors.letter))
		else
			region = letters:CreateTexture(nil, "ARTWORK")
			region:SetColorTexture(unpack(colors.tick))
			region:SetSize(1, config.tickHeight)
		end
		directions[#directions + 1] = { degrees = degrees, region = region, tick = not text }
	end
end

-- Each direction sits where its ray from the arrow leaves the top edge.
local function UpdateDirections(facing)
	local halfWidth = config.width / 2
	for _, direction in ipairs(directions) do
		local x = Geometry.EdgeX(Geometry.DirectionAngle(direction.degrees, facing), config.height, halfWidth)
		local region = direction.region
		if x then
			-- Ticks hang from the top edge, letters just below them.
			region:ClearAllPoints()
			if direction.tick then
				region:SetPoint("TOP", letters, "TOP", x, 0)
			else
				region:SetPoint("TOP", letters, "TOP", x, -config.tickHeight)
			end
			region:SetAlpha(Geometry.EdgeAlpha(x, halfWidth, config.fadeStart, config.edgeAlpha))
			region:Show()
		else
			region:Hide()
		end
	end
end

-- Runs while the strip is shown.
local function OnUpdate()
	-- The island covers the strip while open. Alpha instead of hiding, so
	-- the minimap inside isn't hidden.
	local island = ns.notchIsland
	band:SetAlpha(island and island:IsShown() and 0 or 1)
	-- No facing in instances: the map stays, the letters go.
	local facing = GetPlayerFacing()
	letters:SetShown(facing ~= nil)
	if facing then
		UpdateDirections(facing)
	end
end

-- `strata` is the minimap's, so the map can go between the background and
-- the letters.
function Strip.Create(strata)
	-- No mouse, so clicks and camera drags pass through.
	band = CreateFrame("Frame", "StevioUI_MinimapStrip", UIParent)
	band:SetFrameStrata(strata)
	band:SetSize(config.width, config.height + config.behind)
	band:SetClipsChildren(true)
	band:Hide()
	local background = band:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(unpack(colors.background))

	letters = CreateFrame("Frame", nil, band)
	letters:SetAllPoints()
	CreateDirections()

	band:SetScript("OnUpdate", OnUpdate)

	UpdateGeometry()
	-- Same as the notch: UIParent moves below the notch only later.
	hooksecurefunc("UpdateUIParentPosition", UpdateGeometry)
	ns.RegisterEvent("UI_SCALE_CHANGED", function()
		C_Timer.After(0, UpdateGeometry)
	end)
	return band
end

-- Puts the map (as wide as the band) into the band, centred on the arrow,
-- which sits `behind` above the band's bottom edge.
function Strip.Adopt(minimap)
	minimap:SetParent(band)
	minimap:SetFrameStrata(band:GetFrameStrata())
	minimap:SetFrameLevel(band:GetFrameLevel() + 1)
	minimap:SetSize(config.width, config.width)
	letters:SetFrameLevel(minimap:GetFrameLevel() + 10)
end

function Strip.Place(minimap)
	minimap:ClearAllPoints()
	minimap:SetPoint("CENTER", band, "BOTTOM", 0, config.behind)
end
