local _, ns = ...

local config = ns.config.units
local style = ns.config.style

local Units = ns:RegisterModule("units", {})
Units.frames = {}

-- Health, power and names may be secret values in combat. They can be passed
-- straight into widgets, but never compared or used in arithmetic.

local function UpdateHealth(frame)
	local unit = frame.unit
	frame.health:SetMinMaxValues(0, UnitHealthMax(unit))
	frame.health:SetValue(UnitHealth(unit))
end

local function UpdateHealthColor(frame)
	frame.health:SetStatusBarColor(ns.UnitHealthColor(frame.unit))
end

local function UpdatePower(frame)
	if not frame.power then
		return
	end
	local unit = frame.unit
	frame.power:SetMinMaxValues(0, UnitPowerMax(unit))
	frame.power:SetValue(UnitPower(unit))
end

local function UpdatePowerColor(frame)
	if frame.power then
		frame.power:SetStatusBarColor(ns.UnitPowerColor(frame.unit))
	end
end

local function UpdateName(frame)
	if not frame.name then
		return
	end
	local unit = frame.unit
	frame.name:SetText(UnitName(unit))

	local level = UnitLevel(unit)
	if issecretvalue(level) then
		frame.level:SetText(level)
	elseif level and level > 0 then
		local color = GetCreatureDifficultyColor(level)
		frame.level:SetText(level)
		frame.level:SetTextColor(color.r, color.g, color.b)
	else
		frame.level:SetText("??")
		frame.level:SetTextColor(1, 0.2, 0.2)
	end
end

local function UpdateCombat(frame)
	if frame.combatIcon then
		frame.combatIcon:SetShown(UnitAffectingCombat(frame.unit))
	end
end

local function UpdateAll(frame)
	if not UnitExists(frame.unit) then
		return
	end
	UpdateHealth(frame)
	UpdateHealthColor(frame)
	UpdatePower(frame)
	UpdatePowerColor(frame)
	UpdateName(frame)
	UpdateCombat(frame)
end

local eventUpdaters = {
	-- Dying or resurrecting only fires health events, and those change the color too.
	UNIT_HEALTH = function(frame)
		UpdateHealth(frame)
		UpdateHealthColor(frame)
	end,
	UNIT_MAXHEALTH = UpdateHealth,
	UNIT_POWER_UPDATE = UpdatePower,
	UNIT_MAXPOWER = UpdatePower,
	UNIT_DISPLAYPOWER = function(frame)
		UpdatePowerColor(frame)
		UpdatePower(frame)
	end,
	UNIT_FACTION = UpdateHealthColor,
	UNIT_CONNECTION = UpdateHealthColor,
	UNIT_FLAGS = UpdateHealthColor,
	UNIT_NAME_UPDATE = UpdateName,
	UNIT_LEVEL = UpdateName,
	PLAYER_REGEN_DISABLED = UpdateCombat,
	PLAYER_REGEN_ENABLED = UpdateCombat,
}

local function OnEvent(frame, event)
	local updater = eventUpdaters[event]
	if updater then
		updater(frame)
	else
		UpdateAll(frame)
	end
end

local function OnPollUpdate(frame, elapsed)
	frame.elapsed = (frame.elapsed or 0) + elapsed
	if frame.elapsed >= config.pollInterval then
		frame.elapsed = 0
		UpdateAll(frame)
	end
end

local function CreateUnitFrame(spec)
	local unit = spec.unit
	local hasPower = spec.powerHeight > 0
	local frame = CreateFrame("Button", "StevioUI_" .. unit, UIParent, "SecureUnitButtonTemplate")
	frame.unit = unit
	local px = ns.PixelSize(frame)

	frame:SetSize(spec.width, spec.healthHeight + (hasPower and spec.powerHeight + px or 0))
	frame:SetAttribute("unit", unit)
	frame:SetAttribute("*type1", "target")
	frame:SetAttribute("*type2", "togglemenu")
	frame:RegisterForClicks("AnyUp")

	ns.CreateBackground(frame)
	frame.border = ns.CreateBorder(frame)

	frame.health = ns.CreateStatusBar(frame)
	frame.health:SetPoint("TOPLEFT")
	frame.health:SetPoint("TOPRIGHT")
	frame.health:SetHeight(spec.healthHeight)

	if hasPower then
		frame.power = ns.CreateStatusBar(frame)
		frame.power:SetPoint("BOTTOMLEFT")
		frame.power:SetPoint("BOTTOMRIGHT")
		frame.power:SetHeight(spec.powerHeight)

		-- A border-colored line between the bars instead of a gap keeps the frame one solid block.
		local separator = frame:CreateTexture(nil, "ARTWORK")
		separator:SetColorTexture(unpack(style.borderColor))
		separator:SetPoint("TOPLEFT", frame.health, "BOTTOMLEFT")
		separator:SetPoint("TOPRIGHT", frame.health, "BOTTOMRIGHT")
		separator:SetHeight(px)
	end

	if spec.showName then
		frame.level = ns.CreateFontString(frame)
		frame.level:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 4)
		frame.name = ns.CreateFontString(frame)
		frame.name:SetPoint("LEFT", frame.level, "RIGHT", 4, 0)
		frame.name:SetPoint("RIGHT", frame, "RIGHT")
	end

	if spec.showCombat then
		-- Sits on the name row, at the opposite end from level and name.
		frame.combatIcon = frame:CreateTexture(nil, "OVERLAY")
		frame.combatIcon:SetAtlas("UI-HUD-UnitFrame-Player-CombatIcon")
		frame.combatIcon:SetSize(config.combatIconSize, config.combatIconSize)
		frame.combatIcon:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 2)
		frame.combatIcon:Hide()
		if frame.name then
			frame.name:SetPoint("RIGHT", frame.combatIcon, "LEFT", -4, 0)
		end
	end

	if spec.anchorTo then
		frame:SetPoint("TOP" .. spec.align, Units.frames[spec.anchorTo], "BOTTOM" .. spec.align, 0, -spec.gap)
	else
		ns.SetPoint(frame, ns.layout[unit])
	end

	if unit == "targettarget" then
		frame:SetScript("OnUpdate", OnPollUpdate)
	else
		for event in pairs(eventUpdaters) do
			if event:find("^UNIT_") then
				frame:RegisterUnitEvent(event, unit)
			end
		end
		if spec.showCombat then
			frame:RegisterEvent("PLAYER_REGEN_DISABLED")
			frame:RegisterEvent("PLAYER_REGEN_ENABLED")
		end
		if unit == "target" then
			frame:RegisterEvent("PLAYER_TARGET_CHANGED")
		elseif unit == "pet" then
			frame:RegisterUnitEvent("UNIT_PET", "player")
		end
		frame:SetScript("OnEvent", OnEvent)
	end

	-- Unit watch toggles visibility securely, so frames appear even mid-combat.
	-- New frames start out shown, so OnShow never fires for units that already
	-- exist (player, an active pet); those need an explicit first update.
	frame:SetScript("OnShow", UpdateAll)
	RegisterUnitWatch(frame)
	UpdateAll(frame)

	return frame
end

local function HideBlizzardFrames()
	-- PlayerFrame keeps its events: vehicle and class-bar code still reads its state.
	ns.HideBlizzard(PlayerFrame, true)
	ns.HideBlizzard(TargetFrame)
	ns.HideBlizzard(FocusFrame)
	ns.HideBlizzard(PetFrame)
	ns.HideBlizzard(PartyFrame)
	ns.HideBlizzard(PlayerCastingBarFrame)
	ns.HideBlizzard(PetCastingBarFrame)
end

function Units:OnEnable()
	HideBlizzardFrames()

	for _, spec in ipairs(config.frames) do
		self.frames[spec.unit] = CreateUnitFrame(spec)
	end

	ns.CreateClassPower(self.frames.player)
	ns.CreateCastBar("player", self.frames.player, self.frames.pet, "RIGHT")
	ns.CreateCastBar("target", self.frames.target, self.frames.targettarget, "LEFT")
end
