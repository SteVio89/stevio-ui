local _, ns = ...

local MinimapModule = ns.RegisterModule("minimap", {})
local config = ns.config.minimap
local Strip = ns.MinimapStrip

local SQUARE_MASK = "Interface\\Buttons\\WHITE8X8"
-- Another plain square, set first: setting the mask already set does nothing.
local OTHER_SQUARE_MASK = "Interface\\ChatFrame\\ChatFrameBackground"

-- Two views of the one minimap, switched with ns.ToggleMinimapView (the ','
-- key): the square map in the corner, north up, and the strip below the
-- notch (Strip.lua), rotating with the character. The choice is kept in
-- StevioUIState.minimapView.
local CORNER, STRIP = "corner", "strip"

-- Stands in for the map in the corner, so the mark toolbar and the map's
-- corner position stay put while the map is in the strip.
local corner
-- Holds the cluster parts on the map (mail, tracking, queue), which only
-- show in the corner view.
local icons
local border, band
local cornerSize, cornerStrata, cornerLevel
local view = STRIP
-- The view the map is in; differs from `view` while combat delays the switch.
local appliedView
-- The corner view's zoom; the strip always uses the widest one (0).
local cornerZoom = 0

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
	frame:SetParent(icons)
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

-- The size change needs a forced redraw, otherwise the map keeps rendering at the old size.
local function Redraw(zoom)
	Minimap:SetZoom(zoom > 0 and 0 or 1)
	Minimap:SetZoom(zoom)
end

local function PlaceMap(frame)
	if (appliedView or view) == STRIP then
		Strip.Place(frame)
	else
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", corner, "CENTER")
	end
end

-- A mask set while the map still rotates (or before it rotates) turns with
-- it, so the mask follows the rotation CVar a moment later.
local function RefreshMask()
	if appliedView == STRIP then
		Strip.RefreshMask()
		return
	end
	C_Timer.After(0.2, function()
		if appliedView == CORNER then
			Minimap:SetMaskTexture(OTHER_SQUARE_MASK)
			Minimap:SetMaskTexture(SQUARE_MASK)
		end
	end)
end

-- The rotation is a CVar, which Edit Mode also sets from its layout (north
-- up in ours), so it is applied again after Edit Mode.
local function ApplyRotation()
	local rotate = appliedView == STRIP and "1" or "0"
	if GetCVar("rotateMinimap") ~= rotate then
		SetCVar("rotateMinimap", rotate)
		RefreshMask()
	end
end

local function ApplyView()
	local strip = view == STRIP
	if strip and appliedView ~= STRIP then
		cornerZoom = Minimap:GetZoom()
	end
	appliedView = view
	if strip then
		Strip.Adopt(Minimap)
	else
		Strip.Release()
		Minimap:SetParent(UIParent)
		Minimap:SetFrameStrata(cornerStrata)
		Minimap:SetFrameLevel(cornerLevel)
		Minimap:SetSize(cornerSize, cornerSize)
	end
	PlaceMap(Minimap)
	band:SetShown(strip)
	icons:SetShown(not strip)
	border:SetShown(not strip)
	-- The strip lets clicks and camera drags pass through.
	Minimap:EnableMouse(not strip)
	Minimap:EnableMouseWheel(not strip)
	ApplyRotation()
	Redraw(strip and 0 or cornerZoom)
	RefreshMask()
end

-- Moving the map is protected in combat once something protected sits on it.
local function RequestView()
	if Minimap:IsProtected() then
		ns.RunAfterCombat(ApplyView)
	else
		ApplyView()
	end
end

-- Bound to a key even while the module is off; then there is nothing to switch.
function ns.ToggleMinimapView()
	if not band then
		return
	end
	view = view == STRIP and CORNER or STRIP
	if StevioUIState then
		StevioUIState.minimapView = view
	end
	RequestView()
end

function MinimapModule:OnEnable()
	cornerSize = GetMapSize()
	cornerStrata, cornerLevel = Minimap:GetFrameStrata(), Minimap:GetFrameLevel()
	corner = CreateFrame("Frame", "StevioUI_MinimapCorner", UIParent)
	corner:SetSize(cornerSize, cornerSize)
	ns.SetPoint(corner, ns.layout.minimap)
	ns.minimapCorner = corner

	Minimap:SetParent(UIParent)
	Minimap:SetSize(cornerSize, cornerSize)
	border = ns.CreateBorder(Minimap)
	icons = CreateFrame("Frame", nil, Minimap)
	icons:SetAllPoints()
	band = Strip.Create(cornerStrata)

	AdoptIndicators()
	PlaceQueueButton()
	PlaceVehicleLeaveButton(cornerSize)

	ns.KeepHidden(MinimapBackdrop)
	ns.KeepHidden(Minimap.ZoomIn)
	ns.KeepHidden(Minimap.ZoomOut)
	ns.KeepHidden(Minimap.ZoomHitArea)
	ns.KeepHidden(MinimapCluster)

	Minimap:SetScript("OnMouseWheel", OnMouseWheel)

	if MinimapCluster and MinimapCluster.UpdateSystemSettingRotateMinimap then
		hooksecurefunc(MinimapCluster, "UpdateSystemSettingRotateMinimap", ApplyRotation)
	end

	view = StevioUIState and StevioUIState.minimapView == CORNER and CORNER or STRIP
	ns.PinFrame(Minimap, PlaceMap)
	RequestView()
end
