local _, ns = ...

-- The keybindings page: the profile's bindings and your own changes by
-- Blizzard's categories, with search and filters. A click on "+" waits for
-- a key (Escape cancels); a key chip can be bound anew or removed. Changes
-- go into StevioUIConfig.bindings and are applied at once (after combat).
-- Keyboard healing's arrow keys are shown, but locked.

local K = ns.PlayersKit
local C = ns.SettingsControls
local Keys = ns.SettingsKeys
local Window = ns.SettingsWindow
local config = ns.config.settings
local T = ns.T

local ROW_HEIGHT = 30
local NOTE_HEIGHT = 18
local CARD_PAD = 16
-- Rows drawn at most; "not bound" lists every action of the client.
local MAX_ROWS = 150

local FILTERS = {
	{ "all", { "All", "Alle" } },
	{ "own", { "Own", "Eigene" } },
	{ "conflicts", { "Conflicts", "Konflikte" } },
	{ "unbound", { "Not bound", "Nicht belegt" } },
}

-- filter, query, capture = { command, replace (a key) }, message = { command, text }
local state = { filter = "all", query = "" }

local function ProfileBindings()
	return config.profile.bindings or {}
end

local SetBindingOverride = ns.SettingsUI.SetBindingOverride

-- The client's actions in its order, with category and name.
local function Actions()
	local actions = {}
	for index = 1, GetNumBindings() do
		local command, category = GetBinding(index)
		if command and not command:find("^HEADER") then
			actions[#actions + 1] = {
				command = command,
				categoryName = ns.BindingCategoryName(category, OTHER),
				name = GetBindingName(command),
			}
		end
	end
	return actions
end

local function ActionName(command)
	local name = GetBindingName(command)
	return name ~= "" and name or command
end

-- Capture --------------------------------------------------------------------------

local captureBox

local function StopCapture()
	state.capture = nil
	if captureBox then
		captureBox:EnableKeyboard(false)
		captureBox:Hide()
	end
end

local function Assign(command, key, replace)
	local locked = Keys.Locked(ns.config.keyboardHealing)
	if locked[key] then
		state.message = {
			command = command,
			text = T(
				"%s belongs to keyboard healing and can't be bound here.",
				"%s gehört der Tastaturheilung und lässt sich hier nicht belegen."
			):format(Keys.DisplayName(key)),
		}
		return
	end
	state.message = nil
	if replace and replace ~= key then
		SetBindingOverride(replace, nil)
	end
	SetBindingOverride(key, command)
end

local function StartCapture(command, replace)
	state.capture = { command = command, replace = replace }
	state.message = nil
	Window.Render()
end

local function CreateCaptureBox(parent)
	local box = K.Box(parent, { K.RGB("accent", 0.18) }, { K.RGB("accent", 0.8) }, "Button")
	box:SetHeight(22)
	box.text = K.Text(box, 11, "textStrong", "CENTER")
	box.text:SetPoint("CENTER")
	box.text:SetText(T("Press a key … Esc cancels", "Drücke eine Taste … Esc bricht ab"))
	box:SetWidth(box.text:GetStringWidth() + 24)
	box:SetScript("OnKeyDown", function(_, key)
		-- The keys Blizzard's keybinding page waits past (modifiers alone, ...).
		if IsKeyPressIgnoredForBinding(key) then
			return
		end
		local capture = state.capture
		StopCapture()
		if key ~= "ESCAPE" and capture then
			Assign(capture.command, CreateKeyChordStringUsingMetaKeyState(key), capture.replace)
		end
		Window.Render()
	end)
	box:SetScript("OnClick", function()
		StopCapture()
		Window.Render()
	end)
	box:Hide()
	return box
end

-- Rows ----------------------------------------------------------------------------------

local function CreateKeyChip(parent)
	local chip = K.Box(parent, { 1, 1, 1, 0.08 }, { 1, 1, 1, 0.16 }, "Button")
	chip:SetHeight(20)
	chip.text = K.Text(chip, 11, "textStrong", "CENTER")
	chip.text:SetPoint("CENTER")
	function chip:SetKey(key)
		self.key = key
		self.text:SetText(Keys.DisplayName(key))
		self:SetWidth(math.max(22, self.text:GetStringWidth() + 14))
	end
	return chip
end

local function CreateRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(ROW_HEIGHT)
	row.line = K.Texture(row, "BACKGROUND", 1, 1, 1, 0.04)
	row.line:SetHeight(1)
	row.line:SetPoint("BOTTOMLEFT")
	row.line:SetPoint("BOTTOMRIGHT")
	row.dot = K.Circle(row, "ARTWORK")
	row.dot:SetSize(5, 5)
	row.dot:SetPoint("TOPLEFT", 2, -(ROW_HEIGHT / 2 - 2))
	row.name = K.Text(row, 12, "text")
	row.name:SetPoint("TOPLEFT", 14, -(ROW_HEIGHT / 2 - 7))
	row.source = K.Text(row, 10, "textFaint", "RIGHT")
	row.source:SetPoint("TOPRIGHT", 0, -(ROW_HEIGHT / 2 - 6))
	row.reset = C.Link(row, T("Reset", "Zurücksetzen"), function()
		for _, key in ipairs(Keys.ResetKeys(row.command, ProfileBindings(), StevioUIConfig.bindings)) do
			StevioUIConfig.bindings[key] = nil
		end
		ns.ApplyOverridesNow()
		Window.Render()
	end, 11)
	row.reset:SetPoint("TOPRIGHT", 0, -(ROW_HEIGHT / 2 - 7))
	row.chips = K.Pool(function()
		local chip = CreateKeyChip(row)
		chip:SetScript("OnClick", function(self)
			local key = self.key
			if row.locked then
				return
			end
			K.Menu(self, {
				{
					T("Bind anew …", "Neu belegen …"),
					function()
						StartCapture(row.command, key)
					end,
				},
				{
					T("Remove", "Entfernen"),
					function()
						SetBindingOverride(key, nil)
						Window.Render()
					end,
				},
			})
		end)
		return chip
	end)
	row.add = C.Button(row, "+", function()
		StartCapture(row.command)
	end, 20)
	row.add:SetWidth(22)
	row.note = K.Text(row, 10)
	row.note:SetTextColor(unpack(ns.config.style.palette.warning))
	row.note:SetPoint("TOPLEFT", 14, -ROW_HEIGHT + 4)
	row.note:SetWordWrap(true)
	return row
end

-- The conflict line under an own key that the profile gives to another action.
local function ConflictText(conflicts)
	local parts = {}
	for _, conflict in ipairs(conflicts) do
		parts[#parts + 1] = T(
			"%s is also given to “%s” by the profile. Your own binding wins.",
			"%s ist im Profil auch „%s“ zugewiesen. Die eigene Belegung gewinnt."
		):format(Keys.DisplayName(conflict.key), ActionName(conflict.profileCommand))
	end
	return table.concat(parts, " ")
end

-- Fills a row; returns its height. `keysX` is where the key chips start.
local function FillRow(row, data, width, keysX)
	row.command, row.locked = data.command, data.locked
	row.dot:SetVertexColor(K.RGB(data.own and "accent" or "textFaint"))
	row.name:SetText(data.name)
	row.name:SetWidth(keysX - 24)
	local x = keysX
	for index, key in ipairs(data.keys) do
		local chip = row.chips:Get(index)
		chip:SetKey(key)
		chip:ClearAllPoints()
		chip:SetPoint("TOPLEFT", x, -(ROW_HEIGHT - 20) / 2)
		x = x + chip:GetWidth() + 4
	end
	row.chips:HideFrom(#data.keys + 1)

	local capturing = state.capture and state.capture.command == data.command
	row.add:SetShown(not data.locked and not capturing)
	row.add:ClearAllPoints()
	row.add:SetPoint("TOPLEFT", x, -(ROW_HEIGHT - 20) / 2)
	if capturing then
		captureBox:SetParent(row)
		captureBox:ClearAllPoints()
		captureBox:SetPoint("TOPLEFT", x, -(ROW_HEIGHT - 22) / 2)
		captureBox:SetFrameLevel(row:GetFrameLevel() + 5)
		captureBox:Show()
		captureBox:EnableKeyboard(true)
		-- Restricted in combat; the key still arrives.
		if not InCombatLockdown() then
			captureBox:SetPropagateKeyboardInput(false)
		end
	end

	row.reset:SetShown(data.own and not data.locked)
	row.source:SetShown(not (data.own and not data.locked))
	row.source:SetText(data.sourceText or T("Profile", "Profil"))

	local note
	if state.message and state.message.command == data.command then
		note = state.message.text
	elseif data.conflicts and #data.conflicts > 0 then
		note = ConflictText(data.conflicts)
	end
	local height = ROW_HEIGHT
	row.note:SetShown(note ~= nil)
	if note then
		row.note:SetText(note)
		row.note:SetWidth(width - 14)
		height = height + math.max(NOTE_HEIGHT, row.note:GetStringHeight() + 6)
	end
	row:SetHeight(height)
	return height
end

-- Page -----------------------------------------------------------------------------------

local function CreateCard(parent)
	local card = K.Box(parent, K.CardColors())
	card.title = K.Text(card, 13, "textStrong")
	card.title:SetPoint("TOPLEFT", CARD_PAD, -14)
	card.count = K.Text(card, 11, "textMuted")
	card.count:SetPoint("LEFT", card.title, "RIGHT", 8, 0)
	return card
end

local function Legend(parent, colorName, text)
	local entry = CreateFrame("Frame", nil, parent)
	entry:SetHeight(14)
	entry.dot = K.Circle(entry, "ARTWORK")
	entry.dot:SetSize(5, 5)
	entry.dot:SetPoint("LEFT")
	entry.dot:SetVertexColor(K.RGB(colorName))
	entry.text = K.Text(entry, 10, "textMuted")
	entry.text:SetPoint("LEFT", entry.dot, "RIGHT", 6, 0)
	entry.text:SetText(text)
	entry:SetWidth(entry.text:GetStringWidth() + 11)
	return entry
end

local function Create(parent)
	local page = CreateFrame("Frame", nil, parent)
	page.crumb = K.Text(page, 10, "textMuted")
	page.crumb:SetPoint("TOPLEFT")
	page.crumb:SetText(T("System ›", "System ›"))
	page.title = K.Text(page, 22, "textStrong")
	page.title:SetPoint("TOPLEFT", 0, -16)
	page.title:SetText(T("Keybindings", "Tastenbelegung"))
	page.description = K.Text(page, 12, "text")
	page.description:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -8)
	page.description:SetWordWrap(true)
	page.description:SetText(
		T(
			"stevio-ui sets these bindings for the whole account at login. What you change here or in Blizzard's keybindings is kept and wins over the profile.",
			"stevio-ui setzt beim Login diese Belegung für den ganzen Account. Was du hier oder in Blizzards Tastenbelegung änderst, bleibt erhalten und hat Vorrang vor dem Profil."
		)
	)
	page.export = C.Button(page, T("Export as profile", "Als Profil exportieren"), function()
		SlashCmdList.STEVIOUI("export")
	end, 26)
	page.export:SetPoint("TOPRIGHT", 0, -14)

	page.search = K.Input(page, T("Search action or key …", "Aktion oder Taste suchen …"), function(text)
		state.query = text
		Window.Render()
	end, 28)
	page.search:SetWidth(240)
	page.chips = {}
	for index, entry in ipairs(FILTERS) do
		local chip = K.Chip(page, 22)
		chip.filter = entry[1]
		chip:SetScript("OnClick", function(self)
			state.filter = self.filter
			Window.Render()
		end)
		page.chips[index] = chip
	end
	page.legendOwn = Legend(page, "accent", T("own change", "eigene Änderung"))
	page.legendProfile = Legend(page, "textFaint", T("from the profile", "aus dem Profil"))

	page.cards = K.Pool(function()
		return CreateCard(page)
	end)
	page.rowPools = {}
	page.more = K.Text(page, 11, "textMuted")
	page.unmanaged = K.Text(page, 12, "warning")
	page.unmanaged:SetText(
		T(
			"The profile doesn't manage keybindings (bindings = nil in Profile.lua).",
			"Das Profil verwaltet keine Tastenbelegung (bindings = nil in Profile.lua)."
		)
	)
	captureBox = CreateCaptureBox(page)
	page.captureBox = captureBox
	page:SetScript("OnHide", StopCapture)
	return page
end

-- Rows of a card, recycled per card.
local function CardRows(page, card)
	page.rowPools[card] = page.rowPools[card] or K.Pool(function()
		return CreateRow(card)
	end)
	return page.rowPools[card]
end

-- Keyboard healing's keys, locked: up/down and left/right.
local function LockedGroup()
	local keys = ns.config.keyboardHealing.keys
	local source = ns.ConfigLabel("keyboardHealing")
	return {
		name = source,
		subtitle = T(
			"belong to keyboard healing and can't be changed here",
			"gehören der Tastaturheilung und sind hier nicht änderbar"
		),
		rows = {
			{
				command = "STEVIOUI_CURSOR_VERTICAL",
				name = T("Cursor up / down", "Cursor hoch / runter"),
				keys = { keys.up, keys.down },
				locked = true,
				sourceText = source,
			},
			{
				command = "STEVIOUI_CURSOR_HORIZONTAL",
				name = T("Cursor left / right", "Cursor links / rechts"),
				keys = { keys.left, keys.right },
				locked = true,
				sourceText = source,
			},
		},
	}
end

local function Render(page, filter, width)
	if filter and filter ~= state.lastArg then
		state.filter = filter
	end
	state.lastArg = filter
	-- Shown again by the row it waits in, if that is still drawn.
	captureBox:Hide()
	page.description:SetWidth(width - page.export:GetWidth() - 32)
	local y = 16 + 30 + page.description:GetStringHeight() + 18

	local managed = config.profile.bindings ~= nil
	page.unmanaged:SetShown(not managed)
	page.search:ClearAllPoints()
	page.search:SetPoint("TOPLEFT", 0, -y)
	local groups, counts = Keys.Rows(Actions(), ProfileBindings(), StevioUIConfig.bindings, state.filter, state.query)
	local x = 252
	for index, chip in ipairs(page.chips) do
		local entry = FILTERS[index]
		chip:SetChip(
			T(entry[2][1], entry[2][2]),
			counts[entry[1]],
			state.filter == entry[1],
			entry[1] == "conflicts" and counts.conflicts > 0 and "warning" or nil
		)
		chip:ClearAllPoints()
		chip:SetPoint("LEFT", page, "TOPLEFT", x, -y - 14)
		x = x + chip:GetWidth() + 6
	end
	page.legendOwn:ClearAllPoints()
	page.legendOwn:SetPoint("RIGHT", page, "TOPRIGHT", 0, -y - 14)
	page.legendProfile:ClearAllPoints()
	page.legendProfile:SetPoint("RIGHT", page.legendOwn, "LEFT", -14, 0)
	y = y + 28 + 18
	if not managed then
		page.unmanaged:ClearAllPoints()
		page.unmanaged:SetPoint("TOPLEFT", 0, -y)
		y = y + 28
	end

	if state.filter == "all" and state.query == "" and ns.config.keyboardHealing.enabled ~= false then
		groups[#groups + 1] = LockedGroup()
	end

	local rowWidth = width - 2 * CARD_PAD
	local keysX = math.floor(rowWidth * 0.48)
	local drawn, cards = 0, 0
	for _, group in ipairs(groups) do
		if drawn >= MAX_ROWS then
			break
		end
		cards = cards + 1
		local card = page.cards:Get(cards)
		card.title:SetText(group.name)
		card.count:SetText(
			group.subtitle
				or (
					#group.rows == 1 and T("1 action", "1 Aktion") or T("%d actions", "%d Aktionen"):format(#group.rows)
				)
		)
		card:ClearAllPoints()
		card:SetPoint("TOPLEFT", 0, -y)
		card:SetWidth(width)
		local rows = CardRows(page, card)
		local rowY = 40
		local used = 0
		for _, data in ipairs(group.rows) do
			if drawn >= MAX_ROWS then
				break
			end
			used, drawn = used + 1, drawn + 1
			local row = rows:Get(used)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", CARD_PAD, -rowY)
			row:SetWidth(rowWidth)
			rowY = rowY + FillRow(row, data, rowWidth, keysX)
		end
		rows:HideFrom(used + 1)
		card:SetHeight(rowY + 10)
		y = y + rowY + 10 + 12
	end
	for index = cards + 1, #page.cards.frames do
		page.cards.frames[index]:Hide()
	end
	page.more:SetShown(drawn >= MAX_ROWS)
	if drawn >= MAX_ROWS then
		page.more:ClearAllPoints()
		page.more:SetPoint("TOPLEFT", 0, -y)
		page.more:SetText(
			T(
				"Only the first %d actions are shown; the search finds the others.",
				"Nur die ersten %d Aktionen werden gezeigt; die Suche findet die anderen."
			):format(MAX_ROWS)
		)
		y = y + 24
	end
	if state.capture and not captureBox:IsShown() then
		-- The action being bound is no longer in view (filter, search).
		StopCapture()
	end
	page:SetHeight(y)
	return y
end

Window.RegisterPage("bindings", { Create = Create, Render = Render })
