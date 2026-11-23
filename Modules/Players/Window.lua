local _, ns = ...

-- The player database's window: the players on the left, the selected one on
-- the right with rating, group stats, loot, note, and either the groups
-- together (role, stars, comment) or the items they won. Edits are saved as
-- they are typed.

local Window = {}
ns.PlayersWindow = Window

local Store = ns.PlayersStore
local W = ns.NotesWidgets
local PW = ns.PlayerWidgets
local config = ns.config.players
local colors = ns.config.notes.colors
local T = ns.T

local WARN_COLOR = "|cffff5050"
local DIM_COLOR = "|cff999999"

local LIST_WIDTH = 250
local ROW_HEIGHT = 26
local SORTS = { "recent", "name", "rating" }
local SORT_NAMES = {
	recent = { "Last seen", "Zuletzt" },
	name = { "Name", "Name" },
	rating = { "Rating", "Bewertung" },
}

local frame, panel
-- view: what the lower part of the page lists, "groups" or "loot".
local state = { search = "", sortBy = "recent", view = "groups" }

local function Now()
	return time()
end

local function CurrentStore()
	return ns.Players.store
end

local function Selected()
	return state.selected and CurrentStore():Player(state.selected)
end

-- Texts -------------------------------------------------------------------------

local function PlayerInfo(player)
	local class = player.class and LOCALIZED_CLASS_NAMES_MALE[player.class]
	local parts = {}
	if class then
		parts[#parts + 1] = class
	end
	if player.guild then
		parts[#parts + 1] = ("<%s>"):format(player.guild)
	end
	parts[#parts + 1] = T("first seen %s", "zuerst %s"):format(W.Date(player.firstSeen))
	parts[#parts + 1] = T("last seen %s", "zuletzt %s"):format(W.Date(player.lastSeen))
	return table.concat(parts, " · ")
end

local function SessionPlace(session)
	if session.open then
		return T("grouped now", "gerade in der Gruppe")
	elseif session.instance then
		return session.where
	elseif session.where then
		return session.where .. T(" · open world", " · offene Welt")
	end
	return "?"
end

-- "22.11.26  Molten Core · 2 items"
local function SessionLabel(player, session)
	local label = ("%s  %s"):format(W.Date(session.start), SessionPlace(session))
	local wins = #CurrentStore():SessionWins(player, session)
	if wins > 0 then
		label = label .. DIM_COLOR .. T(" · %d items", " · %d Gegenst."):format(wins) .. "|r"
	end
	return label
end

-- The hover lines of a session: place, time, bosses, wipes and items won.
local function SessionTooltip(session)
	local player = Selected()
	if not player then
		return nil
	end
	local lines = { SessionPlace(session) }
	local stop = session.stop or (session.open and Now()) or session.start
	lines[#lines + 1] = ("%s – %s · %s"):format(
		date("%d.%m.%y %H:%M", session.start),
		date("%H:%M", stop),
		Store.FormatDuration(math.max(0, stop - session.start))
	)
	if session.kills and #session.kills > 0 then
		lines[#lines + 1] = T("Bosses: %s", "Bosse: %s"):format(table.concat(session.kills, ", "))
	end
	if session.wipes and session.wipes > 0 then
		lines[#lines + 1] = T("Wipes: %d", "Wipes: %d"):format(session.wipes)
	end
	for _, win in ipairs(CurrentStore():SessionWins(player, session)) do
		lines[#lines + 1] = T("Won %s", "Gewonnen: %s"):format(win.link)
	end
	return lines
end

-- "Ragnaros · Molten Core · 22.11.26"
local function WinSource(win)
	local parts = {}
	if win.encounter then
		parts[#parts + 1] = win.encounter
	end
	if win.instance and win.instance ~= win.encounter then
		parts[#parts + 1] = win.instance
	end
	parts[#parts + 1] = W.Date(win.time)
	return table.concat(parts, " · ")
end

-- Player page ---------------------------------------------------------------------

local function RefreshSummary()
	local player = Selected()
	if not player then
		return
	end
	local lines = { PW.SummaryText(player) or T("Not rated yet", "Noch nicht bewertet") }
	if player.blocked then
		lines[#lines + 1] = WARN_COLOR
			.. T("Marked %s: %s", "Markiert %s: %s"):format(W.Date(player.blocked.time), PW.BlockReason(player))
			.. "|r"
	end
	local stats = Store.Stats(player, Now())
	lines[#lines + 1] = PW.StatsText(stats)
	local loot = PW.LootText(stats)
	if loot then
		lines[#lines + 1] = loot
	end
	-- More lines push the note label below down with them.
	panel.summary:SetText(table.concat(lines, "\n"))
	panel.unmark:SetShown(player.blocked ~= nil)
end

local function SessionRow(index)
	local row = panel.sessionRows[index]
	if not row then
		row = PW.SessionRow(panel.listContent, 230, function()
			RefreshSummary()
			Window.RefreshList()
		end)
		row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
		row:SetPoint("RIGHT")
		panel.sessionRows[index] = row
	end
	return row
end

local function WinRow(index)
	local row = panel.winRows[index]
	if not row then
		row = CreateFrame("Button", nil, panel.listContent)
		row:SetHeight(ROW_HEIGHT)
		row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
		row:SetPoint("RIGHT")
		local hover = row:CreateTexture(nil, "HIGHLIGHT")
		hover:SetAllPoints()
		hover:SetColorTexture(unpack(colors.hover))
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(ROW_HEIGHT - 6, ROW_HEIGHT - 6)
		row.icon:SetPoint("LEFT", 2, 0)
		ns.CropIcon(row.icon)
		row.source = ns.CreateFontString(row, nil, "RIGHT")
		row.source:SetPoint("RIGHT", -4, 0)
		row.source:SetTextColor(unpack(colors.dim))
		row.name = ns.CreateFontString(row)
		row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
		row.name:SetPoint("RIGHT", row.source, "LEFT", -6, 0)
		row.name:SetWordWrap(false)
		row:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink(self.win.link)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", GameTooltip_Hide)
		-- Shift-click links the item, like everywhere else.
		row:SetScript("OnClick", function(self)
			HandleModifiedItemClick(self.win.link)
		end)
		panel.winRows[index] = row
	end
	return row
end

local function HideFrom(rows, first)
	for index = first, #rows do
		rows[index]:Hide()
	end
end

local function RenderSessions(player)
	local sessions = player.sessions
	local count = #sessions
	for index = 1, count do
		local session = sessions[count - index + 1]
		SessionRow(index):Set(session, SessionLabel(player, session), SessionTooltip)
		panel.sessionRows[index]:Show()
	end
	HideFrom(panel.sessionRows, count + 1)
	HideFrom(panel.winRows, 1)
	panel.listEmpty:SetText(T("No groups together yet.", "Noch keine gemeinsame Gruppe."))
	return count
end

local function RenderWins(player)
	local wins = player.wins or {}
	local count = #wins
	for index = 1, count do
		local win = wins[count - index + 1]
		local row = WinRow(index)
		row.win = win
		row.icon:SetTexture(C_Item.GetItemIconByID(win.link) or 134400) -- question mark
		row.name:SetText(win.link)
		row.source:SetText(WinSource(win))
		row:Show()
	end
	HideFrom(panel.winRows, count + 1)
	HideFrom(panel.sessionRows, 1)
	panel.listEmpty:SetText(
		T("No items won in your groups yet.", "Noch keine Gegenstände in deinen Gruppen gewonnen.")
	)
	return count
end

local function RenderPlayer()
	local player = Selected()
	panel.content:SetShown(player ~= nil)
	panel.empty:SetShown(player == nil)
	if not player then
		return
	end
	panel.name:SetText(W.ClassColored(player.name, player.class))
	panel.info:SetText(PlayerInfo(player))
	RefreshSummary()
	panel.note:SetText(player.note)

	local count
	if state.view == "loot" then
		count = RenderWins(player)
	else
		count = RenderSessions(player)
	end
	panel.groupsTab:SetEnabled(state.view ~= "groups")
	panel.lootTab:SetEnabled(state.view ~= "loot")
	panel.listContent:SetHeight(math.max(count * ROW_HEIGHT, 1))
	panel.listEmpty:SetShown(count == 0)
end

local function ShowView(view)
	state.view = view
	RenderPlayer()
end

local function CreatePlayerPanel(parent)
	panel = CreateFrame("Frame", nil, parent)
	panel:SetAllPoints()
	panel.sessionRows, panel.winRows = {}, {}

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
	panel.summary:SetPoint("RIGHT")
	panel.summary:SetJustifyH("LEFT")
	panel.summary:SetWordWrap(true)
	panel.summary:SetSpacing(3)

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

	panel.unmark = W.Button(content, T("Unmark", "Entmarkieren"), 90)
	panel.unmark:SetPoint("RIGHT", forget, "LEFT", -6, 0)
	panel.unmark:SetScript("OnClick", function()
		if IsShiftKeyDown() then
			CurrentStore():Unblock(state.selected)
			RefreshSummary()
			Window.RefreshList()
		else
			ns.Print(
				T(
					"Shift-click Unmark to remove the blocked-guild mark.",
					"Umschalt-Klick auf Entmarkieren entfernt die Gilden-Markierung."
				)
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
	panel.note:SetHeight(60)

	panel.groupsTab = W.Button(content, T("Groups together", "Gemeinsame Gruppen"), 150)
	panel.groupsTab:SetPoint("TOPLEFT", panel.note, "BOTTOMLEFT", 0, -10)
	panel.groupsTab:SetScript("OnClick", function()
		ShowView("groups")
	end)
	panel.lootTab = W.Button(content, T("Items won", "Gewonnene Beute"), 150)
	panel.lootTab:SetPoint("LEFT", panel.groupsTab, "RIGHT", 4, 0)
	panel.lootTab:SetScript("OnClick", function()
		ShowView("loot")
	end)

	local scroll = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", panel.groupsTab, "BOTTOMLEFT", 0, -6)
	scroll:SetPoint("BOTTOMRIGHT", -22, 0)
	panel.listContent = CreateFrame("Frame", nil, scroll)
	panel.listContent:SetSize(1, 1)
	scroll:SetScrollChild(panel.listContent)
	scroll:SetScript("OnSizeChanged", function(_, width)
		panel.listContent:SetWidth(width)
	end)
	panel.listEmpty = ns.CreateFontString(content)
	panel.listEmpty:SetPoint("TOPLEFT", scroll, "TOPLEFT", 2, -4)
	panel.listEmpty:SetTextColor(unpack(colors.dim))
end

-- List ----------------------------------------------------------------------------

local function RenderRow(row, player)
	local name = W.ClassColored(player.name, player.class)
	if player.blocked then
		name = WARN_COLOR .. "!|r " .. name
	end
	if player.note then
		name = name .. " " .. DIM_COLOR .. "·|r"
	end
	row.left:SetText(name)
	row.right:SetText(PW.Rating(Store.Summary(player).overall))
end

function Window.RefreshList()
	if not frame or not frame:IsShown() then
		return
	end
	frame.list:SetItems(CurrentStore():Players(state.search, state.sortBy), RenderRow, Selected())
end

function Window.Refresh()
	if not frame or not frame:IsShown() then
		return
	end
	frame.sort:SetText(T(unpack(SORT_NAMES[state.sortBy])))
	Window.RefreshList()
	RenderPlayer()
end

local function Select(player)
	state.selected = player.name
	Window.Refresh()
end

-- Window -------------------------------------------------------------------------

local function CreateWindow()
	frame = CreateFrame("Frame", "StevioUI_Players", UIParent)
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
	ns.CreatePanel(frame, { color = ns.PanelColor() })
	-- Lets Escape close the window like any Blizzard panel.
	tinsert(UISpecialFrames, frame:GetName())
	frame:SetScript("OnShow", Window.Refresh)

	local title = ns.CreateFontString(frame, 14)
	title:SetPoint("TOPLEFT", 12, -10)
	title:SetText(T("Players", "Spieler"))

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)

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

	frame.list = W.List(frame, 20, Select)
	frame.list:SetPoint("TOPLEFT", 12, -66)
	frame.list:SetPoint("BOTTOMLEFT", 12, 12)
	frame.list:SetWidth(LIST_WIDTH)

	local detail = CreateFrame("Frame", nil, frame)
	detail:SetPoint("TOPLEFT", frame.list, "TOPRIGHT", 16, 0)
	detail:SetPoint("BOTTOMRIGHT", -12, 12)
	CreatePlayerPanel(detail)
end

-- Opens the window, selecting the player `name` when given.
function Window.Open(name)
	if not frame then
		CreateWindow()
	end
	if name ~= nil then
		state.selected = name
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
