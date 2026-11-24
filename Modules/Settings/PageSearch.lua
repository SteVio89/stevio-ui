local _, ns = ...

-- The search results of the settings window (Search.lua), shown while the
-- navigation's search box holds text: a chip per module, the matches as
-- cards per module with their section and the control to change them right
-- there, and a link to the module's page.

local K = ns.PlayersKit
local C = ns.SettingsControls
local UI = ns.SettingsUI
local Search = ns.SettingsSearch
local Window = ns.SettingsWindow
local T = ns.T

local CARD_PAD = 16

-- The module chip picked for the current query (nil: all).
local filter, filterQuery

local function ValueOf(entry)
	return Search.ValueText(entry, UI.Value(entry.item.path))
end

local function CreateCard(parent)
	local card = K.Box(parent, K.CardColors())
	card.title = K.Text(card, 13, "textStrong")
	card.title:SetPoint("TOPLEFT", CARD_PAD, -14)
	card.link = C.Link(card, T("To the page ›", "Zur Seite ›"), function(self)
		Window.Open("module", self.module)
	end, 11)
	card.link:SetPoint("TOPRIGHT", -CARD_PAD, -14)
	card.rows = C.RowPools(card)
	return card
end

local function Create(parent)
	local page = CreateFrame("Frame", nil, parent)
	page.title = K.Text(page, 22, "textStrong")
	page.title:SetPoint("TOPLEFT")
	page.info = K.Text(page, 12, "textMuted")
	page.info:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -8)
	page.chips = K.Pool(function()
		local chip = K.Chip(page, 22)
		chip:SetScript("OnClick", function(self)
			filter = self.module
			Window.Render()
		end)
		return chip
	end)
	page.cards = K.Pool(function()
		return CreateCard(page)
	end)
	return page
end

local function Render(page, query, width)
	if query ~= filterQuery then
		filter, filterQuery = nil, query
	end
	local entries = Search.Entries(UI.Items)
	local result = Search.Run(entries, query, ValueOf)
	local shownQuery = query:match("^%s*(.-)%s*$")
	if result.total == 1 then
		page.title:SetText(T("1 match for “%s”", "1 Treffer für „%s“"):format(shownQuery))
	else
		page.title:SetText(T("%d matches for “%s”", "%d Treffer für „%s“"):format(result.total, shownQuery))
	end
	page.info:SetText(
		(
			#result.groups == 1 and T("In 1 area. ", "In 1 Bereich. ")
			or T("In %d areas. ", "In %d Bereichen. "):format(#result.groups)
		)
			.. T(
				"Names, explanations and values are searched; Esc empties the search. Changes work right here.",
				"Gesucht wird in Namen, Erklärungen und Werten; Esc leert die Suche. Ändern geht direkt hier."
			)
	)
	local y = 64

	-- Chips: all, then one per module.
	local x, line = 0, 0
	local chips = 0
	local function Chip(module, text, count)
		chips = chips + 1
		local chip = page.chips:Get(chips)
		chip.module = module
		chip:SetChip(text, count, filter == module)
		if x > 0 and x + chip:GetWidth() > width then
			x, line = 0, line + 1
		end
		chip:ClearAllPoints()
		chip:SetPoint("TOPLEFT", x, -(y + line * 28))
		x = x + chip:GetWidth() + 6
	end
	if result.total > 0 then
		Chip(nil, T("All", "Alle"), result.total)
		for _, group in ipairs(result.groups) do
			Chip(group.module, group.title, #group.entries)
		end
		y = y + (line + 1) * 28 + 16
	end
	page.chips:HideFrom(chips + 1)

	local cards = 0
	local rowWidth = width - 2 * CARD_PAD
	for _, group in ipairs(result.groups) do
		if not filter or filter == group.module then
			cards = cards + 1
			local card = page.cards:Get(cards)
			card.title:SetText(group.title)
			card.link.module = group.module
			card:ClearAllPoints()
			card:SetPoint("TOPLEFT", 0, -y)
			card:SetWidth(width)
			card.rows:Begin()
			local rowY = 40
			for _, entry in ipairs(group.entries) do
				local row = card.rows:Get(C.Kind(entry.item))
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", CARD_PAD, -rowY)
				row:SetWidth(rowWidth)
				rowY = rowY
					+ C.FillRow(row, entry.item, {
						width = rowWidth,
						query = query,
						pathText = entry.path ~= "" and entry.path or nil,
						showAdvanced = true,
					})
			end
			card.rows:Finish()
			card:SetHeight(rowY + 8)
			y = y + rowY + 8 + 12
		end
	end
	page.cards:HideFrom(cards + 1)
	page:SetHeight(y)
	return y
end

Window.RegisterPage("search", { Create = Create, Render = Render })
