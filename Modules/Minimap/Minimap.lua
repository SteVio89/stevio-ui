local _, ns = ...

local MinimapModule = ns:RegisterModule("minimap", {})

local SQUARE_MASK = "Interface\\Buttons\\WHITE8X8"

-- Read by other addons (e.g. LibDBIcon) to place their minimap buttons correctly.
function GetMinimapShape()
	return "SQUARE"
end

local function OnMouseWheel(minimap, delta)
	local zoom = Clamp(minimap:GetZoom() + delta, 0, minimap:GetZoomLevels() - 1)
	minimap:SetZoom(zoom)
end

-- Mail and tracking are the only cluster parts worth keeping; they move onto
-- the map itself so the whole cluster (border, zone text, clock, calendar) can go.
local function AdoptIndicators(config)
	local indicators = MinimapCluster.IndicatorFrame
	indicators:SetParent(Minimap)
	indicators:SetScale(config.iconScale)
	ns.PinFrame(indicators, function(frame)
		frame:ClearAllPoints()
		frame:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -2, -2)
	end)

	local tracking = MinimapCluster.Tracking
	tracking:SetParent(Minimap)
	tracking:SetScale(config.iconScale)
	ns.KillTexture(tracking.Background)
	ns.PinFrame(tracking, function(frame)
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 2, -2)
	end)
end

-- Derived from the layout instead of a fixed size so the map always ends just
-- short of the target frame, whatever the screen width or UI scale.
local function GetMapSize(config)
	local targetWidth
	for _, spec in ipairs(ns.config.units.frames) do
		if spec.unit == "target" then
			targetWidth = spec.width
		end
	end
	local targetRight = UIParent:GetWidth() / 2 + ns.layout.target.x + targetWidth
	local mapRight = UIParent:GetWidth() + ns.layout.minimap.x
	return math.floor(mapRight - targetRight - config.gapToTarget)
end

-- The leave button would sit on the action bars; under the map's lower left
-- corner it stays clear of them. Via Edit Mode because Blizzard re-stacks it
-- with the bottom bars, in combat too.
local function PlaceVehicleLeaveButton(config, size)
	local mapLayout = ns.layout.minimap
	ns:SetEditModeSystem(Enum.EditModeSystem.VehicleLeaveButton, nil, {
		point = "TOPLEFT",
		relativePoint = "BOTTOMRIGHT",
		x = mapLayout.x - size,
		y = mapLayout.y - config.vehicleLeaveGap,
	})
end

function MinimapModule:OnEnable(config)
	local size = GetMapSize(config)
	Minimap:SetParent(UIParent)
	Minimap:SetSize(size, size)
	Minimap:SetMaskTexture(SQUARE_MASK)
	ns.PinFrame(Minimap, function(frame)
		ns.SetPoint(frame, ns.layout.minimap)
	end)

	ns.CreateBorder(Minimap)

	AdoptIndicators(config)
	PlaceVehicleLeaveButton(config, size)

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
