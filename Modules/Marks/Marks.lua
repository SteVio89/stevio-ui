local _, ns = ...

local config = ns.config.marks
local style = ns.config.style
local Symbols = ns.MarkSymbols

local Marks = ns.RegisterModule("marks", {})

local bar
local buttons = {}

local function CanMark()
	return UnitExists("target") and CanBeRaidTarget("target")
end

-- The target's symbol, or nil when it has none or the game keeps it secret.
local function TargetSymbol()
	local index = GetRaidTargetIndex("target")
	if issecretvalue(index) then
		return nil
	end
	return index
end

local function UpdateTargetMarks()
	local usable = CanMark()
	local current = TargetSymbol()
	for _, button in ipairs(buttons) do
		local index = button.symbol and button.symbol.index
		local active = index ~= nil and index == current
		button.active:SetShown(active)
		-- The clear button is dimmed while the target has no symbol to clear.
		local dimmed
		if index then
			dimmed = not usable
		else
			dimmed = not current
		end
		button.icon:SetAlpha(dimmed and config.unusableAlpha or 1)
	end
end

local function ShowTooltip(button)
	-- The default position, above the toolbar (Modules/Tooltip).
	GameTooltip_SetDefaultAnchor(GameTooltip, button)
	if button.symbol then
		GameTooltip:SetText(ns.T(button.symbol.name[1], button.symbol.name[2]))
		GameTooltip:AddLine(ns.T("Left click: mark the target", "Linksklick: Ziel markieren"), 1, 1, 1)
	else
		GameTooltip:SetText(ns.T("Clear", "Entfernen"))
		GameTooltip:AddLine(
			ns.T("Left click: unmark the target", "Linksklick: Markierung des Ziels entfernen"),
			1,
			1,
			1
		)
	end
	GameTooltip:Show()
end

-- Marking a unit is protected, so the buttons are secure, set up by
-- Symbols.Attributes.
local function CreateButton(position, symbol)
	local button = CreateFrame("Button", "StevioUI_Mark" .. position, bar, "SecureActionButtonTemplate")
	button:SetSize(config.buttonSize, config.buttonSize)
	button:SetPoint("LEFT", (position - 1) * (config.buttonSize + config.buttonGap), 0)
	ns.CreateBackground(button)
	ns.CreateBorder(button)
	button.active = ns.CreateBorder(button, 1, 2)
	button.active:SetColor(unpack(config.activeColor))
	button.active:SetShown(false)

	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetPoint("TOPLEFT", 2, -2)
	button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
	button:SetHighlightTexture(style.texture)
	button:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.15)

	button:RegisterForClicks("LeftButtonUp")
	for name, value in pairs(Symbols.Attributes(symbol)) do
		button:SetAttribute(name, value)
	end
	if symbol then
		button.symbol = symbol
		button.icon:SetTexture(Symbols.Texture(symbol.index))
	else
		-- No symbol: a cross that clears.
		button.icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
	end

	-- The target's mark changes with RAID_TARGET_UPDATE.
	button:HookScript("OnEnter", ShowTooltip)
	button:HookScript("OnLeave", GameTooltip_Hide)
	buttons[#buttons + 1] = button
	return button
end

function Marks:OnEnable()
	bar = CreateFrame("Frame", "StevioUI_MarkBar", UIParent)
	local count = #Symbols.LIST + 1
	bar:SetSize(count * config.buttonSize + (count - 1) * config.buttonGap, config.buttonSize)
	-- The map's corner stand-in stays put while the map is in the strip view.
	ns.SetPoint(bar, ns.layout.marks, ns.minimapCorner or Minimap)

	for position, symbol in ipairs(Symbols.LIST) do
		CreateButton(position, symbol)
	end
	CreateButton(count, nil)

	ns.RegisterEvent("PLAYER_TARGET_CHANGED", UpdateTargetMarks)
	ns.RegisterEvent("RAID_TARGET_UPDATE", UpdateTargetMarks)
	UpdateTargetMarks()
end
