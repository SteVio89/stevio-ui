local _, ns = ...

local config = ns.config.group
local style = ns.config.style

-- Incoming heals and absorbs may be secret: the calculator clamps them to the
-- missing health and the bars take them as they are, so nothing is compared.
local function UpdatePrediction(cell)
	local unit, calculator = cell.unit, cell.calculator
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
	cell.health:SetMinMaxValues(0, UnitHealthMax(unit))
	cell.health:SetValue(UnitHealth(unit))
	cell.health:SetStatusBarColor(ns.UnitHealthColor(unit))
	UpdatePrediction(cell)
end

local function UpdateName(cell)
	cell.nameText:SetText(UnitName(cell.unit))
end

local function UpdatePower(cell)
	local unit = cell.unit
	cell.power:SetMinMaxValues(0, UnitPowerMax(unit))
	cell.power:SetValue(UnitPower(unit))
end

local function UpdatePowerColor(cell)
	cell.power:SetStatusBarColor(ns.UnitPowerColor(cell.unit))
end

local function UpdateRange(cell)
	local unit = cell.unit
	local isPlayer = UnitIsUnit(unit, "player")
	if not issecretvalue(isPlayer) and isPlayer then
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

local function UpdateAll(cell)
	if not cell.unit or not UnitExists(cell.unit) then
		return
	end
	UpdateHealth(cell)
	UpdateName(cell)
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
	UNIT_DISPLAYPOWER = function(cell)
		UpdatePowerColor(cell)
		UpdatePower(cell)
	end,
	UNIT_IN_RANGE_UPDATE = UpdateRange,
	UNIT_THREAT_SITUATION_UPDATE = UpdateThreat,
	UNIT_NAME_UPDATE = UpdateName,
	UNIT_HEAL_PREDICTION = UpdatePrediction,
	UNIT_ABSORB_AMOUNT_CHANGED = UpdatePrediction,
	UNIT_HEAL_ABSORB_AMOUNT_CHANGED = UpdatePrediction,
}

local globalEvents = {
	PLAYER_TARGET_CHANGED = UpdateTarget,
	PLAYER_ROLES_ASSIGNED = UpdateRole,
	GROUP_ROSTER_UPDATE = UpdateAll,
}

local function OnEvent(cell, event)
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
		return
	end
	for _, container in ipairs(cell.auraContainers) do
		container:SetUnit(unit)
	end
	for event in pairs(unitEvents) do
		cell:RegisterUnitEvent(event, unit)
	end
	for event in pairs(globalEvents) do
		cell:RegisterEvent(event)
	end
	UpdateAll(cell)
end

local function OnAttributeChanged(cell, name, value)
	if name == "unit" and value ~= cell.unit then
		SetUnit(cell, value)
	end
end

local ICON_SPACING = 2

local function StyleIcon(icon, size)
	icon:SetSize(size, size)

	icon.texture = icon:CreateTexture(nil, "ARTWORK")
	icon.texture:SetAllPoints()
	icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
	icon.cooldown:SetAllPoints()
	icon.cooldown:SetReverse(true)
	icon.cooldown:SetDrawEdge(false)
	icon.cooldown:SetHideCountdownNumbers(true)

	icon.count = ns.CreateFontString(icon, 9, "RIGHT")
	icon.count:SetPoint("BOTTOMRIGHT", 1, -1)

	ns.CreateBorder(icon)
end

local function CreatePreviewIcon(cell, anchorPoint, offsetX, offsetY, size)
	local icon = CreateFrame("Frame", nil, cell.health)
	icon:SetPoint(anchorPoint, cell.health, anchorPoint, offsetX, offsetY)
	icon:SetFrameLevel(cell.health:GetFrameLevel() + 2)
	StyleIcon(icon, size)
	icon:Hide()
	return icon
end

-- Runs once per button before Blizzard locks it against tainted access while
-- auras are secret, so this is the only place our code may touch it.
local function AuraButtonInitializer(size)
	return function(button)
		button:EnableMouse(false)
		StyleIcon(button, size)
		button:SetIcon(button.texture)
		button:SetDurationCooldown(button.cooldown)
		button:SetApplicationCount(button.count)
	end
end

-- Addon code can't read other units' auras in combat (the queries error once
-- they turn secret), so Blizzard's secure container reads and tracks them and
-- only fills in the elements we hand it. `anchorPoint` is the cell corner or
-- edge the icons start from (e.g. "LEFT", "TOPLEFT").
local function CreateAuraGroup(cell, key, filter, anchorPoint, offsetX, offsetY, growth, count, size)
	local container = CreateFrame("AuraContainer", nil, cell.health, "CustomAuraContainerTemplate")
	container:SetFrameLevel(cell.health:GetFrameLevel() + 2)
	container:SetPoint(anchorPoint, cell.health, anchorPoint, offsetX, offsetY)
	container:SetEditModePreviewEnabled(false)
	local flowAnchor = anchorPoint:find("TOP") and anchorPoint or ("TOP" .. anchorPoint)
	container:SetFlowLayoutAnchorPoint(flowAnchor)
	container:SetFlowLayoutGrowthDirection(growth, AnchorUtil.FlowDirection.Down)
	container:AddAuraGroup(key, filter, {
		maxFrameCount = count,
		layout = { elementSpacing = ICON_SPACING },
		initializeFrame = AuraButtonInitializer(size),
	})
	container:SetEnabled(true)
	return container
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

	ns.CreateBackground(cell)
	cell.border = ns.CreateBorder(cell, 0)
	cell.aggroBorder = ns.CreateBorder(cell, 1)
	cell.aggroBorder:SetColor(unpack(config.aggroColor))
	cell.aggroBorder:SetShown(false)
	cell.targetBorder = ns.CreateBorder(cell, 2)
	cell.targetBorder:SetColor(unpack(config.targetColor))
	cell.targetBorder:SetShown(false)

	cell.power = ns.CreateStatusBar(cell)
	cell.power:SetPoint("BOTTOMLEFT")
	cell.power:SetPoint("BOTTOMRIGHT")
	cell.power:SetHeight(config.powerHeight)

	cell.health = ns.CreateStatusBar(cell)
	cell.health:SetPoint("TOPLEFT")
	cell.health:SetPoint("BOTTOMRIGHT", cell.power, "TOPRIGHT", 0, px)

	local separator = cell:CreateTexture(nil, "ARTWORK")
	separator:SetColorTexture(unpack(style.borderColor))
	separator:SetPoint("BOTTOMLEFT", cell.power, "TOPLEFT")
	separator:SetPoint("BOTTOMRIGHT", cell.power, "TOPRIGHT")
	separator:SetHeight(px)

	-- Drawn on the health bar right above its fill, so every icon covers it.
	cell.nameText = cell.health:CreateFontString(nil, "ARTWORK", nil, 7)
	cell.nameText:SetFont(style.font, config.nameFontSize, "")
	cell.nameText:SetTextColor(unpack(config.nameColor))
	cell.nameText:SetPoint("LEFT", 2, 0)
	cell.nameText:SetPoint("RIGHT", -2, 0)
	cell.nameText:SetWordWrap(false)

	-- Field names are what Blizzard's role icon delegate reads from the frame.
	cell.roleIcon = cell.health:CreateTexture(nil, "OVERLAY")
	cell.roleIcon:SetSize(config.roleIconSize, config.roleIconSize)
	cell.roleIcon:SetPoint("CENTER", cell.health)
	cell.roleIcon:Hide()
	cell.optionTable = { displayRoleIcon = true }
end

-- Plain frames the /sui test preview fills with fake debuffs and HoTs.
function ns.BuildGroupPreviewIcons(cell)
	local step = config.iconSize + ICON_SPACING
	cell.leftIcons, cell.rightIcons, cell.ownIcons = {}, {}, {}
	for i = 1, config.iconsPerSide do
		cell.leftIcons[i] = CreatePreviewIcon(cell, "LEFT", 2 + (i - 1) * step, 0, config.iconSize)
		cell.rightIcons[i] = CreatePreviewIcon(cell, "RIGHT", -2 - (i - 1) * step, 0, config.iconSize)
	end
	local ownStep = config.ownAuraSize + ICON_SPACING
	for i = 1, config.ownAurasMax do
		cell.ownIcons[i] = CreatePreviewIcon(cell, "TOPLEFT", 2 + (i - 1) * ownStep, -2, config.ownAuraSize)
	end
end

-- Called from the XML template's OnLoad; the cell size lives in Cell.xml
-- because the secure header may create cells in combat, where Lua can't resize them.
function ns.InitGroupCell(cell)
	ns.BuildGroupCell(cell)
	CreatePrediction(cell)
	local Flow = AnchorUtil.FlowDirection
	cell.auraContainers = {
		CreateAuraGroup(
			cell,
			"dispellable",
			config.dispellableFilter,
			"LEFT",
			2,
			0,
			Flow.Right,
			config.iconsPerSide,
			config.iconSize
		),
		CreateAuraGroup(
			cell,
			"other",
			config.otherFilter,
			"RIGHT",
			-2,
			0,
			Flow.Left,
			config.iconsPerSide,
			config.iconSize
		),
		CreateAuraGroup(
			cell,
			"own",
			config.ownAuraFilter,
			"TOPLEFT",
			2,
			-2,
			Flow.Right,
			config.ownAurasMax,
			config.ownAuraSize
		),
	}
	cell:SetScript("OnEvent", OnEvent)
	cell:HookScript("OnAttributeChanged", OnAttributeChanged)
	cell:HookScript("OnShow", UpdateAll)
end
