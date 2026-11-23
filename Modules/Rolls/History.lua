local _, ns = ...

-- The roll history: every decided group loot roll, newest first, under a
-- header per fight (boss · instance · date). A click on a drop lists
-- everyone's choice and number. It takes the loot ticker's place at the
-- bottom left (same column and height) and hides the ticker while open.

local History = {}
ns.RollHistory = History

local Logic = ns.RollLogic
local config = ns.config.rolls
local style = ns.config.style
local T = ns.T

-- Width of the scroll bar beside the list, with its gap, when it is needed.
local SCROLL_BAR_SPACE = 14

local frame, scrollBox, search, mineButton
local filter = { search = "", mineOnly = false }
local expanded = {}
-- The saved records (set by Rolls.lua), or made-up ones while previewing.
local records, previewRecords = {}, nil

local function LinkName(link)
	return link and (link:match("|h%[(.-)%]|h") or link:match("|h(.-)|h")) or "?"
end

local function LinkColor(link)
	local hex = link and link:match("|c(%x%x%x%x%x%x%x%x)")
	if hex then
		return tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, tonumber(hex:sub(7, 8), 16) / 255
	end
	return 1, 1, 1
end

local function FormatDate(time)
	return date("%d.%m. %H:%M", time)
end

local function Shown()
	return previewRecords or records
end

-- "Bob Need 98", "You Need 87" (green), "All passed".
local function DropDetail(record)
	local L, labels = ns.RollCards.L, ns.RollCards.stateLabels
	if record.allPassed then
		return "|cffaaaaaa" .. L.allPassed .. "|r"
	end
	local winner = record.winner
	if not winner then
		return ""
	end
	local text = winner.isSelf and ("|cff40ff40" .. T("You", "Du") .. "|r")
		or ns.RollCards.ClassColored(winner.name or "?", winner.class)
	return text .. " |cffaaaaaa" .. Logic.RollText(winner, labels) .. "|r"
end

function History.Refresh()
	if not frame or not frame:IsShown() then
		return
	end
	local rows = Logic.HistoryRows(Shown(), filter, expanded, LinkName)
	scrollBox:SetDataProvider(CreateDataProvider(rows), ScrollBoxConstants.RetainScrollPosition)
	mineButton.label:SetTextColor(
		filter.mineOnly and 1 or 0.5,
		filter.mineOnly and 1 or 0.5,
		filter.mineOnly and 1 or 0.5
	)
end

-- Rows ---------------------------------------------------------------------------

local function OnRowClick(row)
	local data = row.data
	if not data or data.kind == "header" then
		return
	end
	if IsModifierKeyDown() then
		HandleModifiedItemClick(data.record.link)
		return
	end
	expanded[data.record] = not expanded[data.record] or nil
	History.Refresh()
end

local function OnRowEnter(row)
	local data = row.data
	if data and data.kind == "drop" and data.record.link then
		GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
		GameTooltip:SetHyperlink(data.record.link)
		GameTooltip:Show()
	end
end

local function InitRow(row, data)
	local h = config.history
	if not row.text then
		row:SetHighlightTexture(style.texture)
		row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(h.iconSize, h.iconSize)
		ns.CropIcon(row.icon)
		row.detail = ns.CreateFontString(row, h.fontSize, "RIGHT")
		row.detail:SetPoint("RIGHT", -2, 0)
		row.text = ns.CreateFontString(row, h.fontSize)
		row.text:SetPoint("RIGHT", row.detail, "LEFT", -6, 0)
		row:RegisterForClicks("LeftButtonUp")
		row:SetScript("OnClick", OnRowClick)
		row:SetScript("OnEnter", OnRowEnter)
		row:SetScript("OnLeave", GameTooltip_Hide)
	end
	row.data = data
	local record = data.record
	row.text:ClearAllPoints()
	row.text:SetPoint("RIGHT", row.detail, "LEFT", -6, 0)
	row.detail:SetText("")
	if data.kind == "header" then
		row.icon:Hide()
		row.text:SetPoint("LEFT", 2, -2)
		row.text:SetText(Logic.HeaderText(record, FormatDate, T("Loot", "Beute")))
		row.text:SetTextColor(0.6, 0.6, 0.6)
		row:GetHighlightTexture():SetAlpha(0)
	elseif data.kind == "drop" then
		row.icon:Show()
		row.icon:ClearAllPoints()
		row.icon:SetPoint("LEFT", 2, 0)
		row.icon:SetTexture(C_Item.GetItemIconByID(record.link) or 134400) -- question mark
		row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
		row.text:SetText(LinkName(record.link))
		row.text:SetTextColor(LinkColor(record.link))
		row.detail:SetText(DropDetail(record))
		row:GetHighlightTexture():SetAlpha(1)
	else
		local roll = data.roll
		local L = ns.RollCards.L
		row.icon:Hide()
		row.text:SetPoint("LEFT", 2 + h.iconSize + 6, 0)
		row.text:SetText(roll.isSelf and L.you or ns.RollCards.ClassColored(roll.name or "?", roll.class))
		row.text:SetTextColor(1, 1, 1)
		row.detail:SetText("|cffaaaaaa" .. Logic.RollText(roll, ns.RollCards.stateLabels) .. "|r")
		row:GetHighlightTexture():SetAlpha(1)
	end
end

local function RowHeight(data)
	local h = config.history
	if data.kind == "header" then
		return h.headerHeight
	elseif data.kind == "drop" then
		return h.rowHeight
	end
	return h.rollHeight
end

-- Window -------------------------------------------------------------------------

local function TextButton(parent, text, onClick)
	local button = CreateFrame("Button", nil, parent)
	button.label = ns.CreateFontString(button, 12, "CENTER")
	button.label:SetPoint("CENTER")
	button.label:SetText(text)
	button:SetSize(math.max(20, button.label:GetStringWidth() + 12), 20)
	button:SetHighlightTexture(style.texture)
	button:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.1)
	button:SetScript("OnClick", onClick)
	return button
end

-- Clears what the window shows: while previewing only the made-up records.
local function Clear()
	wipe(Shown())
	wipe(expanded)
	History.Refresh()
end

StaticPopupDialogs.STEVIOUI_CLEAR_ROLL_HISTORY = {
	text = T("Delete the whole roll history?", "Den ganzen Würfelverlauf löschen?"),
	button1 = YES,
	button2 = NO,
	OnAccept = Clear,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

-- The loot ticker's column and height (Modules/LootTicker/Config.lua).
local function TickerSize()
	local ticker = ns.config.lootTicker
	return ticker.width, ticker.maxRows * (ticker.iconSize + ticker.rowGap) - ticker.rowGap
end

local function CreateWindow()
	local width, height = TickerSize()
	frame = CreateFrame("Frame", "StevioUI_RollHistory", UIParent)
	frame:SetSize(width, height)
	ns.SetPoint(frame, ns.LayoutPosition("lootTicker"))
	frame:SetFrameStrata("MEDIUM")
	frame:EnableMouse(true)
	frame:Hide()
	ns.CreatePanel(frame, { color = ns.PanelColor() })
	-- Lets Escape close the window like any Blizzard panel.
	tinsert(UISpecialFrames, frame:GetName())
	frame:SetScript("OnShow", function()
		if ns.SetLootTickerShown then
			ns.SetLootTickerShown(false)
		end
		History.Refresh()
	end)
	frame:SetScript("OnHide", function()
		if ns.SetLootTickerShown then
			ns.SetLootTickerShown(true)
		end
		previewRecords = nil
	end)

	local title = ns.CreateFontString(frame, 14)
	title:SetPoint("TOPLEFT", 8, -9)
	title:SetText(T("Loot rolls", "Beutewürfe"))

	local close = ns.CreateCloseButton(frame, 20, function()
		frame:Hide()
	end)
	close:SetPoint("TOPRIGHT", -4, -5)
	local clear = TextButton(frame, T("Clear", "Löschen"), function()
		StaticPopup_Show("STEVIOUI_CLEAR_ROLL_HISTORY")
	end)
	clear:SetPoint("RIGHT", close, "LEFT", -4, 0)

	mineButton = TextButton(frame, T("Mine", "Meine"), function()
		filter.mineOnly = not filter.mineOnly
		History.Refresh()
	end)
	mineButton:SetPoint("TOPRIGHT", -4, -32)
	mineButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(
			T("Only drops you rolled on or won", "Nur Beute, auf die du gewürfelt oder die du gewonnen hast")
		)
		GameTooltip:Show()
	end)
	mineButton:SetScript("OnLeave", GameTooltip_Hide)

	search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	search:SetHeight(20)
	search:SetPoint("TOPLEFT", 14, -32)
	search:SetPoint("RIGHT", mineButton, "LEFT", -8, 0)
	search:SetAutoFocus(false)
	search:SetScript("OnEnterPressed", search.ClearFocus)
	search:SetScript("OnEscapePressed", search.ClearFocus)
	search.hint = search:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	search.hint:SetPoint("LEFT", 2, 0)
	search.hint:SetText(T("Search item, boss or player", "Gegenstand, Boss oder Spieler suchen"))
	search:SetScript("OnTextChanged", function(self)
		self.hint:SetShown(self:GetText() == "")
		filter.search = self:GetText():lower()
		History.Refresh()
	end)

	scrollBox = CreateFrame("Frame", nil, frame, "WowScrollBoxList")
	local scrollBar = CreateFrame("EventFrame", nil, frame, "MinimalScrollBar")
	scrollBar:SetPoint("TOPRIGHT", -6, -60)
	scrollBar:SetPoint("BOTTOMRIGHT", -6, 6)

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtentCalculator(function(_, data)
		return RowHeight(data)
	end)
	view:SetElementInitializer("Button", InitRow)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

	-- The scroll bar only shows (and takes room) when the list doesn't fit.
	local withBar = {
		CreateAnchor("TOPLEFT", frame, "TOPLEFT", 6, -60),
		CreateAnchor("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6 - SCROLL_BAR_SPACE, 6),
	}
	local withoutBar = {
		CreateAnchor("TOPLEFT", frame, "TOPLEFT", 6, -60),
		CreateAnchor("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6),
	}
	ScrollUtil.AddManagedScrollBarVisibilityBehavior(scrollBox, scrollBar, withBar, withoutBar)
end

-- Data -----------------------------------------------------------------------------

function History.SetRecords(saved)
	records = saved
	History.Refresh()
end

function History.Toggle()
	if not frame then
		CreateWindow()
	end
	frame:SetShown(not frame:IsShown())
end

-- Opens the window on made-up records until it is closed again.
function History.Preview(sample)
	if not frame then
		CreateWindow()
	end
	previewRecords = sample
	if frame:IsShown() then
		History.Refresh()
	else
		frame:Show()
	end
end
