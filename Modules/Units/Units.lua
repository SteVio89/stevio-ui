local _, ns = ...

local config = ns.config.units
local style = ns.config.style

-- Game API called on every unit event, as upvalues.
local UnitExists, UnitName, UnitLevel = UnitExists, UnitName, UnitLevel
local UnitHealthPercent, UnitAffectingCombat = UnitHealthPercent, UnitAffectingCombat
local issecretvalue = issecretvalue

local Units = ns.RegisterModule("units", {})
Units.frames = {}

-- Unit changes that come with their own event; shared with the cast bars.
ns.UNIT_CHANGE_EVENTS = {
	target = "PLAYER_TARGET_CHANGED",
	focus = "PLAYER_FOCUS_CHANGED",
}

-- Health, power and names may be secret values in combat. They can be passed
-- straight into widgets, but never compared or used in arithmetic.

-- "12.3k · 87%" with a muted dot, built once the palette is known.
local healthFormat

-- Health and its percentage may be secret, so both go straight into the font
-- string, abbreviated and scaled by the client.
local function UpdateHealth(frame)
	local unit = frame.unit
	local health = ns.UpdateHealthBar(frame.health, unit)
	frame.healthText:SetFormattedText(
		healthFormat,
		AbbreviateNumbers(health),
		UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
	)
end

-- The color may be secret; both setters take it as it is.
local function UpdateHealthColor(frame)
	local r, g, b = ns.UnitHealthColor(frame.unit)
	frame.health:SetStatusBarColor(r, g, b)
	ns.SetTrackColor(frame.healthTrack, r, g, b)
end

local function UpdatePower(frame)
	if frame.power then
		ns.UpdatePowerBar(frame.power, frame.unit)
	end
end

local function UpdatePowerColor(frame)
	if frame.power then
		ns.SetPowerBarColor(frame.power, frame.unit)
	end
end

local function UpdatePowerType(frame)
	if frame.power then
		ns.UpdatePowerType(frame.power, frame.unit)
	end
end

-- The level text and its color: the difficulty color, a red "??" for unknown
-- levels (bosses), or white for a secret level, which can't be compared.
function Units.LevelDisplay(level, isSecret, difficultyColor)
	if isSecret then
		return level, 1, 1, 1
	elseif level and level > 0 then
		local color = difficultyColor(level)
		return level, color.r, color.g, color.b
	end
	return "??", 1, 0.2, 0.2
end

local function UpdateName(frame)
	if not frame.name then
		return
	end
	local unit = frame.unit
	frame.name:SetText(UnitName(unit))

	local level = UnitLevel(unit)
	local text, r, g, b = Units.LevelDisplay(level, issecretvalue(level), GetCreatureDifficultyColor)
	frame.level:SetText(text)
	-- Your own level says nothing about difficulty, so it stays in the background.
	if unit == "player" then
		r, g, b = unpack(style.palette.textMuted)
	end
	frame.level:SetTextColor(r, g, b)
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
	UNIT_DISPLAYPOWER = UpdatePowerType,
	UNIT_FACTION = UpdateHealthColor,
	UNIT_CONNECTION = UpdateHealthColor,
	UNIT_FLAGS = UpdateHealthColor,
	-- The name arriving may also mean the class is now known (CompactUnitFrame).
	UNIT_NAME_UPDATE = function(frame)
		UpdateName(frame)
		UpdateHealthColor(frame)
	end,
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

-- Returns nil for a frame that has nowhere to go: anchored to a unit missing
-- from the list (the options panel can remove entries) and without a layout
-- position of its own.
local function CreateUnitFrame(spec)
	local unit = spec.unit
	local anchor = spec.anchorTo and Units.frames[spec.anchorTo]
	if not anchor and not ns.layout[unit] then
		return nil
	end
	local hasPower = spec.powerHeight > 0
	local frame = CreateFrame("Button", "StevioUI_" .. unit, UIParent, "SecureUnitButtonTemplate")
	frame.unit = unit
	local px = ns.PixelSize(frame)

	frame:SetSize(spec.width, spec.healthHeight + (hasPower and spec.powerHeight + px or 0))
	frame:SetAttribute("unit", unit)
	frame:SetAttribute("*type1", "target")
	frame:SetAttribute("*type2", "togglemenu")
	frame:RegisterForClicks("AnyUp")

	ns.CreatePanel(frame)

	frame.health = ns.CreateStatusBar(frame)
	frame.health:SetPoint("TOPLEFT")
	frame.health:SetPoint("TOPRIGHT")
	frame.health:SetHeight(spec.healthHeight)
	frame.healthTrack = ns.CreateTintedTrack(frame.health)
	ns.CreateBarShade(frame.health)

	-- On the bright bar the outline stays, for contrast.
	frame.healthText = ns.CreateFontString(frame.health, spec.healthTextSize, "RIGHT", true)
	frame.healthText:SetPoint("RIGHT", -3, 0)

	if hasPower then
		frame.power = ns.CreateStatusBar(frame)
		frame.power:SetPoint("BOTTOMLEFT")
		frame.power:SetPoint("BOTTOMRIGHT")
		frame.power:SetHeight(spec.powerHeight)
		ns.CreateBarShade(frame.power, true)
		ns.CreateSeparator(frame, "TOP", frame.health, "BOTTOM")
	end

	if spec.showName then
		local nameSize = style.fontSize + 1
		frame.level = ns.CreateFontString(frame, nameSize)
		frame.level:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 4)
		frame.name = ns.CreateFontString(frame, nameSize)
		frame.name:SetTextColor(unpack(style.palette.textStrong))
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

	if anchor then
		frame:SetPoint("TOP" .. spec.align, anchor, "BOTTOM" .. spec.align, 0, -spec.gap)
	else
		ns.SetPoint(frame, ns.LayoutPosition(unit))
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
		if ns.UNIT_CHANGE_EVENTS[unit] then
			frame:RegisterEvent(ns.UNIT_CHANGE_EVENTS[unit])
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
	ns.HideBlizzard(PlayerCastingBarFrame)
	ns.HideBlizzard(PetCastingBarFrame)
end

function Units:OnEnable()
	HideBlizzardFrames()
	healthFormat = "%s " .. ns.Hex(style.palette.textMuted) .. "·|r %d%%"

	for _, spec in ipairs(config.frames) do
		self.frames[spec.unit] = CreateUnitFrame(spec)
	end

	-- Any of these may have been removed from the list in the options panel;
	-- a cast bar then sits below the unit's own frame instead.
	local frames = self.frames
	if frames.player then
		ns.CreateClassPower(frames.player)
		ns.CreateCastBar("player", frames.player, frames.pet or frames.player, "RIGHT")
	end
	if frames.target then
		ns.CreateCastBar("target", frames.target, frames.targettarget or frames.target, "LEFT")
	end
	if self.frames.focus then
		ns.CreateCastBar("focus", self.frames.focus, self.frames.focus, "RIGHT", {
			height = config.castBar.focusHeight,
			fontSize = config.castBar.focusFontSize,
		})
	end
	ns.CreateTargetAuras()
end
