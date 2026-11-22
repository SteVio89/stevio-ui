local _, ns = ...

local config = ns.config.units.classPower

local COMBO_POINTS = Enum.PowerType.ComboPoints

-- Where combo points live. In the game type that loads Blizzard's
-- TargetBoundComboPointBar (WoW Forever), they are stored on the target: they
-- follow target changes and are read with GetComboPoints, and moving them to
-- a new target fires COMBO_TARGET_CHANGED instead of a power event. Elsewhere
-- they are the player's power.
local targetBound = TargetBoundComboPointBarMixin ~= nil and GetComboPoints ~= nil

local function ComboPoints()
	if targetBound then
		return GetComboPoints("player", "target")
	end
	return UnitPower("player", COMBO_POINTS)
end

local function UsesComboPoints()
	local _, class = UnitClass("player")
	if class == "ROGUE" then
		return true
	end
	return class == "DRUID" and UnitPowerType("player") == Enum.PowerType.Energy
end

-- Each segment covers the range (i-1, i) and receives the full combo point
-- value, so the client decides fill state and a secret value is never compared.
local function Update(container)
	local points = ComboPoints()
	for _, segment in ipairs(container.segments) do
		segment:SetValue(points)
	end
end

local function UpdateVisibility(container)
	container:SetShown(UsesComboPoints())
	Update(container)
end

local function OnEvent(container, event, _, powerToken)
	if event == "UNIT_POWER_FREQUENT" then
		if powerToken == "COMBO_POINTS" then
			Update(container)
		end
	elseif event == "PLAYER_TARGET_CHANGED" or event == "COMBO_TARGET_CHANGED" then
		Update(container)
	else
		UpdateVisibility(container)
	end
end

function ns.CreateClassPower(playerFrame)
	local container = CreateFrame("Frame", nil, UIParent)
	container:SetPoint("TOPLEFT", playerFrame, "BOTTOMLEFT", 0, -config.gap)
	container:SetPoint("TOPRIGHT", playerFrame, "BOTTOMRIGHT", 0, -config.gap)
	container:SetHeight(config.height)

	local color = PowerBarColor.COMBO_POINTS
	local width = (playerFrame:GetWidth() - config.spacing * (config.max - 1)) / config.max
	container.segments = {}
	for i = 1, config.max do
		local segment = ns.CreateStatusBar(container)
		segment:SetSize(width, config.height)
		segment:SetPoint("LEFT", (i - 1) * (width + config.spacing), 0)
		segment:SetMinMaxValues(i - 1, i)
		segment:SetStatusBarColor(color.r, color.g, color.b)
		ns.CreateBackground(segment)
		ns.CreateBorder(segment)
		container.segments[i] = segment
	end

	-- Like Blizzard's class resource bars: the frequent event, without a delay.
	container:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
	container:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
	container:RegisterEvent("PLAYER_ENTERING_WORLD")
	if targetBound then
		container:RegisterEvent("PLAYER_TARGET_CHANGED")
		container:RegisterEvent("COMBO_TARGET_CHANGED")
	end
	container:SetScript("OnEvent", OnEvent)
	UpdateVisibility(container)
end
