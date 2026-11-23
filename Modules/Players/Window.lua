local _, ns = ...

-- The players window (#86): a database to open in a quiet moment. The left
-- side lists the players (search, filter chips, sort, role, sections by
-- when they were last seen); the right side scrolls and shows either the
-- overview (Overview.lua) or the selected player's page (Page.lua). Edits
-- are saved as they are made.

local Window = {}
ns.PlayersWindow = Window

local Store = ns.PlayersStore
local PW = ns.PlayerWidgets
local K = ns.PlayersKit
local config = ns.config.players
local T = ns.T

local TITLE_HEIGHT = 52
local LIST_WIDTH = 300
local PAD = 16
local ROW_HEIGHT = 46
local HEADER_HEIGHT = 30
local OVERVIEW_HEIGHT = 40

local SORTS = { "recent", "rating", "time", "name" }
local SORT_NAMES = {
	recent = { "Last seen", "Zuletzt" },
	rating = { "Rating", "Bewertung" },
	time = { "Time together", "Gemeinsame Zeit" },
	name = { "Name", "Name" },
}
local FILTER_NAMES = {
	all = { "All", "Alle" },
	rated = { "Rated", "Bewertet" },
	like = { "Play again", "Gerne wieder" },
	avoid = { "Avoid", "Meiden" },
	note = { "Note", "Notiz" },
	marked = { "Marked", "Markiert" },
}
local AGE_NAMES = {
	today = { "TODAY", "HEUTE" },
	yesterday = { "YESTERDAY", "GESTERN" },
	week = { "THIS WEEK", "DIESE WOCHE" },
	month = { "THIS MONTH", "DIESEN MONAT" },
	older = { "OLDER", "ÄLTER" },
}

local frame
-- selected: the player's name, nil for the overview. period: days of the
-- overview (nil: everything). history: the page's history filter.
local state = { search = "", sortBy = "recent", filter = "all", period = 30, history = "all" }
Window.state = state

function Window.Now()
	return time()
end

function Window.Store()
	return ns.Players.store
end

local function Selected()
	return state.selected and Window.Store():Player(state.selected)
end

-- List ----------------------------------------------------------------------------

-- The rows the list shows: the overview entry, then the players, under
-- section headers when sorted by last seen.
local function ListItems()
	local store, now = Window.Store(), Window.Now()
	local players = store:Players(state.search, state.sortBy, now, function(player)
		return Store.ListFilter(player, state.filter, state.role)
	end)
	local items = { { kind = "overview", height = OVERVIEW_HEIGHT } }
	local dayStart, section = PW.DayStart(now), nil
	for _, player in ipairs(players) do
		if state.sortBy == "recent" then
			local age = Store.Age(player.lastSeen, dayStart)
			if age ~= section then
				section = age
				items[#items + 1] = { kind = "header", height = HEADER_HEIGHT, text = T(unpack(AGE_NAMES[age])) }
			end
		end
		items[#items + 1] = { kind = "player", height = ROW_HEIGHT, player = player }
	end
	local y = 0
	for _, item in ipairs(items) do
		item.y = y
		y = y + item.height
	end
	return items, y, players
end

local function RatingText(player)
	local overall = Store.Summary(player).overall
	if not overall then
		return K.Hex("textFaint") .. "–|r"
	end
	local color = overall.average <= Store.ATTENTION_STARS and K.Hex("avoid") or K.Hex("textStrong")
	return ("%s%s|r |T%s:11|t"):format(color, Store.FormatAverage(overall.average), K.ICON_STAR)
end

-- "Healer · Deadmines"
local function RowInfo(player)
	local parts = {}
	local role = Store.LastRole(player)
	if role then
		parts[#parts + 1] = PW.RoleName(role)
	end
	local last = Store.LastSession(player)
	if last then
		local place = last.open and T("grouped now", "gerade in der Gruppe") or last.where
		if place then
			parts[#parts + 1] = place
		end
	elseif player.guild then
		parts[#parts + 1] = ("<%s>"):format(player.guild)
	end
	return table.concat(parts, " · ")
end

local function CreatePlayerRow(parent)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(ROW_HEIGHT)
	row.selected = K.Texture(row, "BACKGROUND", K.RGB("selected"))
	row.selected:SetAllPoints()
	row.stripe = K.Texture(row, "ARTWORK", K.RGB("accent"))
	row.stripe:SetPoint("TOPLEFT")
	row.stripe:SetPoint("BOTTOMLEFT")
	row.stripe:SetWidth(2)
	local hover = K.Texture(row, "HIGHLIGHT", 1, 1, 1, 0.04)
	hover:SetAllPoints()

	row.avatar = K.Avatar(row, 28)
	row.avatar:SetPoint("LEFT", 12, 0)
	row.rating = K.Text(row, 11, "textStrong", "RIGHT")
	row.rating:SetPoint("TOPRIGHT", -12, -10)
	row.when = K.Text(row, 10, "textFaint", "RIGHT")
	row.when:SetPoint("TOPRIGHT", row.rating, "BOTTOMRIGHT", 0, -4)
	row.note = row:CreateTexture(nil, "ARTWORK")
	row.note:SetSize(11, 11)
	row.note:SetTexture(K.ICON_NOTE)
	row.warning = row:CreateTexture(nil, "ARTWORK")
	row.warning:SetSize(12, 12)
	row.warning:SetTexture(K.ICON_WARNING)
	row.name = K.Text(row, 12, "text")
	row.name:SetPoint("TOPLEFT", row.avatar, "TOPRIGHT", 10, 3)
	row.info = K.Text(row, 10, "textMuted")
	row.info:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
	row.info:SetPoint("RIGHT", row.when, "LEFT", -8, 0)
	row:SetScript("OnClick", function(self)
		Window.Select(self.player.name)
	end)
	return row
end

local function RenderPlayerRow(row, player)
	row.player = player
	local selected = player.name == state.selected
	row.selected:SetShown(selected)
	row.stripe:SetShown(selected)
	row.avatar:Set(player.name, player.class)
	row.name:SetText(K.ColoredName(player.name, player.class))
	row.info:SetText(RowInfo(player))
	row.rating:SetText(RatingText(player))
	row.when:SetText(PW.When(player.lastSeen, Window.Now()))
	-- Icons before the rating, right to left: note, then the warning.
	local anchor = row.rating
	row.note:ClearAllPoints()
	row.note:SetShown(player.note ~= nil)
	if player.note then
		row.note:SetPoint("RIGHT", anchor, "LEFT", -4, 0)
		anchor = row.note
	end
	row.warning:ClearAllPoints()
	row.warning:SetShown(player.blocked ~= nil)
	if player.blocked then
		row.warning:SetPoint("RIGHT", anchor, "LEFT", -4, 0)
		anchor = row.warning
	end
	row.name:SetPoint("RIGHT", anchor, "LEFT", -6, 0)
end

local function CreateHeader(parent)
	local header = CreateFrame("Frame", nil, parent)
	header:SetHeight(HEADER_HEIGHT)
	header.text = K.Text(header, 10, "textFaint")
	header.text:SetPoint("BOTTOMLEFT", 14, 6)
	return header
end

-- Three small bars: the overview's icon (the fonts have no chart glyph).
local function ChartIcon(parent)
	local icon = CreateFrame("Frame", nil, parent)
	icon:SetSize(14, 12)
	for index, height in ipairs({ 6, 12, 9 }) do
		local bar = K.Texture(icon, "ARTWORK", K.RGB("text"))
		bar:SetSize(3, height)
		bar:SetPoint("BOTTOMLEFT", (index - 1) * 5, 0)
	end
	return icon
end

local function CreateOverviewRow(parent)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(OVERVIEW_HEIGHT)
	row.selected = K.Texture(row, "BACKGROUND", K.RGB("selected"))
	row.selected:SetAllPoints()
	row.stripe = K.Texture(row, "ARTWORK", K.RGB("accent"))
	row.stripe:SetPoint("TOPLEFT")
	row.stripe:SetPoint("BOTTOMLEFT")
	row.stripe:SetWidth(2)
	local hover = K.Texture(row, "HIGHLIGHT", 1, 1, 1, 0.04)
	hover:SetAllPoints()
	local icon = ChartIcon(row)
	icon:SetPoint("LEFT", 14, 0)
	local label = K.Text(row, 12, "textStrong")
	label:SetPoint("LEFT", icon, "RIGHT", 10, 0)
	label:SetText(T("Overview", "Übersicht"))
	local aside = K.Text(row, 10, "textFaint", "RIGHT")
	aside:SetPoint("RIGHT", -12, 0)
	aside:SetText(T("Statistics", "Statistik"))
	row:SetScript("OnClick", function()
		Window.Select(nil)
	end)
	return row
end

-- Only the rows in view exist as frames, so a database of hundreds of
-- players scrolls as smoothly as a short one.
local function RenderVisibleRows()
	local list = frame.list
	local offset, height = list:GetVerticalScroll(), list:GetHeight()
	local players, headers = 0, 0
	for _, item in ipairs(list.items or {}) do
		if item.y + item.height >= offset and item.y <= offset + height then
			local row
			if item.kind == "player" then
				players = players + 1
				row = list.playerRows:Get(players)
				RenderPlayerRow(row, item.player)
			elseif item.kind == "header" then
				headers = headers + 1
				row = list.headers:Get(headers)
				row.text:SetText(item.text)
			else
				row = list.overviewRow
				row:Show()
				row.selected:SetShown(state.selected == nil)
				row.stripe:SetShown(state.selected == nil)
			end
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", list.child, "TOPLEFT", 0, -item.y)
			row:SetPoint("RIGHT", list.child, "RIGHT")
		elseif item.kind == "overview" then
			list.overviewRow:Hide()
		end
	end
	list.playerRows:HideFrom(players + 1)
	list.headers:HideFrom(headers + 1)
end

local function RefreshChips()
	local counts = Window.Store():ListCounts(state.search, state.role)
	local x, y, width = 0, 0, LIST_WIDTH - 2 * PAD
	for _, chip in ipairs(frame.chips) do
		chip:SetChip(T(unpack(FILTER_NAMES[chip.filter])), counts[chip.filter], state.filter == chip.filter)
		if x > 0 and x + chip:GetWidth() > width then
			x, y = 0, y + 26
		end
		chip:ClearAllPoints()
		chip:SetPoint("TOPLEFT", frame.chipArea, "TOPLEFT", x, -y)
		x = x + chip:GetWidth() + 6
	end
	frame.chipArea:SetHeight(y + 22)
end

local function RefreshHeaderCounts()
	local counts = Window.Store():ListCounts(nil, nil)
	frame.counts:SetText(
		T("%d entries · %d rated · %d marked", "%d Einträge · %d bewertet · %d markiert"):format(
			counts.all,
			counts.rated,
			counts.marked
		)
	)
end

local function DropdownText(label, value)
	return ("%s%s:|r %s"):format(K.Hex("textMuted"), label, value)
end

function Window.RefreshList()
	if not frame or not frame:IsShown() then
		return
	end
	RefreshChips()
	RefreshHeaderCounts()
	frame.sort.text:SetText(DropdownText(T("Sort", "Sortieren"), T(unpack(SORT_NAMES[state.sortBy]))))
	frame.role.text:SetText(
		DropdownText(T("Role", "Rolle"), state.role and PW.RoleName(state.role) or T("All", "Alle"))
	)
	local items, height, players = ListItems()
	frame.list.items, frame.list.players = items, players
	frame.list:SetContentHeight(height)
	RenderVisibleRows()
end

-- Content ---------------------------------------------------------------------------

function Window.RenderContent()
	if not frame or not frame:IsShown() then
		return
	end
	local player = Selected()
	if state.selected and not player then
		state.selected = nil
	end
	local content = frame.content
	frame.overview:SetShown(player == nil)
	frame.page:SetShown(player ~= nil)
	local height
	if player then
		height = frame.page:Render(player)
	else
		height = frame.overview:Render()
	end
	content:SetContentHeight(height + PAD)
end

function Window.Refresh()
	Window.RefreshList()
	Window.RenderContent()
end

-- Selects a player by name (nil: the overview) and scrolls the content up.
function Window.Select(name)
	local changed = state.selected ~= name
	state.selected = name
	if changed then
		frame.content:ScrollTo(0)
	end
	Window.Refresh()
end

-- The next or previous player in the list (arrow keys), keeping it in view.
local function Step(delta)
	local players = frame.list.players or {}
	local index = 0
	for position, player in ipairs(players) do
		if player.name == state.selected then
			index = position
		end
	end
	local target = players[math.max(1, math.min(#players, index + delta))]
	if not target then
		return
	end
	Window.Select(target.name)
	for _, item in ipairs(frame.list.items) do
		if item.player == target then
			local list = frame.list
			local top, height = list:GetVerticalScroll(), list:GetHeight()
			if item.y < top then
				list:ScrollTo(item.y)
			elseif item.y + item.height > top + height then
				list:ScrollTo(item.y + item.height - height)
			end
		end
	end
end

-- Window -----------------------------------------------------------------------------

local function SavePosition()
	local point, _, relativePoint, x, y = frame:GetPoint()
	Window.Store().db.window = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function RestorePosition()
	local saved = Window.Store().db.window
	frame:ClearAllPoints()
	if saved and saved.point then
		frame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
	else
		frame:SetPoint("CENTER")
	end
end

-- A text button with a small arrow that opens a menu.
local function Dropdown(parent, entries)
	local button = CreateFrame("Button", nil, parent)
	button:SetHeight(18)
	button.text = K.Text(button, 11, "textStrong")
	button.text:SetPoint("LEFT")
	local arrow = button:CreateTexture(nil, "ARTWORK")
	arrow:SetSize(10, 10)
	arrow:SetPoint("LEFT", button.text, "RIGHT", 2, -1)
	arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
	arrow:SetVertexColor(K.RGB("textMuted"))
	button:SetScript("OnClick", function(self)
		K.Menu(self, entries())
	end)
	hooksecurefunc(button.text, "SetText", function(self)
		button:SetWidth(self:GetStringWidth() + 14)
	end)
	return button
end

local function CreateTitleBar()
	local bar = CreateFrame("Frame", nil, frame)
	bar:SetPoint("TOPLEFT")
	bar:SetPoint("TOPRIGHT")
	bar:SetHeight(TITLE_HEIGHT)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function()
		frame:StartMoving()
	end)
	bar:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		SavePosition()
	end)

	local icon = bar:CreateTexture(nil, "ARTWORK")
	icon:SetSize(18, 18)
	icon:SetPoint("LEFT", PAD + 4, 0)
	icon:SetTexture("Interface\\Icons\\Achievement_GuildPerk_HaveGroup WillTravel")
	ns.CropIcon(icon)
	local title = K.Text(bar, 15, "textStrong")
	title:SetPoint("LEFT", icon, "RIGHT", 10, 0)
	title:SetText(T("Players", "Spieler"))
	frame.counts = K.Text(bar, 11, "textMuted")
	frame.counts:SetPoint("LEFT", title, "RIGHT", 12, -1)

	local close = ns.CreateCloseButton(bar, 22, function()
		frame:Hide()
	end)
	close:SetPoint("RIGHT", -PAD, 0)
	local options = K.IconButton(bar, K.ICON_OPTIONS, 18, function(self)
		K.Menu(self, {
			{
				T("Options", "Optionen"),
				function()
					frame:Hide()
					if ns.OpenOptionsPage then
						ns.OpenOptionsPage("players")
					end
				end,
			},
			{
				T("Empty the database …", "Datenbank leeren …"),
				function()
					ns.Players.ConfirmReset()
				end,
			},
		})
	end)
	options.tooltip = T("Options", "Optionen")
	options:SetPoint("RIGHT", close, "LEFT", -12, 0)

	local line = K.Texture(frame, "ARTWORK", 1, 1, 1, 0.06)
	line:SetPoint("TOPLEFT", 0, -TITLE_HEIGHT)
	line:SetPoint("TOPRIGHT", 0, -TITLE_HEIGHT)
	line:SetHeight(1)
end

local function CreateListSide()
	local side = CreateFrame("Frame", nil, frame)
	side:SetPoint("TOPLEFT", 0, -TITLE_HEIGHT - 1)
	side:SetPoint("BOTTOMLEFT")
	side:SetWidth(LIST_WIDTH)
	local divider = K.Texture(frame, "ARTWORK", 1, 1, 1, 0.06)
	divider:SetPoint("TOPLEFT", side, "TOPRIGHT")
	divider:SetPoint("BOTTOMLEFT", side, "BOTTOMRIGHT")
	divider:SetWidth(1)

	local search = K.Input(side, T("Name, guild, note or tag …", "Name, Gilde, Notiz oder Tag …"), function(text)
		state.search = text
		frame.list:ScrollTo(0)
		Window.RefreshList()
	end, 32)
	search:SetPoint("TOPLEFT", PAD, -PAD)
	search:SetPoint("TOPRIGHT", -PAD, -PAD)
	local glass = search:CreateTexture(nil, "ARTWORK")
	glass:SetSize(14, 14)
	glass:SetPoint("LEFT", 10, 0)
	glass:SetTexture(K.ICON_SEARCH)
	search.edit:SetPoint("TOPLEFT", 30, 0)
	search.edit:SetScript("OnArrowPressed", function(_, key)
		if key == "UP" or key == "DOWN" then
			Step(key == "UP" and -1 or 1)
		end
	end)
	frame.search = search

	frame.chipArea = CreateFrame("Frame", nil, side)
	frame.chipArea:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -12)
	frame.chipArea:SetPoint("RIGHT", -PAD, 0)
	frame.chips = {}
	for _, filter in ipairs(Store.LIST_FILTERS) do
		local chip = K.Chip(frame.chipArea, 22)
		chip.filter = filter
		chip:SetScript("OnClick", function(self)
			state.filter = self.filter
			frame.list:ScrollTo(0)
			Window.RefreshList()
		end)
		frame.chips[#frame.chips + 1] = chip
	end

	frame.sort = Dropdown(side, function()
		local entries = {}
		for _, sortBy in ipairs(SORTS) do
			entries[#entries + 1] = {
				T(unpack(SORT_NAMES[sortBy])),
				function()
					state.sortBy = sortBy
					frame.list:ScrollTo(0)
					Window.RefreshList()
				end,
			}
		end
		return entries
	end)
	frame.sort:SetPoint("TOPLEFT", frame.chipArea, "BOTTOMLEFT", 0, -10)
	frame.role = Dropdown(side, function()
		local entries = {
			{
				T("All", "Alle"),
				function()
					state.role = nil
					Window.RefreshList()
				end,
			},
		}
		for _, role in ipairs(Store.ROLES) do
			entries[#entries + 1] = {
				PW.RoleName(role),
				function()
					state.role = role
					Window.RefreshList()
				end,
			}
		end
		return entries
	end)
	frame.role:SetPoint("TOPRIGHT", frame.chipArea, "BOTTOMRIGHT", 0, -10)

	local list = K.Scroll(side, ROW_HEIGHT)
	list:SetPoint("TOPLEFT", frame.sort, "BOTTOMLEFT", -PAD + 8, -10)
	list:SetPoint("BOTTOMRIGHT", -8, 8)
	list.onScroll = RenderVisibleRows
	list:HookScript("OnSizeChanged", function()
		RenderVisibleRows()
	end)
	list.playerRows = K.Pool(function()
		return CreatePlayerRow(list.child)
	end)
	list.headers = K.Pool(function()
		return CreateHeader(list.child)
	end)
	list.overviewRow = CreateOverviewRow(list.child)
	frame.list = list
end

local function CreateContentSide()
	local content = K.Scroll(frame, 80)
	content:SetPoint("TOPLEFT", LIST_WIDTH + 1 + 32, -TITLE_HEIGHT - 1 - 24)
	content:SetPoint("BOTTOMRIGHT", -32, 16)
	frame.content = content
	local width = config.window.width - LIST_WIDTH - 1 - 64
	frame.overview = ns.PlayersOverview.Create(content.child, width)
	frame.overview:SetPoint("TOPLEFT")
	frame.overview:SetPoint("TOPRIGHT")
	frame.page = ns.PlayersPage.Create(content.child, width)
	frame.page:SetPoint("TOPLEFT")
	frame.page:SetPoint("TOPRIGHT")
end

-- Arrow keys step through the players; typing goes to the search. Keys are
-- only taken out of combat, where letting them through can't be changed.
local function OnKeyDown(self, key)
	if InCombatLockdown() then
		return
	end
	local handled = true
	if key == "ESCAPE" then
		self:Hide()
	elseif key == "UP" or key == "DOWN" then
		Step(key == "UP" and -1 or 1)
	elseif
		#key == 1
		and key:match("[%w]")
		and not IsControlKeyDown()
		and not IsAltKeyDown()
		and not IsMetaKeyDown()
	then
		local edit = frame.search.edit
		edit:SetFocus()
		edit:Insert(IsShiftKeyDown() and key:upper() or key:lower())
	else
		handled = false
	end
	self:SetPropagateKeyboardInput(not handled)
end

local function CreateWindow()
	frame = CreateFrame("Frame", "StevioUI_Players", UIParent)
	frame:SetSize(config.window.width, config.window.height)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	ns.CreatePanel(frame, { color = ns.PanelColor() })
	-- Escape closes the window like any Blizzard panel (also in combat,
	-- where the window takes no keys).
	tinsert(UISpecialFrames, frame:GetName())
	RestorePosition()

	CreateTitleBar()
	CreateListSide()
	CreateContentSide()

	frame:SetScript("OnShow", function(self)
		if not InCombatLockdown() then
			self:EnableKeyboard(true)
		end
		Window.Refresh()
	end)
	frame:SetScript("OnHide", function(self)
		if not InCombatLockdown() then
			self:EnableKeyboard(false)
		end
	end)
	frame:SetScript("OnKeyDown", OnKeyDown)
	ns.RegisterEvent("PLAYER_REGEN_DISABLED", function()
		frame:EnableKeyboard(false)
	end)
	ns.RegisterEvent("PLAYER_REGEN_ENABLED", function()
		frame:EnableKeyboard(frame:IsShown())
	end)
end

-- After the database was emptied: back to the overview, filters cleared.
function Window.Reset()
	state.selected, state.search, state.filter, state.role = nil, "", "all", nil
	if not frame then
		return
	end
	frame.search:SetText("")
	frame.list:ScrollTo(0)
	frame.content:ScrollTo(0)
	Window.Refresh()
end

-- Opens the window, selecting the player `name` when given.
function Window.Open(name)
	if not frame then
		CreateWindow()
	end
	if name ~= nil then
		state.selected = Window.Store():Key(name)
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
