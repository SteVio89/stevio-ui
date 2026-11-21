local addonName, ns = ...

local config = ns.config.minimap.strip
local colors = config.colors
local Geometry = ns.MinimapGeometry

-- The band below the notch that holds the minimap in the strip view
-- (Minimap.lua moves the map in and out): black like the notch, with the
-- direction letters along its top edge. There is only one minimap, so the
-- strip is the real one, rotating with the character. Neither clipping nor a
-- scroll frame cuts the minimap, only its mask does, and a rotating minimap
-- turns its mask along. So the mask is swapped as the character turns, for
-- one turned back by the facing (Media/StripMasks, tools/strip_mask.py).

local Strip = {}
ns.MinimapStrip = Strip

local MASK_PATH = ("Interface\\AddOns\\%s\\Media\\StripMasks\\%%03d"):format(addonName)
local maskCount = math.floor(360 / config.maskStep + 0.5)

local DIRECTION_NAMES = ns.isGerman and { NE = "NO", E = "O", SE = "SO" } or nil

local band, letters, map
local directions = {}
-- The mask on the map; nil forces the next frame to set one.
local maskIndex

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
	if not facing then
		return
	end
	UpdateDirections(facing)
	local index = Geometry.MaskIndex(facing, maskCount, config.maskDirection)
	if index ~= maskIndex and map then
		map:SetMaskTexture(MASK_PATH:format(index))
		maskIndex = index
	end
end

-- `strata` is the minimap's, so the map can go between the background and
-- the letters.
function Strip.Create(strata)
	-- No mouse, so clicks and camera drags pass through.
	band = CreateFrame("Frame", "StevioUI_MinimapStrip", UIParent)
	band:SetFrameStrata(strata)
	band:SetSize(config.width, config.height + config.behind)
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

-- Puts the map into the band, centred on the arrow, which sits `behind`
-- above the band's bottom edge. The mask follows from the next frame on.
function Strip.Adopt(minimap)
	map = minimap
	maskIndex = nil
	minimap:SetParent(band)
	minimap:SetFrameStrata(band:GetFrameStrata())
	minimap:SetFrameLevel(band:GetFrameLevel() + 1)
	local size = Geometry.StripMapSize(config.width, config.height)
	minimap:SetSize(size, size)
	letters:SetFrameLevel(minimap:GetFrameLevel() + 10)
end

-- Sets the mask again once the rotation has changed. Setting the one
-- already set does nothing, so a neighbour goes first.
function Strip.RefreshMask()
	if map then
		C_Timer.After(0.2, function()
			if band:IsShown() and maskIndex then
				map:SetMaskTexture(MASK_PATH:format((maskIndex + 1) % maskCount))
				map:SetMaskTexture(MASK_PATH:format(maskIndex))
			end
		end)
	end
end

-- The map left for the corner: stop swapping its mask.
function Strip.Release()
	map = nil
	maskIndex = nil
end

function Strip.Place(minimap)
	minimap:ClearAllPoints()
	minimap:SetPoint("CENTER", band, "BOTTOM", 0, config.behind)
end
