local _, ns = ...

local config = ns.config.chat
local C = ns.ChatInternal

-- The channel view: sidebar with the channels, header, messages and input line.

local function DayLine(entry)
	return C.GREY .. "-- " .. C.Day(entry.time) .. " --|r"
end

-- Adds `entry` to the message frame, after a date line when it starts a new
-- day; `previous` is the last message shown before it.
function C.ShowEntry(channel, previous, entry)
	if ns.ChatHistory.StartsDay(previous, entry, C.Day) then
		C.ui.messages:AddMessage(DayLine(entry))
	end
	local line, r, g, b = C.FormatEntry(channel, entry, C.TypeColor)
	C.ui.messages:AddMessage(line, r or 1, g or 1, b or 1)
end

function C.RenderMessages(channel)
	local messages = C.ui.messages
	messages:Clear()
	if not channel then
		return
	end
	local previous
	for _, entry in ipairs(channel.messages) do
		C.ShowEntry(channel, previous, entry)
		previous = entry.time and entry or previous
	end
	messages:ScrollToBottom()
end

-- Opens channel `key` in the message area, closing the copy view; returns the
-- channel. The sidebar and unread counts are left to the caller.
function C.ShowChannel(key)
	C.state.selected = key
	C.ui.copy:Hide()
	local channel = C.Selected()
	C.RenderMessages(channel)
	return channel
end

local function CreateRow(index)
	local ui = C.ui
	local row = CreateFrame("Button", nil, ui.list)
	row:SetHeight(config.rowHeight)
	row:SetPoint("TOPLEFT", 0, -(index - 1) * config.rowHeight)
	row:SetPoint("TOPRIGHT", 0, -(index - 1) * config.rowHeight)

	row.highlight = row:CreateTexture(nil, "BACKGROUND")
	row.highlight:SetAllPoints()
	row.highlight:SetColorTexture(unpack(config.selectedColor))

	row.text = ns.CreateFontString(row, config.sidebarFontSize, "LEFT")
	row.text:SetPoint("LEFT", 4, 0)
	row.text:SetPoint("RIGHT", -config.rowHeight, 0)

	row.delete = CreateFrame("Button", nil, row)
	row.delete:SetSize(config.rowHeight, config.rowHeight)
	row.delete:SetPoint("RIGHT")
	row.delete.text = ns.CreateFontString(row.delete, config.sidebarFontSize, "CENTER")
	row.delete.text:SetAllPoints()
	row.delete.text:SetText("x")
	row.delete.text:SetTextColor(unpack(config.deleteColor))
	row.delete:SetScript("OnClick", function()
		C.DeleteChannel(row.key)
	end)

	row:SetScript("OnClick", function()
		C.Select(row.key)
	end)
	return row
end

-- Scrolls the channel list to `offset` (clamped) and moves the scroll thumb.
local function SetSidebarScroll(offset)
	local ui = C.ui
	local count = ui.rowCount or 0
	local viewHeight = ui.listScroll:GetHeight()
	offset = C.ClampSidebarScroll(offset, viewHeight, count, config.rowHeight)
	ui.listScroll:SetVerticalScroll(offset)
	local listHeight = count * config.rowHeight
	if viewHeight <= 0 or listHeight <= viewHeight then
		ui.thumb:Hide()
		return
	end
	ui.thumb:SetHeight(viewHeight * viewHeight / listHeight)
	ui.thumb:SetPoint("TOPRIGHT", ui.sidebar, "TOPRIGHT", 0, -viewHeight * offset / listHeight)
	ui.thumb:Show()
end

function C.RefreshSidebar()
	local ui, store = C.ui, C.store
	local channels = store:Sorted(config.kindOrder)
	local selectedIndex
	for index, channel in ipairs(channels) do
		local row = ui.rows[index] or CreateRow(index)
		ui.rows[index] = row
		row.key = channel.key
		local r, g, b = C.ChannelColor(channel)
		local text = C.Label(channel)
		local unread = C.Unread(channel)
		if unread > 0 then
			text = ("%s (%d)"):format(text, unread)
		end
		row.text:SetText(text)
		row.text:SetTextColor(r, g, b, unread > 0 and 1 or 0.7)
		row.highlight:SetShown(channel.key == C.state.selected)
		if channel.key == C.state.selected then
			selectedIndex = index
		end
		row.delete:SetShown(store.IsDeletable(channel, config.main.enabled))
		row:Show()
	end
	for index = #channels + 1, #ui.rows do
		ui.rows[index]:Hide()
	end

	-- More channels than fit scroll; a newly selected one is scrolled into view,
	-- otherwise the list stays where the player scrolled it.
	ui.rowCount = #channels
	ui.list:SetHeight(math.max(1, #channels * config.rowHeight))
	local offset = ui.listScroll:GetVerticalScroll()
	local viewHeight = ui.listScroll:GetHeight()
	if selectedIndex and viewHeight > 0 and C.state.selected ~= ui.scrolledTo then
		offset = C.ScrollToRow(offset, viewHeight, selectedIndex, config.rowHeight)
		ui.scrolledTo = C.state.selected
	end
	SetSidebarScroll(offset)

	local channel = C.Selected()
	if channel then
		local r, g, b = C.ChannelColor(channel)
		local text = C.Label(channel)
		-- Main names the channel it writes to: "Main > Party".
		local target = C.IsMain(channel.key) and C.MainTarget()
		if target then
			text = ("%s > %s%s|r"):format(text, C.ColorCode(C.ChannelColor(target)), C.Label(target))
		end
		ui.header:SetText(text)
		ui.header:SetTextColor(r, g, b)
	else
		ui.header:SetText("")
	end
end

local function CreateInput(frame)
	local ui = C.ui
	local input = CreateFrame("EditBox", nil, frame)
	C.ApplyFont(input)
	input:SetAutoFocus(false)
	input:SetHeight(math.max(config.rowHeight, config.fontSize + 6))
	input:SetPoint("BOTTOMLEFT", ui.sidebar, "BOTTOMRIGHT", 6, 2)
	input:SetPoint("BOTTOMRIGHT", -6, 2)
	input:SetMaxLetters(255)
	input:SetScript("OnEnterPressed", function(self)
		local text = self:GetText()
		self:SetText("")
		self:ClearFocus()
		C.Send(text)
	end)
	input:SetScript("OnEscapePressed", input.ClearFocus)
	input:SetScript("OnTabPressed", function()
		C.CycleChannel(IsShiftKeyDown() and -1 or 1)
	end)
	-- Main keeps the channel it writes to while typing, so a line arriving
	-- elsewhere doesn't redirect the message.
	input:SetScript("OnEditFocusGained", function()
		C.state.typing = true
		if C.IsMain(C.state.selected) and not C.state.mainTarget then
			local target = C.MainTarget()
			C.state.mainTarget = target and target.key
		end
		C.Update()
	end)
	input:SetScript("OnEditFocusLost", function()
		C.state.typing = false
		C.state.mainTarget = nil
		C.Update()
	end)
	ui.input = input
end

local function CreateMessages(frame)
	local ui = C.ui
	local messages = CreateFrame("ScrollingMessageFrame", nil, frame)
	C.ApplyFont(messages)
	messages:SetJustifyH("LEFT")
	messages:SetFading(false)
	-- Room for a date line before each message, so date lines never push
	-- stored messages out of the view.
	messages:SetMaxLines(config.historyLimit * 2)
	messages:SetPoint("TOPLEFT", ui.header, "BOTTOMLEFT", 0, -4)
	messages:SetPoint("BOTTOMRIGHT", ui.input, "TOPRIGHT", 0, 4)
	messages:EnableMouseWheel(true)
	messages:SetScript("OnMouseWheel", function(self, delta)
		for _ = 1, config.scrollStep do
			if delta > 0 then
				self:ScrollUp()
			else
				self:ScrollDown()
			end
		end
	end)
	messages:SetHyperlinksEnabled(true)
	-- A click on a channel tag in Main writes to that channel;
	-- a left click on a player's name opens the whisper channel with them,
	-- a right click our menu for them (see C.ShowPlayerMenu);
	-- other clicks (shift click, ...) and links stay Blizzard's.
	messages:SetScript("OnHyperlinkClick", function(self, link, text, button)
		local channelKey = ns.ChatHistory.LinkedChannel(link)
		if channelKey then
			C.PickMainTarget(channelKey)
			return
		end
		local player = ns.ChatHistory.LinkedPlayer(link)
		if player and button == "LeftButton" and not IsModifierKeyDown() then
			C.OpenWhisper(player)
			return
		end
		if player and button == "RightButton" and not IsModifierKeyDown() then
			C.ShowPlayerMenu(self, player)
			return
		end
		SetItemRef(link, text, button, self)
	end)
	ui.messages = messages
end

-- The sidebar's channel rows sit in a scroll frame, which clips them, so a
-- long list scrolls with the mouse wheel instead of running out of the chat.
local function CreateChannelList()
	local ui = C.ui
	local scroll = CreateFrame("ScrollFrame", nil, ui.sidebar)
	scroll:SetAllPoints()
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		SetSidebarScroll(self:GetVerticalScroll() - delta * config.rowHeight)
	end)
	scroll:SetScript("OnSizeChanged", function(self)
		SetSidebarScroll(self:GetVerticalScroll())
	end)

	local list = CreateFrame("Frame", nil, scroll)
	list:SetSize(config.sidebarWidth, 1)
	scroll:SetScrollChild(list)

	local thumb = ui.sidebar:CreateTexture(nil, "OVERLAY")
	thumb:SetColorTexture(unpack(config.scrollThumbColor))
	thumb:SetWidth(2)
	thumb:Hide()

	ui.listScroll, ui.list, ui.thumb = scroll, list, thumb
end

function C.CreateChannelView()
	local ui = C.ui
	local frame = CreateFrame("Frame", "StevioUI_Chat", UIParent)
	frame:SetSize(C.ChatWidth(), config.height)
	ns.SetPoint(frame, ns.layout.chat)
	frame:SetFrameStrata("MEDIUM")
	frame:EnableMouse(true)
	frame:Hide()
	ns.CreateBackground(frame, config.backgroundColor, -8)
	ns.CreateBorder(frame)
	ui.frame = frame
	ui.rows = {}

	ui.sidebar = CreateFrame("Frame", nil, frame)
	ui.sidebar:SetWidth(config.sidebarWidth)
	ui.sidebar:SetPoint("TOPLEFT", 0, -4)
	ui.sidebar:SetPoint("BOTTOMLEFT")
	CreateChannelList()
	local divider = frame:CreateTexture(nil, "ARTWORK")
	divider:SetColorTexture(unpack(config.dividerColor))
	divider:SetWidth(ns.PixelSize(frame))
	divider:SetPoint("TOPLEFT", ui.sidebar, "TOPRIGHT")
	divider:SetPoint("BOTTOMLEFT", ui.sidebar, "BOTTOMRIGHT")

	ui.header = ns.CreateFontString(frame, config.sidebarFontSize, "LEFT")
	ui.header:SetPoint("TOPLEFT", ui.sidebar, "TOPRIGHT", 6, 0)

	CreateInput(frame)
	CreateMessages(frame)
	C.CreateCopyView(frame)
end
