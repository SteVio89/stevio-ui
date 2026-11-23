local _, ns = ...

local MinimapModule = ns.RegisterModule("minimap", {})
local config = ns.config.minimap

local SQUARE_MASK = "Interface\\Buttons\\WHITE8X8"
-- Another plain square, set first: setting the mask already set does nothing.
local OTHER_SQUARE_MASK = "Interface\\ChatFrame\\ChatFrameBackground"

-- Read by other addons (e.g. LibDBIcon) to place their minimap buttons
-- correctly. Defined at load, as they may place buttons before the module is
-- enabled; with the module off they get Blizzard's round map.
function GetMinimapShape()
	return config.enabled == false and "ROUND" or "SQUARE"
end

local function OnMouseWheel(minimap, delta)
	local zoom = Clamp(minimap:GetZoom() + delta, 0, minimap:GetZoomLevels() - 1)
	minimap:SetZoom(zoom)
end

-- Moves a cluster part onto the map, pinned to the same corner of the map
-- at the given offset.
local function AttachToMap(frame, point, x, y)
	frame:SetParent(Minimap)
	frame:SetScale(config.iconScale)
	ns.PinFrame(frame, function(pinned)
		pinned:ClearAllPoints()
		pinned:SetPoint(point, Minimap, point, x, y)
	end)
end

-- Mail and tracking are the only cluster parts worth keeping; they move onto
-- the map itself so the whole cluster (border, zone text, clock, calendar) can go.
-- Mail goes to the lower right corner, so the top edge stays free for the
-- zone name and clock.
local function AdoptIndicators()
	AttachToMap(MinimapCluster.IndicatorFrame, "BOTTOMRIGHT", -2, 2)

	local tracking = MinimapCluster.Tracking
	ns.KillTexture(tracking.Background)
	AttachToMap(tracking, "TOPLEFT", 2, -2)
	-- Above the zone header's fade.
	tracking:SetFrameLevel(Minimap:GetFrameLevel() + 5)
end

-- Blizzard anchors the looking-for-group eye to the micro menu, which ends up
-- covering the map; the map's lower left corner keeps it out of the way.
local function PlaceQueueButton()
	local button = QueueStatusButton
	AttachToMap(button, "BOTTOMLEFT", 2, 2)
	-- Above the map; set after the reparenting, which changes the level.
	button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
end

-- Derived from the layout instead of a fixed size so the map scales with the
-- space right of the target frame, whatever the screen width or UI scale.
local function GetMapSize()
	return ns.MinimapGeometry.MapSize(
		UIParent:GetWidth(),
		ns.layout.target.x,
		ns.MinimapGeometry.TargetWidth(ns.config.units.frames),
		ns.layout.minimap.x,
		config.gapToTarget,
		config.sizeScale
	)
end

-- The leave button would sit on the action bars; under the map's lower left
-- corner it stays clear of them. Via Edit Mode because Blizzard re-stacks it
-- with the bottom bars, in combat too.
local function PlaceVehicleLeaveButton(size)
	local mapLayout = ns.layout.minimap
	ns.SetEditModeSystem(Enum.EditModeSystem.VehicleLeaveButton, nil, {
		point = "TOPLEFT",
		relativePoint = "BOTTOMRIGHT",
		x = mapLayout.x - size,
		y = mapLayout.y - config.vehicleLeaveGap,
	})
end

local function ApplySquareMask()
	Minimap:SetMaskTexture(OTHER_SQUARE_MASK)
	Minimap:SetMaskTexture(SQUARE_MASK)
end

-- The map stays north up. A rotating map turns its mask into a circle, and
-- the circle stays after the rotation is switched off, so the square mask
-- is set again a moment after every change of the rotation CVar. The CVar
-- is saved, so a rotation left on from an earlier session (or set by Edit
-- Mode or another addon) would otherwise keep the map round.
local function KeepNorthUp()
	if GetCVar("rotateMinimap") ~= "0" then
		SetCVar("rotateMinimap", "0")
	end
	ApplySquareMask()
	C_Timer.After(0.2, ApplySquareMask)
end

-- The zone name (after the tracking button) and the clock on a fade along
-- the top edge, above the map but below its icons.
local function CreateHeader()
	if not (config.showZone or config.showClock) then
		return
	end
	local palette = ns.config.style.palette
	local header = CreateFrame("Frame", nil, Minimap)
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT")
	header:SetHeight(config.headerHeight)
	header:SetFrameLevel(Minimap:GetFrameLevel() + 1)
	local fade = header:CreateTexture(nil, "BACKGROUND")
	fade:SetAllPoints()
	fade:SetTexture(ns.config.style.texture)
	fade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.62))

	local clock
	if config.showClock then
		clock = ns.CreateFontString(header, 11, "RIGHT")
		clock:SetPoint("TOPRIGHT", -10, -7)
		local r, g, b = unpack(palette.text)
		clock:SetTextColor(r, g, b, 0.8)
		local function UpdateClock()
			clock:SetText(date("%H:%M"))
		end
		UpdateClock()
		C_Timer.NewTicker(10, UpdateClock)
	end

	if config.showZone then
		local zone = ns.CreateFontString(header, 11, "LEFT")
		zone:SetPoint("TOPLEFT", MinimapCluster.Tracking, "TOPRIGHT", 4, -5)
		zone:SetPoint("RIGHT", clock or header, clock and "LEFT" or "RIGHT", -8, 0)
		zone:SetTextColor(unpack(palette.textStrong))
		local function UpdateZone()
			zone:SetText(GetMinimapZoneText())
		end
		UpdateZone()
		for _, event in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }) do
			ns.RegisterEvent(event, UpdateZone)
		end
	end
end

function MinimapModule:OnEnable()
	local size = GetMapSize()
	Minimap:SetParent(UIParent)
	Minimap:SetSize(size, size)
	ns.PinFrame(Minimap, function(frame)
		ns.SetPoint(frame, ns.layout.minimap)
	end)

	ns.CreatePanel(Minimap, { background = false })

	AdoptIndicators()
	CreateHeader()
	PlaceQueueButton()
	PlaceVehicleLeaveButton(size)

	ns.KeepHidden(MinimapBackdrop)
	ns.KeepHidden(Minimap.ZoomIn)
	ns.KeepHidden(Minimap.ZoomOut)
	ns.KeepHidden(Minimap.ZoomHitArea)
	ns.KeepHidden(MinimapCluster)

	Minimap:EnableMouseWheel(true)
	Minimap:SetScript("OnMouseWheel", OnMouseWheel)

	-- The size change needs a forced redraw, otherwise the map keeps rendering at the old size.
	Minimap:SetZoom(Minimap:GetZoom() > 0 and 0 or 1)
	Minimap:SetZoom(0)

	KeepNorthUp()
	ns.RegisterEvent("CVAR_UPDATE", function(_, name)
		-- Compared without case: the payload's spelling is unverified.
		if name and name:lower() == "rotateminimap" then
			KeepNorthUp()
		end
	end)
end
