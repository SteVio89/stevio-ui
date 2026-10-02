local _, ns = ...

local config = ns.config.group
local style = ns.config.style

local function UpdateHealth(cell)
	local unit = cell.unit
	cell.health:SetMinMaxValues(0, UnitHealthMax(unit))
	cell.health:SetValue(UnitHealth(unit))
	cell.health:SetStatusBarColor(ns.UnitHealthColor(unit))
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

local function UpdateIconSide(cell, icons, filter)
	local unit = cell.unit
	local auras = C_UnitAuras.GetUnitAuras(unit, filter, #icons)
	for i, icon in ipairs(icons) do
		local aura = auras[i]
		if aura then
			icon.texture:SetTexture(aura.icon)
			local id = aura.auraInstanceID
			local duration = not issecretvalue(id) and C_UnitAuras.GetAuraDuration(unit, id)
			if duration and not issecretvalue(duration) then
				icon.count:SetText(C_UnitAuras.GetAuraApplicationDisplayCount(unit, id))
				icon.cooldown:SetCooldownFromDurationObject(duration)
			else
				icon.count:SetText("")
				icon.cooldown:Clear()
			end
			icon:Show()
		else
			icon:Hide()
		end
	end
end

local function UpdateAuras(cell)
	UpdateIconSide(cell, cell.leftIcons, config.dispellableFilter)
	UpdateIconSide(cell, cell.rightIcons, config.otherFilter)
end

local function UpdateAll(cell)
	if not cell.unit or not UnitExists(cell.unit) then
		return
	end
	UpdateHealth(cell)
	UpdatePower(cell)
	UpdatePowerColor(cell)
	UpdateRange(cell)
	UpdateTarget(cell)
	UpdateThreat(cell)
	UpdateAuras(cell)
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
	UNIT_AURA = UpdateAuras,
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

local function CreateIcon(cell, anchorPoint, offsetX)
	local icon = CreateFrame("Frame", nil, cell.health)
	icon:SetSize(config.iconSize, config.iconSize)
	icon:SetPoint(anchorPoint, cell.health, anchorPoint, offsetX, 0)
	icon:SetFrameLevel(cell.health:GetFrameLevel() + 2)

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
	icon:Hide()
	return icon
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

	-- Field names are what Blizzard's role icon delegate reads from the frame.
	cell.roleIcon = cell.health:CreateTexture(nil, "OVERLAY")
	cell.roleIcon:SetSize(config.roleIconSize, config.roleIconSize)
	cell.roleIcon:SetPoint("CENTER", cell.health)
	cell.roleIcon:Hide()
	cell.optionTable = { displayRoleIcon = true }

	local step = config.iconSize + 2
	cell.leftIcons, cell.rightIcons = {}, {}
	for i = 1, config.iconsPerSide do
		cell.leftIcons[i] = CreateIcon(cell, "LEFT", 2 + (i - 1) * step)
		cell.rightIcons[i] = CreateIcon(cell, "RIGHT", -2 - (i - 1) * step)
	end
end

-- Called from the XML template's OnLoad; the cell size lives in Cell.xml
-- because the secure header may create cells in combat, where Lua can't resize them.
function ns.InitGroupCell(cell)
	ns.BuildGroupCell(cell)
	cell:SetScript("OnEvent", OnEvent)
	cell:HookScript("OnAttributeChanged", OnAttributeChanged)
	cell:HookScript("OnShow", UpdateAll)
end
