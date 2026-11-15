local _, ns = ...

local config = ns.config.marks
local style = ns.config.style
local Symbols = ns.MarkSymbols

local Marks = ns.RegisterModule("marks", {})

local bar
local buttons = {}
-- Whether this game version has ground markers at all (Blizzard hides its own
-- ground marker menu otherwise).
local groundMarkers = false

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
		-- The clear button is dimmed while the target has no symbol to clear
		-- (its right click, all ground markers, still works).
		local dimmed
		if index then
			dimmed = not usable
		else
			dimmed = not current
		end
		button.icon:SetAlpha(dimmed and config.unusableAlpha or 1)
	end
end

local function UpdateGroundMarks()
	for _, button in ipairs(buttons) do
		if button.ground then
			local placed = IsRaidMarkerActive(button.symbol.world)
			if issecretvalue(placed) then
				button.ground:Show()
				button.ground:SetAlphaFromBoolean(placed, 1, 0)
			else
				button.ground:SetAlpha(1)
				button.ground:SetShown(placed)
			end
		end
	end
end

local function ShowTooltip(button)
	GameTooltip:SetOwner(button, "ANCHOR_BOTTOMRIGHT")
	if button.symbol then
		GameTooltip:SetText(ns.T(button.symbol.name[1], button.symbol.name[2]))
		GameTooltip:AddLine(ns.T("Left click: mark the target", "Linksklick: Ziel markieren"), 1, 1, 1)
		if groundMarkers then
			GameTooltip:AddLine(
				ns.T(
					"Right click: place or remove the ground marker",
					"Rechtsklick: Bodenmarkierung setzen oder entfernen"
				),
				1,
				1,
				1
			)
		end
	else
		GameTooltip:SetText(ns.T("Clear", "Entfernen"))
		GameTooltip:AddLine(
			ns.T("Left click: unmark the target", "Linksklick: Markierung des Ziels entfernen"),
			1,
			1,
			1
		)
		if groundMarkers then
			GameTooltip:AddLine(
				ns.T("Right click: remove all ground markers", "Rechtsklick: alle Bodenmarkierungen entfernen"),
				1,
				1,
				1
			)
		end
	end
	GameTooltip:Show()
end

-- Marking a unit and placing ground markers are protected, so the buttons
-- are secure: left click runs Blizzard's "raidtarget" action on the target,
-- right click its "worldmarker" action (which then waits for a click on the ground).
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

	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:SetAttribute("unit", "target")
	button:SetAttribute("type1", "raidtarget")
	if symbol then
		button.symbol = symbol
		button.icon:SetTexture(Symbols.Texture(symbol.index))
		button:SetAttribute("action1", "toggle")
		button:SetAttribute("marker1", symbol.index)
	else
		-- No symbol: a cross that clears.
		button.icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
		button:SetAttribute("action1", "clear")
	end

	if groundMarkers then
		button:SetAttribute("type2", "worldmarker")
		if symbol then
			button:SetAttribute("action2", "toggle")
			button:SetAttribute("marker2", symbol.world)
			button.ground = button:CreateTexture(nil, "OVERLAY", nil, 2)
			button.ground:SetSize(5, 5)
			button.ground:SetPoint("BOTTOMRIGHT", -1, 1)
			button.ground:SetColorTexture(unpack(config.groundColor))
			button.ground:Hide()
		else
			-- Without a marker index, "clear" removes all ground markers.
			button:SetAttribute("action2", "clear")
		end
	end

	-- After Blizzard's click handler: the target's mark changes with
	-- RAID_TARGET_UPDATE, ground markers show up with the next refresh.
	button:HookScript("OnEnter", ShowTooltip)
	button:HookScript("OnLeave", GameTooltip_Hide)
	buttons[#buttons + 1] = button
	return button
end

function Marks:OnEnable()
	groundMarkers = IsRaidMarkerSystemEnabled ~= nil and IsRaidMarkerSystemEnabled() == true

	bar = CreateFrame("Frame", "StevioUI_MarkBar", UIParent)
	local count = #Symbols.LIST + 1
	bar:SetSize(count * config.buttonSize + (count - 1) * config.buttonGap, config.buttonSize)
	ns.SetPoint(bar, ns.layout.marks)

	for position, symbol in ipairs(Symbols.LIST) do
		CreateButton(position, symbol)
	end
	CreateButton(count, nil)

	ns.RegisterEvent("PLAYER_TARGET_CHANGED", UpdateTargetMarks)
	ns.RegisterEvent("RAID_TARGET_UPDATE", UpdateTargetMarks)
	UpdateTargetMarks()

	if groundMarkers then
		C_Timer.NewTicker(config.groundRefresh, UpdateGroundMarks)
		UpdateGroundMarks()
	end
end
