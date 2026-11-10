local _, ns = ...

local MinimapModule = ns.RegisterModule("minimap", {})
local config = ns.config.minimap

local SQUARE_MASK = "Interface\\Buttons\\WHITE8X8"

-- Read by other addons (e.g. LibDBIcon) to place their minimap buttons correctly.
function GetMinimapShape()
	return "SQUARE"
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
local function AdoptIndicators()
	AttachToMap(MinimapCluster.IndicatorFrame, "TOPRIGHT", -2, -2)

	local tracking = MinimapCluster.Tracking
	ns.KillTexture(tracking.Background)
	AttachToMap(tracking, "TOPLEFT", 2, -2)
end

-- Blizzard anchors the looking-for-group eye to the micro menu, which ends up
-- covering the map; the map's lower left corner keeps it out of the way. The
-- older names cover clients that still ship the minimap-cluster variant.
local function PlaceQueueButton()
	local button = QueueStatusButton or QueueStatusMinimapButton or MiniMapLFGFrame or LFGMinimapFrame
	if not button then
		return
	end
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

function MinimapModule:OnEnable()
	local size = GetMapSize()
	Minimap:SetParent(UIParent)
	Minimap:SetSize(size, size)
	Minimap:SetMaskTexture(SQUARE_MASK)
	ns.PinFrame(Minimap, function(frame)
		ns.SetPoint(frame, ns.layout.minimap)
	end)

	ns.CreateBorder(Minimap)

	AdoptIndicators()
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
end
