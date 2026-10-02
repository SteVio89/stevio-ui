local _, ns = ...

local config = ns.config.units.classPower

local COMBO_POINTS = Enum.PowerType.ComboPoints

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
	local points = UnitPower("player", COMBO_POINTS)
	for _, segment in ipairs(container.segments) do
		segment:SetValue(points)
	end
end

local function UpdateVisibility(container)
	container:SetShown(UsesComboPoints())
	Update(container)
end

local function OnEvent(container, event, _, powerToken)
	if event == "UNIT_POWER_UPDATE" then
		if powerToken == "COMBO_POINTS" then
			Update(container)
		end
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

	container:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
	container:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
	container:RegisterEvent("PLAYER_ENTERING_WORLD")
	container:SetScript("OnEvent", OnEvent)
	UpdateVisibility(container)

	return container
end
