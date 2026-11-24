local _, ns = ...

-- A module page of the settings window, and the appearance page: header with
-- breadcrumb, description, the module's on/off switch and a menu; chips
-- that jump to the sections; the sections of Pages.lua with a row per
-- setting; the technical settings folded away under "Advanced". Modules with
-- a preview or test commands get a column on the right.

local K = ns.PlayersKit
local C = ns.SettingsControls
local UI = ns.SettingsUI
local Pages = ns.ConfigPages
local Window = ns.SettingsWindow
local T = ns.T

local SIDE_WIDTH = 220
local SIDE_GAP = 24
local HEADING_GAP = 18
-- Advanced settings with more than this many entries fold their tables.
local FOLD_ADVANCED = 30

local RESET_MODULE_DIALOG = "STEVIOUI_RESET_MODULE"

StaticPopupDialogs[RESET_MODULE_DIALOG] = {
	text = T(
		"Reset every setting of %s to the defaults in code?",
		"Alle Einstellungen von %s auf die Vorgaben im Code zurücksetzen?"
	),
	button1 = YES,
	button2 = NO,
	OnAccept = function(_, module)
		UI.ResetModule(module)
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

-- Which page shows what is folded: module key -> { advanced = open, groups = { [group] = open } }.
local folds = {}

local function Folds(key)
	folds[key] = folds[key] or { groups = {} }
	return folds[key]
end

-- Header -------------------------------------------------------------------------

local function CreateHeader(page)
	page.crumb = K.Text(page, 10, "textMuted")
	page.crumb:SetPoint("TOPLEFT")
	page.title = K.Text(page, 22, "textStrong")
	page.title:SetPoint("TOPLEFT", 0, -16)
	page.description = K.Text(page, 12, "text")
	page.description:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -8)
	page.description:SetWordWrap(true)

	page.menu = C.Button(page, "···", function(self)
		local module = page.module
		K.Menu(self, {
			{
				T("Reset module …", "Modul zurücksetzen …"),
				function()
					StaticPopup_Show(RESET_MODULE_DIALOG, Pages.Title(module), nil, module)
				end,
			},
		})
	end, 26)
	page.menu:SetWidth(30)
	page.menu:SetPoint("TOPRIGHT", 0, -14)
	page.enabled = C.Switch(page)
	page.enabled:SetPoint("RIGHT", page.menu, "LEFT", -12, 0)
	page.enabled.onChange = function(on)
		UI.SetEnabled(page.module[1], on)
	end
	page.enabledLabel = K.Text(page, 12, "text", "RIGHT")
	page.enabledLabel:SetPoint("RIGHT", page.enabled, "LEFT", -8, 0)
	page.enabledLabel:SetText(T("Active", "Aktiv"))
end

-- Sections -----------------------------------------------------------------------

-- The items of a page by section, in the page's section order, and the
-- advanced ones.
local function SortItems(module)
	local bySection, advanced = {}, {}
	for _, item in ipairs(UI.Items(module)) do
		if item.advanced then
			advanced[#advanced + 1] = item
		else
			local key = Pages.Section(module, item.section) and item.section or module.sections[1].key
			bySection[key] = bySection[key] or {}
			table.insert(bySection[key], item)
		end
	end
	return bySection, advanced
end

-- A small muted line between rows naming the table they come from
-- ("Frames 2 · target").
local function CreateGroupLine(parent)
	local line = CreateFrame("Button", nil, parent)
	line:SetHeight(26)
	line.text = K.Text(line, 11, "accent")
	line.text:SetPoint("BOTTOMLEFT", 0, 4)
	line:SetScript("OnClick", function(self)
		if self.onToggle then
			self.onToggle()
		end
	end)
	return line
end

-- Lays out rows for `items` from `y` down within `width`; returns the new y.
-- Rows of the same table get a group line above them. With `foldState` the
-- groups fold (advanced settings of large modules).
local function PlaceRows(page, items, y, width, foldState)
	local lastGroup
	local folded = false
	for _, item in ipairs(items) do
		if item.group ~= lastGroup then
			lastGroup = item.group
			folded = false
			if item.group then
				page.groupIndex = page.groupIndex + 1
				local line = page.groupLines:Get(page.groupIndex)
				line:ClearAllPoints()
				line:SetPoint("TOPLEFT", 0, -y)
				line:SetWidth(width)
				if foldState then
					local open = foldState.groups[item.group] == true
					folded = not open
					line.text:SetText((open and "– " or "+ ") .. item.group)
					local group = item.group
					line.onToggle = function()
						foldState.groups[group] = not open
						Window.Render()
					end
				else
					line.text:SetText(item.group)
					line.onToggle = nil
				end
				y = y + 26
			end
		end
		if not folded then
			local row = page.rows:Get(C.Kind(item))
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 0, -y)
			row:SetWidth(width)
			y = y + C.FillRow(row, item, { width = width })
		end
	end
	return y
end

local function CreateAdvanced(parent)
	local box = K.Box(parent, K.CardColors())
	box:SetHeight(54)
	box.toggle = CreateFrame("Button", nil, box)
	box.toggle:SetPoint("TOPLEFT")
	box.toggle:SetPoint("TOPRIGHT")
	box.toggle:SetHeight(54)
	box.arrow = K.Text(box.toggle, 13, "textMuted")
	box.arrow:SetPoint("LEFT", 14, 0)
	box.title = K.Text(box.toggle, 12, "textStrong")
	box.title:SetPoint("TOPLEFT", 34, -12)
	box.title:SetText(T("Advanced", "Erweitert"))
	box.summary = K.Text(box.toggle, 10, "textMuted")
	box.summary:SetPoint("TOPLEFT", box.title, "BOTTOMLEFT", 0, -4)
	box.action = K.Text(box.toggle, 11, "textMuted", "RIGHT")
	box.action:SetPoint("RIGHT", -16, 0)
	box.summary:SetPoint("RIGHT", box.action, "LEFT", -16, 0)
	box.summary:SetWordWrap(false)
	return box
end

-- "5 technical settings: aura filters, dark name threshold, …"
local function AdvancedSummary(items)
	local names, seen = {}, {}
	for _, item in ipairs(items) do
		local name = item.group and item.group:match("^[^›]+") or item.label
		name = name:gsub("%s+$", "")
		if not seen[name] and #names < 6 then
			seen[name] = true
			names[#names + 1] = name
		end
	end
	local text = #items == 1 and T("1 technical setting", "1 technische Einstellung")
		or T("%d technical settings", "%d technische Einstellungen"):format(#items)
	return ("%s: %s …"):format(text, table.concat(names, ", "))
end

-- Side column ----------------------------------------------------------------------

local SAMPLE_NAMES = {
	{ "Normal", "Normal" },
	{ "Dispellable", "Bannbar" },
	{ "Aggro", "Aggro" },
	{ "Out of range", "Außer Reichweite" },
}

-- A signature of the group config: the sample cells are rebuilt when it changes.
local function Signature(value)
	if type(value) ~= "table" then
		return tostring(value)
	end
	local parts = {}
	for key, inner in pairs(value) do
		parts[#parts + 1] = tostring(key) .. "=" .. Signature(inner)
	end
	table.sort(parts)
	return "{" .. table.concat(parts, ",") .. "}"
end

local function RenderGroupPreview(card)
	local signature = Signature(ns.config.group) .. ns.config.style.theme
	if card.signature ~= signature and ns.CreateGroupSamples then
		for _, cell in ipairs(card.cells or {}) do
			cell:Hide()
		end
		local ok, cells, width, height = ns.SafeCall(ns.CreateGroupSamples, card)
		card.cells = ok and cells or {}
		card.cellWidth, card.cellHeight = width or 80, height or 50
		card.signature = signature
	end
	local cells = card.cells or {}
	card.cellWidth, card.cellHeight = card.cellWidth or 80, card.cellHeight or 50
	local gap = 12
	for index, cell in ipairs(cells) do
		local column, line = (index - 1) % 2, math.floor((index - 1) / 2)
		cell:ClearAllPoints()
		cell:SetPoint("TOPLEFT", 16 + column * (card.cellWidth + gap), -40 - line * (card.cellHeight + 30))
		cell:Show()
		local label = card.labels[index]
		label:ClearAllPoints()
		label:SetPoint("TOPLEFT", cell, "BOTTOMLEFT", 0, -4)
		label:SetText(T(SAMPLE_NAMES[index][1], SAMPLE_NAMES[index][2]))
	end
	local top = 40 + 2 * (card.cellHeight + 30)
	card.note:ClearAllPoints()
	card.note:SetPoint("TOPLEFT", 16, -top)
	card.note:SetPoint("RIGHT", -16, 0)
	return top + card.note:GetStringHeight() + 16
end

local function CreateSide(page)
	local side = CreateFrame("Frame", nil, page)
	side:SetWidth(SIDE_WIDTH)
	side.preview = K.Card(side, T("Preview", "Vorschau"))
	side.preview:SetPoint("TOPLEFT")
	side.preview:SetPoint("TOPRIGHT")
	side.preview.labels = {}
	for index = 1, #SAMPLE_NAMES do
		side.preview.labels[index] = K.Text(side.preview, 10, "textMuted")
	end
	side.preview.note = K.Text(side.preview, 10, "textMuted")
	side.preview.note:SetWordWrap(true)
	side.preview.note:SetText(
		T(
			"The preview follows your changes at once; in the game they take effect after a reload.",
			"Die Vorschau folgt deinen Änderungen sofort, im Spiel wirken sie nach dem Neuladen."
		)
	)
	side.tests = K.Card(side, T("Try in the game", "Im Spiel testen"))
	side.tests.text = K.Text(side.tests, 11, "text")
	side.tests.text:SetPoint("TOPLEFT", 16, -36)
	side.tests.text:SetPoint("RIGHT", -16, 0)
	side.tests.text:SetWordWrap(true)
	side.tests.buttons = K.Pool(function()
		local button = C.Button(side.tests, "", function(self)
			SlashCmdList.STEVIOUI(self.command)
		end, 26)
		return button
	end)
	return side
end

local function RenderSide(side, module)
	local y = 0
	side.preview:SetShown(module.preview == "group")
	if module.preview == "group" then
		local height = RenderGroupPreview(side.preview)
		side.preview:SetHeight(height)
		y = y + height + 12
	end
	local tests = module.tests
	side.tests:SetShown(tests ~= nil)
	if tests then
		side.tests:ClearAllPoints()
		side.tests:SetPoint("TOPLEFT", 0, -y)
		side.tests:SetPoint("TOPRIGHT", 0, -y)
		side.tests.text:SetText(T(tests.title[1], tests.title[2]))
		local top = 36 + side.tests.text:GetStringHeight() + 12
		local x, line = 16, 0
		for index, test in ipairs(tests) do
			local button = side.tests.buttons:Get(index)
			local label = type(test[1]) == "table" and T(test[1][1], test[1][2]) or test[1]
			button:SetLabel(label)
			button:SetWidth(math.max(button:GetWidth(), 38))
			button.command = test[2]
			button.tooltip = "/sui " .. test[2]
			if x > 16 and x + button:GetWidth() > SIDE_WIDTH - 16 then
				x, line = 16, line + 1
			end
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", x, -(top + line * 32))
			x = x + button:GetWidth() + 6
		end
		side.tests.buttons:HideFrom(#tests + 1)
		local height = top + (line + 1) * 32 + 10
		side.tests:SetHeight(height)
		y = y + height
	end
	side:SetHeight(math.max(y, 1))
	return y
end

-- Page --------------------------------------------------------------------------------

local function Create(parent)
	local page = CreateFrame("Frame", nil, parent)
	CreateHeader(page)
	page.chips = K.Pool(function()
		local chip = K.Chip(page, 22)
		chip:SetScript("OnClick", function(self)
			Window.ScrollTo(self.top or 0)
		end)
		return chip
	end)
	page.rows = C.RowPools(page)
	page.headings = K.Pool(function()
		return C.Heading(page)
	end)
	page.groupLines = K.Pool(function()
		return CreateGroupLine(page)
	end)
	page.advanced = CreateAdvanced(page)
	page.side = CreateSide(page)

	page.themes = {}
	for index in ipairs(Window.THEMES) do
		local card = Window.CreateThemeCard(page)
		card:SetHeight(84)
		page.themes[index] = card
	end
	page.empty = K.Text(page, 12, "textMuted")
	page.empty:SetText(T("This module has no settings of its own.", "Dieses Modul hat keine eigenen Einstellungen."))
	return page
end

local function Render(page, key, width)
	local module = Pages.Module(key or "")
	if not module then
		return 0
	end
	page.module = module
	local isStyle = key == "style"
	local hasSide = module.preview ~= nil or module.tests ~= nil
	local mainWidth = hasSide and (width - SIDE_WIDTH - SIDE_GAP) or width

	-- Header.
	page.crumb:SetText(
		isStyle and T("General ›", "Allgemein ›") or (Pages.CategoryTitle(module.category) .. " ›")
	)
	page.title:SetText(Pages.Title(module))
	page.description:SetWidth(width - 200)
	page.description:SetText(Pages.Description(module))
	local canToggle = not isStyle and key ~= "settings" and ns.config[key] and ns.config[key].enabled ~= nil
	page.enabled:SetShown(canToggle)
	page.enabledLabel:SetShown(canToggle)
	if canToggle then
		page.enabled:SetOn(UI.IsEnabled(key))
	end
	local y = 16 + 30 + page.description:GetStringHeight() + 16

	-- Theme cards on the appearance page.
	for index, card in ipairs(page.themes) do
		card:SetShown(isStyle)
		if isStyle then
			local cardWidth = (mainWidth - 12) / 2
			card:ClearAllPoints()
			card:SetPoint("TOPLEFT", (index - 1) * (cardWidth + 12), -(y + 40))
			card:SetWidth(cardWidth)
			card:Set(Window.THEMES[index], Window.THEMES[index].key == ns.config.style.theme)
		end
	end

	local bySection, advanced = SortItems(module)
	local chipY = y
	y = y + 40
	if isStyle then
		y = y + 84 + 24
	end

	page.rows:Begin()
	page.groupIndex = 0
	local headings, chips = 0, 0
	local chipX = 0
	local function Chip(text, top)
		chips = chips + 1
		local chip = page.chips:Get(chips)
		chip:SetChip(text, nil, chips == 1)
		chip.top = top
		if chipX > 0 and chipX + chip:GetWidth() > width then
			return
		end
		chip:ClearAllPoints()
		chip:SetPoint("TOPLEFT", chipX, -chipY)
		chipX = chipX + chip:GetWidth() + 6
	end

	for _, section in ipairs(module.sections) do
		local items = bySection[section.key]
		if items then
			headings = headings + 1
			local heading = page.headings:Get(headings)
			heading:ClearAllPoints()
			heading:SetPoint("TOPLEFT", 0, -y)
			heading:SetWidth(mainWidth)
			heading:Set(
				T(section.title[1], section.title[2]),
				section.subtitle and T(section.subtitle[1], section.subtitle[2])
			)
			Chip(T(section.title[1], section.title[2]), y - 8)
			y = y + 28
			y = PlaceRows(page, items, y, mainWidth) + HEADING_GAP
		end
	end

	-- Advanced: folded, with a summary.
	local fold = Folds(key)
	page.advanced:SetShown(#advanced > 0)
	if #advanced > 0 then
		Chip(T("Advanced", "Erweitert"), y - 8)
		page.advanced:ClearAllPoints()
		page.advanced:SetPoint("TOPLEFT", 0, -y)
		page.advanced:SetWidth(mainWidth)
		page.advanced.arrow:SetText(fold.advanced and "–" or "+")
		page.advanced.summary:SetText(AdvancedSummary(advanced))
		page.advanced.action:SetText(fold.advanced and T("Hide", "Verbergen") or T("Show", "Anzeigen"))
		page.advanced.toggle:SetScript("OnClick", function()
			fold.advanced = not fold.advanced
			Window.Render()
		end)
		y = y + 54 + 8
		if fold.advanced then
			local foldState = #advanced > FOLD_ADVANCED and fold or nil
			y = PlaceRows(page, advanced, y, mainWidth, foldState) + HEADING_GAP
		end
	end
	page.chips:HideFrom(chips + 1)
	page.headings:HideFrom(headings + 1)
	page.groupLines:HideFrom(page.groupIndex + 1)
	page.rows:Finish()

	page.empty:SetShown(headings == 0 and #advanced == 0 and not isStyle)
	if page.empty:IsShown() then
		page.empty:ClearAllPoints()
		page.empty:SetPoint("TOPLEFT", 0, -(chipY + 8))
		y = chipY + 40
	end

	page.side:SetShown(hasSide)
	if hasSide then
		page.side:ClearAllPoints()
		page.side:SetPoint("TOPLEFT", mainWidth + SIDE_GAP, -(chipY + 40))
		local sideHeight = RenderSide(page.side, module)
		y = math.max(y, chipY + 40 + sideHeight)
	end
	page:SetHeight(y)
	return y
end

Window.RegisterPage("module", { Create = Create, Render = Render })
