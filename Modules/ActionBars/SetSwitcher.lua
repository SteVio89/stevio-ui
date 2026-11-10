local _, ns = ...

-- Switches between the action sets named in config.sets (e.g. levelling and
-- healing), out of combat only. Leaving a set saves what its slots hold at
-- that moment, entering one puts its actions back into the same slots, so
-- every bar and page changes and every keybinding stays where it was.
-- Stored per character in StevioUIActionSets:
--   { current = index, sets = { [index] = { [slot] = entry } }, missing = { [slot] = entry } }
-- `missing` holds what the active set could not place (e.g. a talent spell
-- not known right now); it is kept for that set instead of being lost on the next switch.

local Sets = ns.ActionSets
local config = ns.config.actionBars
local style = ns.config.style
local T = ns.T

local state
local button

local PickupSpellByID = C_Spell and C_Spell.PickupSpell or PickupSpell
local PickupItemByID = C_Item and C_Item.PickupItem or PickupItem
local RANDOM_FAVORITE_MOUNT = 268435455

local function ReadSlot(slot)
	if not HasAction(slot) then
		return nil
	end
	local actionType, id, subType = GetActionInfo(slot)
	if not actionType or id == nil then
		return nil
	end
	local entry = { type = actionType, id = id, subType = subType }
	if actionType == "macro" then
		entry.name = GetActionText(slot)
	end
	return entry
end

local function Snapshot()
	local slots = {}
	for slot = 1, Sets.MAX_SLOT do
		slots[slot] = ReadSlot(slot)
	end
	return slots
end

local function FindFlyout(flyoutID)
	if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then
		return nil
	end
	local bank = Enum.SpellBookSpellBank.Player
	for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
		local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
		for index = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
			local item = C_SpellBook.GetSpellBookItemInfo(index, bank)
			if item and item.itemType == Enum.SpellBookItemType.Flyout and item.actionID == flyoutID then
				return index, bank
			end
		end
	end
	return nil
end

-- Puts an action on the cursor; the caller checks GetCursorInfo() for success.
local pickup = {
	spell = function(entry)
		PickupSpellByID(entry.id)
	end,
	item = function(entry)
		PickupItemByID(entry.id)
	end,
	macro = function(entry)
		local index = entry.name and GetMacroIndexByName(entry.name)
		PickupMacro((index and index > 0) and index or entry.id)
	end,
	equipmentset = function(entry)
		local id = entry.id
		if type(id) == "string" then
			id = C_EquipmentSet.GetEquipmentSetID(id)
		end
		C_EquipmentSet.PickupEquipmentSet(id)
	end,
	summonpet = function(entry)
		C_PetJournal.PickupPet(entry.id)
	end,
	summonmount = function(entry)
		if entry.id == RANDOM_FAVORITE_MOUNT then
			C_MountJournal.Pickup(0)
		else
			local _, spellID = C_MountJournal.GetMountInfoByID(entry.id)
			PickupSpellByID(spellID)
		end
	end,
	flyout = function(entry)
		local index, bank = FindFlyout(entry.id)
		if index then
			C_SpellBook.PickupSpellBookItem(index, bank)
		end
	end,
}

-- Makes every slot hold what `wanted` says; returns what could not be placed.
local function Apply(wanted)
	local missing = {}
	for _, change in ipairs(Sets.Changes(Snapshot(), wanted)) do
		ClearCursor()
		local placed = false
		local action = change.action
		if action then
			local fn = pickup[action.type]
			if fn then
				pcall(fn, action)
			end
			if GetCursorInfo() then
				PlaceAction(change.slot)
				placed = true
			end
		end
		ClearCursor()
		if not placed and HasAction(change.slot) then
			PickupAction(change.slot)
			ClearCursor()
		end
		if action and not placed then
			missing[change.slot] = action
		end
	end
	return missing
end

-- The active set as it stands now, plus what it could not place and still lacks.
local function SaveCurrent()
	local slots = Snapshot()
	for slot, entry in pairs(state.missing or {}) do
		if slots[slot] == nil then
			slots[slot] = entry
		end
	end
	state.sets[state.current] = slots
	state.missing = {}
end

local function CurrentName()
	return config.sets[state.current] or "?"
end

local function UpdateButton()
	if not button then
		return
	end
	button:SetShown(#config.sets > 1)
	button.text:SetText(CurrentName())
	button:SetAlpha(InCombatLockdown() and 0.4 or 1)
end

local function SwitchTo(index)
	if InCombatLockdown() then
		ns.Print(
			T(
				"Action sets can only be switched out of combat.",
				"Aktionsleisten-Sets lassen sich nur außerhalb des Kampfes wechseln."
			)
		)
		return
	end
	if GetCursorInfo() then
		ns.Print(T("Put down what is on the cursor first.", "Lege zuerst ab, was am Mauszeiger hängt."))
		return
	end
	if index == state.current then
		return
	end

	SaveCurrent()
	local previous = state.current
	state.current = index
	local wanted = state.sets[index]
	if not wanted then
		-- A set used for the first time starts as a copy of the bars as they are.
		state.sets[index] = CopyTable(state.sets[previous])
		ns.Print(
			T(
				"Action set %s is new and starts as a copy of your bars; changes to it are kept.",
				"Aktionsleisten-Set %s ist neu und beginnt als Kopie deiner Leisten; Änderungen bleiben erhalten."
			):format(CurrentName())
		)
	else
		state.missing = Apply(wanted)
		local count = 0
		for _ in pairs(state.missing) do
			count = count + 1
		end
		if count > 0 then
			ns.Print(
				T(
					"%d actions of %s could not be placed (not known right now); they are kept in the set.",
					"%d Aktionen von %s konnten nicht platziert werden (gerade nicht bekannt); sie bleiben im Set."
				):format(count, CurrentName())
			)
		end
	end
	UpdateButton()
end

function ns.NextActionSet()
	if state and #config.sets > 1 then
		SwitchTo(Sets.Next(state.current, #config.sets))
	end
end

local function PreviousActionSet()
	if state and #config.sets > 1 then
		SwitchTo(Sets.Previous(state.current, #config.sets))
	end
end

local function ShowTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:AddLine(T("Action sets", "Aktionsleisten-Sets"))
	for index, name in ipairs(config.sets) do
		local color = index == state.current and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR
		GameTooltip:AddLine(name, color.r, color.g, color.b)
	end
	GameTooltip:AddLine(
		T(
			"Click: next, right click: previous. Out of combat only.",
			"Klick: nächstes, Rechtsklick: vorheriges. Nur außerhalb des Kampfes."
		),
		0.6,
		0.6,
		0.6,
		true
	)
	GameTooltip:Show()
end

local function CreateButton()
	local b = CreateFrame("Button", "StevioUI_ActionSetButton", UIParent)
	b:SetSize(config.setButtonWidth, config.setButtonHeight)
	ns.SetPoint(b, ns.layout.actionSets)
	ns.CreateBackground(b)
	ns.CreateBorder(b)
	b.text = ns.CreateFontString(b, style.fontSize, "CENTER")
	b.text:SetPoint("LEFT", 2, 0)
	b.text:SetPoint("RIGHT", -2, 0)
	b:SetHighlightTexture(style.texture)
	b:GetHighlightTexture():SetVertexColor(1, 1, 1, config.highlightAlpha)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", function(self, mouseButton)
		if mouseButton == "RightButton" then
			PreviousActionSet()
		else
			ns.NextActionSet()
		end
		if GameTooltip:IsOwned(self) then
			ShowTooltip(self)
		end
	end)
	b:SetScript("OnEnter", ShowTooltip)
	b:SetScript("OnLeave", GameTooltip_Hide)
	return b
end

local function ListSets()
	for index, name in ipairs(config.sets) do
		ns.PrintLine(("%s %d  %s"):format(index == state.current and ">" or " ", index, name))
	end
end

function ns.CreateActionSetSwitcher()
	StevioUIActionSets = StevioUIActionSets or {}
	state = StevioUIActionSets
	state.sets = state.sets or {}
	state.missing = state.missing or {}
	if not config.sets[state.current or 0] then
		-- First use, or the set list got shorter: the bars as they are become the first set.
		state.current = 1
		state.missing = {}
	end

	button = CreateButton()
	UpdateButton()
	ns.RegisterEvent("PLAYER_REGEN_DISABLED", UpdateButton)
	ns.RegisterEvent("PLAYER_REGEN_ENABLED", UpdateButton)

	ns.RegisterSlashCommand("bars", function(input)
		if input == "" then
			ListSets()
			return
		end
		if input == "next" then
			ns.NextActionSet()
			return
		end
		local index = Sets.Find(config.sets, input)
		if index then
			SwitchTo(index)
		else
			ns.Print(T("Unknown action set: ", "Unbekanntes Aktionsleisten-Set: ") .. input)
			ListSets()
		end
	end)
end
