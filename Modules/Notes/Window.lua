local _, ns = ...

-- The notes window: tabs for players, items and general notes, each a list
-- on the left and the selected entry on the right. Edits are saved as they
-- are typed.

local Window = {}
ns.NotesWindow = Window

local Store = ns.NotesStore
local W = ns.NotesWidgets
local config = ns.config.notes
local colors = config.colors
local T = ns.T

local LIST_WIDTH = 270
local SORTS = { "recent", "name", "rating" }
local SORT_NAMES = {
	recent = { "Last seen", "Zuletzt" },
	name = { "Name", "Name" },
	rating = { "Rating", "Bewertung" },
}

local frame
local state = { tab = "players", search = "", sortBy = "recent" }
local tabs, panels = {}, {}

local function Now()
	return time()
end

local function CurrentStore()
	return ns.Notes.store
end

local function ItemName(itemID)
	local name = C_Item.GetItemNameByID(itemID)
	if not name then
		C_Item.RequestLoadItemDataByID(itemID)
		return ("item:%d"):format(itemID)
	end
	local quality = C_Item.GetItemQualityByID(itemID)
	local hex = quality and select(4, C_Item.GetItemQualityColor(quality))
	return hex and ("|c%s%s|r"):format(hex, name) or name
end

-- Players ----------------------------------------------------------------------

local function PlayerInfo(player)
	local class = player.class and LOCALIZED_CLASS_NAMES_MALE[player.class]
	local parts = {}
	if class then
		parts[#parts + 1] = class
	end
	parts[#parts + 1] = T("first seen %s", "zuerst %s"):format(W.Date(player.firstSeen))
	parts[#parts + 1] = T("last seen %s", "zuletzt %s"):format(W.Date(player.lastSeen))
	return table.concat(parts, " · ")
end

local function SessionLabel(session)
	local where
	if session.open then
		where = T("grouped now", "gerade in der Gruppe")
	elseif session.instance then
		where = session.where
	elseif session.where then
		where = session.where .. T(" · open world", " · offene Welt")
	else
		where = "?"
	end
	return ("%s  %s"):format(W.Date(session.start), where)
end

local function RefreshPlayerSummary()
	local panel = panels.players
	local player = state.selected and CurrentStore():Player(state.selected)
	if player then
		panel.summary:SetText(W.SummaryText(player) or T("Not rated yet", "Noch nicht bewertet"))
	end
end

local function RenderPlayer()
	local panel = panels.players
	local player = state.selected and CurrentStore():Player(state.selected)
	panel.content:SetShown(player ~= nil)
	panel.empty:SetShown(player == nil)
	if not player then
		return
	end
	panel.name:SetText(W.ClassColored(player.name, player.class))
	panel.info:SetText(PlayerInfo(player))
	RefreshPlayerSummary()
	panel.note:SetText(player.note)

	local sessions = player.sessions
	local count = #sessions
	for index = 1, count do
		local session = sessions[count - index + 1]
		local row = panel.rows[index]
		if not row then
			row = W.SessionRow(panel.sessionContent, 190, function()
				RefreshPlayerSummary()
				Window.RefreshList()
			end)
			row:SetPoint("TOPLEFT", 0, -(index - 1) * 26)
			row:SetPoint("RIGHT")
			panel.rows[index] = row
		end
		row:Set(session, SessionLabel(session))
		row:Show()
	end
	for index = count + 1, #panel.rows do
		panel.rows[index]:Hide()
	end
	panel.sessionContent:SetHeight(math.max(count * 26, 1))
	panel.noSessions:SetShown(count == 0)
end

local function CreatePlayersPanel(parent)
	local panel = CreateFrame("Frame", nil, parent)
	panel:SetAllPoints()
	panel.rows = {}

	panel.empty = ns.CreateFontString(panel)
	panel.empty:SetPoint("CENTER")
	panel.empty:SetTextColor(unpack(colors.dim))
	panel.empty:SetText(
		T(
			"Players you group with show up here.\nPick one to rate them or add a note.",
			"Spieler aus deinen Gruppen erscheinen hier.\nWähle einen aus, um ihn zu bewerten oder eine Notiz zu schreiben."
		)
	)
	panel.empty:SetWordWrap(true)

	local content = CreateFrame("Frame", nil, panel)
	content:SetAllPoints()
	panel.content = content

	panel.name = ns.CreateFontString(content, 14)
	panel.name:SetPoint("TOPLEFT", 0, 0)
	panel.info = ns.CreateFontString(content)
	panel.info:SetPoint("TOPLEFT", panel.name, "BOTTOMLEFT", 0, -4)
	panel.info:SetTextColor(unpack(colors.dim))
	panel.summary = ns.CreateFontString(content)
	panel.summary:SetPoint("TOPLEFT", panel.info, "BOTTOMLEFT", 0, -6)

	local forget = W.Button(content, T("Forget", "Vergessen"), 90)
	forget:SetPoint("TOPRIGHT", 0, 0)
	forget:SetScript("OnClick", function()
		if IsShiftKeyDown() then
			CurrentStore().db.players[state.selected] = nil
			state.selected = nil
			Window.Refresh()
		else
			ns.Print(
				T("Shift-click Forget to delete this player.", "Umschalt-Klick auf Vergessen löscht diesen Spieler.")
			)
		end
	end)

	local noteLabel = ns.CreateFontString(content)
	noteLabel:SetPoint("TOPLEFT", panel.summary, "BOTTOMLEFT", 0, -12)
	noteLabel:SetText(T("Note", "Notiz"))
	panel.note = W.TextArea(content, function(text)
		CurrentStore():SetPlayerNote(state.selected, text, Now())
		Window.RefreshList()
	end)
	panel.note:SetPoint("TOPLEFT", noteLabel, "BOTTOMLEFT", 0, -4)
	panel.note:SetPoint("RIGHT")
	panel.note:SetHeight(70)

	local sessionsLabel = ns.CreateFontString(content)
	sessionsLabel:SetPoint("TOPLEFT", panel.note, "BOTTOMLEFT", 0, -12)
	sessionsLabel:SetText(
		T("Groups together: role, rating, comment", "Gemeinsame Gruppen: Rolle, Bewertung, Kommentar")
	)

	local scroll = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", sessionsLabel, "BOTTOMLEFT", 0, -6)
	scroll:SetPoint("BOTTOMRIGHT", -22, 0)
	panel.sessionContent = CreateFrame("Frame", nil, scroll)
	panel.sessionContent:SetSize(1, 1)
	scroll:SetScrollChild(panel.sessionContent)
	scroll:SetScript("OnSizeChanged", function(_, width)
		panel.sessionContent:SetWidth(width)
	end)
	panel.noSessions = ns.CreateFontString(content)
	panel.noSessions:SetPoint("TOPLEFT", scroll, "TOPLEFT", 2, -4)
	panel.noSessions:SetTextColor(unpack(colors.dim))
	panel.noSessions:SetText(T("No groups together yet.", "Noch keine gemeinsame Gruppe."))

	panel.Render = RenderPlayer
	return panel
end

-- Items ------------------------------------------------------------------------

local function RenderItem()
	local panel = panels.items
	local itemID = state.selected
	panel.content:SetShown(itemID ~= nil)
	panel.empty:SetShown(itemID == nil)
	if not itemID then
		return
	end
	panel.icon:SetTexture(C_Item.GetItemIconByID(itemID))
	panel.name:SetText(ItemName(itemID))
	panel.text:SetText(CurrentStore():ItemNote(itemID))
end

local function CreateItemsPanel(parent)
	local panel = CreateFrame("Frame", nil, parent)
	panel:SetAllPoints()

	panel.empty = ns.CreateFontString(panel)
	panel.empty:SetPoint("CENTER")
	panel.empty:SetWordWrap(true)
	panel.empty:SetTextColor(unpack(colors.dim))
	panel.empty:SetText(
		T(
			"Alt+right-click an item in your bags or bank,\nor drop one on the list, to write a note for it.",
			"Alt+Rechtsklick auf einen Gegenstand in Taschen oder Bank,\noder einen auf die Liste ziehen, um eine Notiz zu schreiben."
		)
	)

	local content = CreateFrame("Frame", nil, panel)
	content:SetAllPoints()
	panel.content = content

	panel.icon = content:CreateTexture(nil, "ARTWORK")
	panel.icon:SetSize(28, 28)
	panel.icon:SetPoint("TOPLEFT")
	ns.CropIcon(panel.icon)
	panel.name = ns.CreateFontString(content, 14)
	panel.name:SetPoint("LEFT", panel.icon, "RIGHT", 8, 0)
	-- Hovering the name shows the item.
	local hover = CreateFrame("Frame", nil, content)
	hover:SetAllPoints(panel.name)
	hover:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetItemByID(state.selected)
		GameTooltip:Show()
	end)
	hover:SetScript("OnLeave", GameTooltip_Hide)

	local remove = W.Button(content, T("Remove", "Entfernen"), 90)
	remove:SetPoint("TOPRIGHT")
	remove:SetScript("OnClick", function()
		CurrentStore():SetItemNote(state.selected, nil, Now())
		state.selected = nil
		Window.Refresh()
	end)

	panel.text = W.TextArea(content, function(text)
		CurrentStore():SetItemNote(state.selected, text, Now())
		Window.RefreshList()
	end)
	panel.text:SetPoint("TOPLEFT", panel.icon, "BOTTOMLEFT", 0, -12)
	panel.text:SetPoint("BOTTOMRIGHT")

	panel.Render = RenderItem
	return panel
end

-- General notes ----------------------------------------------------------------

local function RenderNote()
	local panel = panels.notes
	local note = state.selected
	panel.content:SetShown(note ~= nil)
	panel.empty:SetShown(note == nil)
	if note then
		panel.changed:SetText(T("changed %s", "geändert %s"):format(W.Date(note.changed)))
		panel.text:SetText(note.text)
	end
end

local function CreateNotesPanel(parent)
	local panel = CreateFrame("Frame", nil, parent)
	panel:SetAllPoints()

	panel.empty = ns.CreateFontString(panel)
	panel.empty:SetPoint("CENTER")
	panel.empty:SetTextColor(unpack(colors.dim))
	panel.empty:SetText(T("Pick a note, or start a new one.", "Wähle eine Notiz oder beginne eine neue."))

	local content = CreateFrame("Frame", nil, panel)
	content:SetAllPoints()
	panel.content = content

	panel.changed = ns.CreateFontString(content)
	panel.changed:SetPoint("TOPLEFT", 0, -4)
	panel.changed:SetTextColor(unpack(colors.dim))

	local delete = W.Button(content, T("Delete", "Löschen"), 90)
	delete:SetPoint("TOPRIGHT")
	delete:SetScript("OnClick", function()
		CurrentStore():RemoveNote(state.selected)
		state.selected = nil
		Window.Refresh()
	end)

	panel.text = W.TextArea(content, function(text)
		Store.SetNoteText(state.selected, text, Now())
		Window.RefreshList()
	end)
	panel.text:SetPoint("TOPLEFT", 0, -30)
	panel.text:SetPoint("BOTTOMRIGHT")

	panel.Render = RenderNote
	return panel
end

-- Lists ------------------------------------------------------------------------

local function RenderPlayerRow(row, player)
	local name = W.ClassColored(player.name, player.class)
	if player.note then
		name = name .. " |cff999999·|r"
	end
	row.left:SetText(name)
	row.right:SetText(W.Rating(Store.Summary(player).overall))
end

local function RenderItemRow(row, itemID)
	frame.list.ShowIcon(row, C_Item.GetItemIconByID(itemID))
	row.left:SetText(ItemName(itemID))
	row.right:SetText("")
end

local function RenderNoteRow(row, note)
	local title = Store.Title(note.text)
	row.left:SetText(title ~= "" and title or T("(empty)", "(leer)"))
	row.right:SetText(W.Date(note.changed))
end

local function ItemsMatching(search)
	local ids = CurrentStore():ItemIDs()
	if search == "" then
		return ids
	end
	local result = {}
	search = search:lower()
	for _, id in ipairs(ids) do
		local name = (C_Item.GetItemNameByID(id) or ""):lower()
		local text = CurrentStore():ItemNote(id):lower()
		if name:find(search, 1, true) or text:find(search, 1, true) then
			result[#result + 1] = id
		end
	end
	return result
end

function Window.RefreshList()
	if not frame or not frame:IsShown() then
		return
	end
	local store = CurrentStore()
	if state.tab == "players" then
		frame.list:SetItems(
			store:Players(state.search, state.sortBy),
			RenderPlayerRow,
			state.selected and store:Player(state.selected)
		)
	elseif state.tab == "items" then
		frame.list:SetItems(ItemsMatching(state.search), RenderItemRow, state.selected)
	else
		frame.list:SetItems(store:Notes(state.search), RenderNoteRow, state.selected)
	end
end

function Window.Refresh()
	if not frame or not frame:IsShown() then
		return
	end
	for name, tab in pairs(tabs) do
		tab:SetEnabled(name ~= state.tab)
		panels[name]:SetShown(name == state.tab)
	end
	frame.sort:SetShown(state.tab == "players")
	frame.sort:SetText(T(unpack(SORT_NAMES[state.sortBy])))
	frame.new:SetShown(state.tab == "notes")
	frame.drop:SetShown(state.tab == "items")
	Window.RefreshList()
	panels[state.tab].Render()
end

local function Select(item)
	state.selected = state.tab == "players" and item.name or item
	Window.Refresh()
end

-- Window -----------------------------------------------------------------------

local function DropItem()
	local kind, itemID = GetCursorInfo()
	if kind == "item" and itemID then
		ClearCursor()
		Window.Open("items", itemID)
	end
end

local function CreateWindow()
	frame = CreateFrame("Frame", "StevioUI_Notes", UIParent)
	frame:SetSize(config.window.width, config.window.height)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	ns.CreateBackground(frame, { 0.05, 0.05, 0.05, 0.95 })
	ns.CreateBorder(frame)
	-- Lets Escape close the window like any Blizzard panel.
	tinsert(UISpecialFrames, frame:GetName())
	frame:SetScript("OnShow", Window.Refresh)

	local title = ns.CreateFontString(frame, 14)
	title:SetPoint("TOPLEFT", 12, -10)
	title:SetText(T("Notes", "Notizen"))

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)

	local tabSpecs = {
		{ "players", T("Players", "Spieler") },
		{ "items", T("Items", "Gegenstände") },
		{ "notes", T("Notes", "Notizen") },
	}
	local previous
	for _, spec in ipairs(tabSpecs) do
		local tab = W.Button(frame, spec[2], 100)
		if previous then
			tab:SetPoint("LEFT", previous, "RIGHT", 4, 0)
		else
			tab:SetPoint("TOPLEFT", 100, -6)
		end
		tab:SetScript("OnClick", function()
			Window.Open(spec[1])
		end)
		tabs[spec[1]] = tab
		previous = tab
	end

	local search = W.Input(frame, LIST_WIDTH - 100, function(text)
		state.search = text
		Window.RefreshList()
	end)
	search:SetPoint("TOPLEFT", 18, -40)
	search.Instructions = search:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	search.Instructions:SetPoint("LEFT", 2, 0)
	search.Instructions:SetText(T("Search", "Suchen"))
	search:HookScript("OnTextChanged", function(self)
		self.Instructions:SetShown(self:GetText() == "")
	end)

	frame.sort = W.Button(frame, "", 90)
	frame.sort:SetPoint("LEFT", search, "RIGHT", 6, 0)
	frame.sort:SetScript("OnClick", function()
		for index, name in ipairs(SORTS) do
			if name == state.sortBy then
				state.sortBy = SORTS[index % #SORTS + 1]
				break
			end
		end
		Window.Refresh()
	end)

	frame.new = W.Button(frame, T("New", "Neu"), 90)
	frame.new:SetPoint("LEFT", search, "RIGHT", 6, 0)
	frame.new:SetScript("OnClick", function()
		state.selected = CurrentStore():AddNote(Now())
		Window.Refresh()
		panels.notes.text.edit:SetFocus()
	end)

	frame.list = W.List(frame, 20, Select)
	frame.list:SetPoint("TOPLEFT", 12, -66)
	frame.list:SetPoint("BOTTOMLEFT", 12, 12)
	frame.list:SetWidth(LIST_WIDTH)

	-- The items tab takes items dropped on its list.
	frame.drop = CreateFrame("Button", nil, frame)
	frame.drop:SetAllPoints(frame.list)
	frame.drop:SetFrameLevel(frame.list:GetFrameLevel() + 20)
	frame.drop:SetScript("OnReceiveDrag", DropItem)
	frame.drop:SetScript("OnMouseUp", DropItem)
	-- Only takes the mouse while an item is held, so the list stays clickable.
	frame.drop:SetScript("OnUpdate", function(self)
		self:EnableMouse(GetCursorInfo() == "item")
	end)

	local detail = CreateFrame("Frame", nil, frame)
	detail:SetPoint("TOPLEFT", frame.list, "TOPRIGHT", 16, 0)
	detail:SetPoint("BOTTOMRIGHT", -12, 12)
	panels.players = CreatePlayersPanel(detail)
	panels.items = CreateItemsPanel(detail)
	panels.notes = CreateNotesPanel(detail)

	ns.RegisterEvent("GET_ITEM_INFO_RECEIVED", function()
		if state.tab == "items" then
			Window.RefreshList()
		end
	end)
end

-- Opens the window on `tab` ("players", "items", "notes"), selecting `key`
-- (a player name, an item ID or a note) when given.
function Window.Open(tab, key)
	if not frame then
		CreateWindow()
	end
	if tab and tab ~= state.tab then
		state.tab, state.selected = tab, nil
	end
	if key ~= nil then
		state.selected = key
	end
	if frame:IsShown() then
		Window.Refresh()
	else
		frame:Show()
	end
end

function Window.Toggle()
	if frame and frame:IsShown() then
		frame:Hide()
	else
		Window.Open()
	end
end
