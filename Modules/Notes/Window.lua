local _, ns = ...

-- The notes window: tabs for items and general notes, each a list on the
-- left and the selected entry on the right. Edits are saved as they are
-- typed. Notes on players are in the players window (Modules/Players).

local Window = {}
ns.NotesWindow = Window

local Store = ns.NotesStore
local W = ns.NotesWidgets
local config = ns.config.notes
local colors = config.colors
local T = ns.T

local LIST_WIDTH = 270

local frame
local state = { tab = "items", search = "" }
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
	if state.tab == "items" then
		frame.list:SetItems(ItemsMatching(state.search), RenderItemRow, state.selected)
	else
		frame.list:SetItems(CurrentStore():Notes(state.search), RenderNoteRow, state.selected)
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
	frame.new:SetShown(state.tab == "notes")
	frame.drop:SetShown(state.tab == "items")
	Window.RefreshList()
	panels[state.tab].Render()
end

local function Select(item)
	state.selected = item
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
	ns.CreatePanel(frame, { color = ns.PanelColor() })
	-- Lets Escape close the window like any Blizzard panel.
	tinsert(UISpecialFrames, frame:GetName())
	frame:SetScript("OnShow", Window.Refresh)

	local title = ns.CreateFontString(frame, 14)
	title:SetPoint("TOPLEFT", 12, -10)
	title:SetText(T("Notes", "Notizen"))

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)

	local tabSpecs = {
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
	panels.items = CreateItemsPanel(detail)
	panels.notes = CreateNotesPanel(detail)

	-- Names of items not cached yet arrive later: the list and the selected
	-- item's header get them (only the header, so a note being typed stays).
	ns.RegisterEvent("GET_ITEM_INFO_RECEIVED", function(_, itemID)
		if state.tab == "items" then
			Window.RefreshList()
			if itemID and itemID == state.selected then
				panels.items.name:SetText(ItemName(itemID))
			end
		end
	end)
end

-- Opens the window on `tab` ("items", "notes"), selecting `key` (an item ID
-- or a note) when given.
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
