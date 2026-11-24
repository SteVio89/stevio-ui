local _, ns = ...

local config = ns.config.group
local style = ns.config.style

-- Game API called on every unit event of up to 40 cells, as upvalues.
local UnitExists, UnitName, UnitIsUnit, UnitInRange = UnitExists, UnitName, UnitIsUnit, UnitInRange
local UnitThreatSituation, UnitGetDetailedHealPrediction = UnitThreatSituation, UnitGetDetailedHealPrediction
local UnitIsConnected, UnitIsDeadOrGhost, UnitIsPlayer, UnitClass =
	UnitIsConnected, UnitIsDeadOrGhost, UnitIsPlayer, UnitClass
local issecretvalue = issecretvalue

-- Where things sit on the health bar, shared with the /sui test preview
-- (Preview.lua): name and role in the top row, debuffs right below on the
-- right, own HoTs at the bottom left.
local CELL_LAYOUT = {
	nameX = 4,
	nameY = -3,
	nameRight = -14,
	roleX = -3,
	roleY = -3,
	debuffX = -3,
	debuffY = -16,
	ownX = 4,
	ownY = -31,
	-- Of config.debuffsMax, the dispellable group gets at most this many.
	dispellableMax = 2,
}
ns.GROUP_CELL_LAYOUT = CELL_LAYOUT

-- "dead", "offline" or nil. Group members' states are readable; a secret one
-- (should that ever happen) shows as alive.
local function UnitStatus(unit)
	local connected, dead = UnitIsConnected(unit), UnitIsDeadOrGhost(unit)
	if issecretvalue(connected) or issecretvalue(dead) then
		return nil
	end
	if not connected then
		return "offline"
	elseif dead then
		return "dead"
	end
	return nil
end

-- Whether the name goes dark on this unit's bright class color; only for a
-- class that isn't secret, as its color is compared.
local function WantsDarkName(unit)
	local isPlayer = UnitIsPlayer(unit)
	if issecretvalue(isPlayer) or not isPlayer then
		return false
	end
	local _, classFile = UnitClass(unit)
	if not classFile or issecretvalue(classFile) then
		return false
	end
	local color = C_ClassColor.GetClassColor(classFile)
	return color ~= nil and ns.Luminance(color.r, color.g, color.b) > config.darkNameLuminance
end

local STATUS_TEXT = {
	dead = ns.T("DEAD", "TOT"),
	offline = ns.T("OFFLINE", "OFFLINE"),
}

-- Health bar color (may be secret), background tint, name color and the
-- dead/offline label; shared with the preview.
function ns.ShowGroupCellState(cell, status, darkName, r, g, b)
	local palette = style.palette
	cell.health:SetStatusBarColor(r, g, b)
	local name = cell.nameText
	if status then
		cell.healthTrack:SetVertexColor(unpack(config.deadTrackColor))
		cell.statusText:SetText(STATUS_TEXT[status])
		cell.statusText:Show()
	else
		ns.SetTrackColor(cell.healthTrack, r, g, b)
		cell.statusText:Hide()
	end
	if darkName and not status then
		name:SetTextColor(unpack(config.darkNameColor))
		name:SetShadowColor(0, 0, 0, 0)
	else
		name:SetTextColor(unpack(status and palette.textFaint or palette.textStrong))
		name:SetShadowColor(0, 0, 0, 1)
	end
end

-- Incoming heals and absorbs may be secret: the calculator clamps them to the
-- missing health and the bars take them as they are, so nothing is compared.
local function UpdatePrediction(cell)
	local unit, calculator = cell.unit, cell.calculator
	-- Missing if building the bars failed (see InitGroupCell).
	if not calculator then
		return
	end
	UnitGetDetailedHealPrediction(unit, "player", calculator)
	local maxHealth = calculator:GetMaximumHealth()
	local _, fromMe, fromOthers = calculator:GetIncomingHeals()
	local absorbs = calculator:GetDamageAbsorbs()
	cell.myHeal:SetMinMaxValues(0, maxHealth)
	cell.myHeal:SetValue(fromMe)
	cell.otherHeal:SetMinMaxValues(0, maxHealth)
	cell.otherHeal:SetValue(fromOthers)
	cell.absorb:SetMinMaxValues(0, maxHealth)
	cell.absorb:SetValue(absorbs)
end

local function UpdateHealth(cell)
	local unit = cell.unit
	ns.UpdateHealthBar(cell.health, unit)
	local r, g, b = ns.UnitHealthColor(unit)
	ns.ShowGroupCellState(cell, UnitStatus(unit), WantsDarkName(unit), r, g, b)
	UpdatePrediction(cell)
end

local function UpdateName(cell)
	cell.nameText:SetText(UnitName(cell.unit))
end

local function UpdatePower(cell)
	ns.UpdatePowerBar(cell.power, cell.unit)
end

local function UpdatePowerColor(cell)
	ns.SetPowerBarColor(cell.power, cell.unit)
end

local function UpdatePowerType(cell)
	ns.UpdatePowerType(cell.power, cell.unit)
end

-- Whether the cell shows the player. UnitIsUnit may be secret in combat; then
-- the answer from the last readable check of the same unit token is used.
local function IsPlayerCell(cell)
	local unit = cell.unit
	if unit == "player" then
		return true
	end
	local isPlayer = UnitIsUnit(unit, "player")
	if not issecretvalue(isPlayer) then
		cell.checkedUnit, cell.checkedIsPlayer = unit, isPlayer
		return isPlayer
	end
	return cell.checkedUnit == unit and cell.checkedIsPlayer
end

-- The player's own cell can't be range checked and always stays at full alpha,
-- in combat too. In combat checkedRange may be secret; every other group
-- member can be checked, so inRange alone decides then.
local function UpdateRange(cell)
	local unit = cell.unit
	if IsPlayerCell(cell) then
		cell:SetAlpha(1)
		return
	end

	local inRange, checkedRange = UnitInRange(unit)
	if issecretvalue(inRange) or issecretvalue(checkedRange) then
		cell:SetAlphaFromBoolean(inRange, 1, config.outOfRangeAlpha)
	else
		cell:SetAlpha((checkedRange and not inRange) and config.outOfRangeAlpha or 1)
	end
end

local function UpdateTarget(cell)
	cell.targetBorder:SetShownFromBoolean(UnitIsUnit(cell.unit, "target"))
end

-- A secret threat status can't be compared, so the indicator stays off then.
local function UpdateThreat(cell)
	local status = UnitThreatSituation(cell.unit)
	cell.aggroBorder:SetShown(not issecretvalue(status) and status ~= nil and status >= 2)
end

-- Blizzard's delegate resolves the role securely, so a secret role in combat
-- still shows the right icon without this code ever reading it.
local function UpdateRole(cell)
	UnitFrameUtil.UpdateUnitFrameRoleIcon(cell)
end

-- The name comes first so a failing update further down can't leave the
-- previous occupant's name on the cell.
local function UpdateAll(cell)
	if not cell.unit or not UnitExists(cell.unit) then
		cell.nameText:SetText("")
		return
	end
	UpdateName(cell)
	UpdateHealth(cell)
	UpdatePower(cell)
	UpdatePowerColor(cell)
	UpdateRange(cell)
	UpdateTarget(cell)
	UpdateThreat(cell)
	UpdateRole(cell)
end

local unitEvents = {
	UNIT_HEALTH = UpdateHealth,
	UNIT_MAXHEALTH = UpdateHealth,
	UNIT_CONNECTION = UpdateHealth,
	UNIT_FLAGS = UpdateHealth,
	UNIT_POWER_UPDATE = UpdatePower,
	UNIT_MAXPOWER = UpdatePower,
	UNIT_DISPLAYPOWER = UpdatePowerType,
	UNIT_IN_RANGE_UPDATE = UpdateRange,
	UNIT_THREAT_SITUATION_UPDATE = UpdateThreat,
	-- Like CompactUnitFrame: the name arriving may also mean the class is now
	-- known, which colors the health bar.
	UNIT_NAME_UPDATE = function(cell)
		UpdateName(cell)
		UpdateHealth(cell)
	end,
	UNIT_HEAL_PREDICTION = UpdatePrediction,
	UNIT_ABSORB_AMOUNT_CHANGED = UpdatePrediction,
	UNIT_HEAL_ABSORB_AMOUNT_CHANGED = UpdatePrediction,
}

local globalEvents = {
	PLAYER_TARGET_CHANGED = UpdateTarget,
	PLAYER_ROLES_ASSIGNED = UpdateRole,
}

-- Blizzard's aura containers reread and lay out their auras right inside
-- SetUnit and UpdateAllAuras. They come last and each runs protected, so an
-- error in one (reported to /sui errors) costs only that aura group, never
-- the cell's own colors and events, nor the other groups.
local function UpdateAuraContainers(cell, method, ...)
	for _, container in ipairs(cell.auraContainers) do
		ns.SafeCall(container[method], container, ...)
	end
end

-- A cell whose token may now stand for another player. Blizzard's aura
-- containers only reread on a new token (SetUnit ignores the same one), so
-- they are told to, like the target auras on a target change.
local function RefreshCell(cell)
	UpdateAll(cell)
	UpdateAuraContainers(cell, "UpdateAllAuras")
end

-- Every cell the headers created.
local cells = {}
local rosterRefreshPending = false

-- Defined below, next to the attribute handler.
local SyncUnit

local function RefreshAllCells()
	rosterRefreshPending = false
	for _, cell in ipairs(cells) do
		SyncUnit(cell)
	end
end

-- A roster change refreshes all cells once, on the next frame: the headers
-- reassign units in their own handler, and cells handed a new unit update
-- right then (OnAttributeChanged). Several roster events in one frame share
-- the one refresh.
ns.RegisterEvent("GROUP_ROSTER_UPDATE", function()
	if not rosterRefreshPending then
		rosterRefreshPending = true
		C_Timer.After(0, RefreshAllCells)
	end
end)

local function OnEvent(cell, event)
	-- Defensive: SetUnit unregisters all events when the unit goes away.
	if not cell.unit then
		return
	end
	local handler = unitEvents[event] or globalEvents[event]
	handler(cell)
end

local function SetUnit(cell, unit)
	cell.unit = unit
	cell:UnregisterAllEvents()
	if not unit then
		cell.nameText:SetText("")
		return
	end
	for event in pairs(unitEvents) do
		cell:RegisterUnitEvent(event, unit)
	end
	for event in pairs(globalEvents) do
		cell:RegisterEvent(event)
	end
	UpdateAll(cell)
	UpdateAuraContainers(cell, "SetUnit", unit)
end

-- Unit tokens belong to roster positions, not players: after someone leaves,
-- "party1" or "raid3" may be someone else while the header hands the cell the
-- same token again. So a repeated token still refreshes everything.
local function OnAttributeChanged(cell, name, value)
	if name ~= "unit" then
		return
	end
	if value ~= cell.unit then
		SetUnit(cell, value)
	elseif value then
		RefreshCell(cell)
	end
end

-- The unit the header gave the cell, read back from its attribute, so a cell
-- that missed the attribute change (or wasn't listening yet) catches up.
function SyncUnit(cell)
	OnAttributeChanged(cell, "unit", cell:GetAttribute("unit"))
end

-- Shown again: a new unit, or the same one with whatever changed while hidden.
local function OnShow(cell)
	local unit = cell:GetAttribute("unit")
	if unit ~= cell.unit then
		SetUnit(cell, unit)
	else
		UpdateAll(cell)
	end
end

-- Shared with the /sui test preview's stand-in icons (Preview.lua).
local ICON_SPACING = 2
local ICON_COUNT_SIZE = 9
ns.GROUP_ICON_SPACING = ICON_SPACING
ns.GROUP_ICON_COUNT_SIZE = ICON_COUNT_SIZE

-- Addon code can't read other units' auras in combat (the queries error once
-- they turn secret), so Blizzard's secure container reads and tracks them and
-- only fills in the elements we hand it. `anchorPoint` is the cell corner or
-- edge the icons start from (e.g. "TOPRIGHT", "TOPLEFT"), on `relativeTo`
-- (default: the health bar) at `relativePoint`.
local function CreateAuraGroup(cell, options)
	local anchorPoint = options.anchorPoint
	return ns.CreateAuraContainer(cell.health, {
		place = function(container)
			container:SetFrameLevel(cell.health:GetFrameLevel() + 2)
			container:SetPoint(
				anchorPoint,
				options.relativeTo or cell.health,
				options.relativePoint or anchorPoint,
				options.x,
				options.y
			)
		end,
		-- The icons are display only; clicks go through to the cell underneath.
		noMouse = true,
		flowAnchor = anchorPoint,
		growth = options.growth,
		key = options.key,
		filter = options.filter,
		max = options.max,
		spacing = ICON_SPACING,
		initializeFrame = ns.AuraButtonInitializer(options.size, ICON_COUNT_SIZE, options.borderColor),
	})
end

-- A bar that continues the health fill to the right: it starts where the fill
-- of `after` ends and is as wide as the whole health bar, so a value up to the
-- missing health (the calculator clamps to it) never leaves the cell.
local function CreateFillBar(cell, after, color)
	local bar = ns.CreateStatusBar(cell.health)
	local fill = after:GetStatusBarTexture()
	bar:SetPoint("TOPLEFT", fill, "TOPRIGHT")
	bar:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT")
	bar:SetStatusBarColor(unpack(color))
	bar:SetFrameLevel(cell.health:GetFrameLevel())
	return bar
end

local function CreatePrediction(cell)
	cell.myHeal = CreateFillBar(cell, cell.health, config.myHealColor)
	cell.otherHeal = CreateFillBar(cell, cell.myHeal, config.otherHealColor)
	cell.absorb = CreateFillBar(cell, cell.otherHeal, config.absorbColor)
	-- Blizzard's striped shield texture over the absorb fill.
	local stripes = cell.absorb:CreateTexture(nil, "ARTWORK", nil, 1)
	stripes:SetAllPoints(cell.absorb:GetStatusBarTexture())
	SetTextureWithAddressModeOptions(
		stripes,
		"RaidFrame-Shield-Overlay",
		TextureKitConstants.IgnoreAtlasSize,
		TextureKitConstants.AddressModeWrap,
		TextureKitConstants.AddressModeWrap
	)
	cell.health:HookScript("OnSizeChanged", function(_, width)
		cell.myHeal:SetWidth(width)
		cell.otherHeal:SetWidth(width)
		cell.absorb:SetWidth(width)
	end)

	local calculator = CreateUnitHealPredictionCalculator()
	calculator:SetIncomingHealClampMode(Enum.UnitIncomingHealClampMode.MissingHealth)
	calculator:SetIncomingHealOverflowPercent(1)
	calculator:SetDamageAbsorbClampMode(Enum.UnitDamageAbsorbClampMode.MissingHealth)
	cell.calculator = calculator
end

-- Visuals only, shared by live cells and the /sui test preview.
function ns.BuildGroupCell(cell)
	local px = ns.PixelSize(cell)

	local palette = style.palette

	ns.CreateBackground(cell, palette.cell)
	ns.CreateBorder(cell, 0)
	cell.targetBorder = ns.CreateBorder(cell, 2, 2)
	cell.targetBorder:SetColor(unpack(config.targetColor))
	cell.targetBorder:SetShown(false)

	cell.power = ns.CreateStatusBar(cell)
	cell.power:SetPoint("BOTTOMLEFT")
	cell.power:SetPoint("BOTTOMRIGHT")
	cell.power:SetHeight(config.powerHeight)

	cell.health = ns.CreateStatusBar(cell)
	cell.health:SetPoint("TOPLEFT")
	cell.health:SetPoint("BOTTOMRIGHT", cell.power, "TOPRIGHT", 0, px)
	cell.healthTrack = ns.CreateTintedTrack(cell.health)
	ns.CreateBarShade(cell.health)

	ns.CreateSeparator(cell, "BOTTOM", cell.power, "TOP")

	cell.nameText = ns.CreateFontString(cell.health, config.nameFontSize)
	cell.nameText:SetPoint("TOPLEFT", CELL_LAYOUT.nameX, CELL_LAYOUT.nameY)
	cell.nameText:SetPoint("RIGHT", CELL_LAYOUT.nameRight, 0)
	cell.nameText:SetTextColor(unpack(palette.textStrong))

	cell.statusText = ns.CreateFontString(cell.health, 9, "CENTER")
	cell.statusText:SetPoint("CENTER")
	cell.statusText:SetTextColor(unpack(palette.textFaint))
	cell.statusText:Hide()

	-- Inside the cell, above the bars and icons.
	local overlay = ns.CreateOverlay(cell)
	cell.aggroBorder = ns.CreateInsetBorder(overlay, 1)
	cell.aggroBorder:SetColor(unpack(config.aggroColor))
	cell.aggroBorder:SetShown(false)

	-- Field names are what Blizzard's role icon delegate reads from the frame.
	-- Damage dealers get an empty texture, so only tanks and healers show.
	cell.roleIcon = cell.health:CreateTexture(nil, "OVERLAY")
	cell.roleIcon:SetSize(config.roleIconSize, config.roleIconSize)
	cell.roleIcon:SetPoint("TOPRIGHT", CELL_LAYOUT.roleX, CELL_LAYOUT.roleY)
	cell.roleIcon:Hide()
	cell.optionTable = { displayRoleIcon = true, textureMap = { DAMAGER = "" } }
end

-- Adds a Blizzard aura container (see CreateAuraGroup) to the cell. Each is
-- built protected: one that fails leaves only its own group empty, reported
-- to /sui errors. Returns the container, or nil.
local function AddAuraGroup(cell, options)
	local ok, container = ns.SafeCall(CreateAuraGroup, cell, options)
	if ok then
		cell.auraContainers[#cell.auraContainers + 1] = container
		return container
	end
end

local function CreateAuraGroups(cell)
	local Flow = AnchorUtil.FlowDirection
	-- Two containers, as each takes one filter: the other debuffs continue left
	-- of the dispellable ones (a container sizes itself to its icons), so
	-- together they never exceed config.debuffsMax.
	local dispellableMax = math.min(CELL_LAYOUT.dispellableMax, config.debuffsMax)
	local dispellable = AddAuraGroup(cell, {
		key = "dispellable",
		filter = config.dispellableFilter,
		anchorPoint = "TOPRIGHT",
		x = CELL_LAYOUT.debuffX,
		y = CELL_LAYOUT.debuffY,
		growth = Flow.Left,
		max = dispellableMax,
		size = config.iconSize,
		borderColor = config.dispelColor,
	})
	AddAuraGroup(cell, {
		key = "other",
		filter = config.otherFilter,
		anchorPoint = "TOPRIGHT",
		-- Where the dispellable ones would start, should their container be missing.
		relativeTo = dispellable,
		relativePoint = dispellable and "TOPLEFT" or "TOPRIGHT",
		x = dispellable and -ICON_SPACING or CELL_LAYOUT.debuffX,
		y = dispellable and 0 or CELL_LAYOUT.debuffY,
		growth = Flow.Left,
		max = config.debuffsMax - dispellableMax,
		size = config.iconSize,
	})
	AddAuraGroup(cell, {
		key = "own",
		filter = config.ownAuraFilter,
		anchorPoint = "TOPLEFT",
		x = CELL_LAYOUT.ownX,
		y = CELL_LAYOUT.ownY,
		growth = Flow.Right,
		max = config.ownAurasMax,
		size = config.ownAuraSize,
	})
end

-- Called from the XML template's OnLoad; the cell size lives in Cell.xml
-- because the secure header may create cells in combat, where Lua can't resize them.
function ns.InitGroupCell(cell)
	-- A Button only reacts to the left button's up-click by default; the
	-- type1/type2 attributes set by the header need both buttons. Cells are
	-- precreated out of combat (see PrecreateCells), where this is allowed.
	cell:RegisterForClicks("AnyUp")
	ns.AddUnitTooltip(cell)
	ns.BuildGroupCell(cell)
	-- The cell listens for its unit before the extras are built: should one of
	-- them fail, it still paints health, name and power instead of staying an
	-- empty block, and the error goes to /sui errors.
	cell.auraContainers = {}
	cells[#cells + 1] = cell
	cell:SetScript("OnEvent", OnEvent)
	cell:HookScript("OnAttributeChanged", OnAttributeChanged)
	cell:HookScript("OnShow", OnShow)
	ns.SafeCall(CreatePrediction, cell)
	CreateAuraGroups(cell)
	-- In case the header handed out the unit before the hook was in place.
	SyncUnit(cell)
end
