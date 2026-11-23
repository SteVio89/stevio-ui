local _, ns = ...

local config = ns.config.chat
local style = ns.config.style
local C = ns.ChatInternal

-- The channel view: sidebar with the channels, header, messages and input line.

-- A message frame can't draw lines, so the date line is made of dashes.
local function DayLine(entry)
	return C.GREY .. "——  " .. C.Day(entry.time) .. "  ——|r"
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

-- Muted until hovered, like the other icons; the ✕ is two crossed lines,
-- as the standard font has no such glyph.
local function CreateDeleteButton(row)
	local button = CreateFrame("Button", nil, row)
	button:SetSize(config.rowHeight, config.rowHeight)
	button:SetPoint("RIGHT")
	local px = ns.PixelSize(row)
	for _, angle in ipairs({ 45, -45 }) do
		local line = button:CreateTexture(nil, "ARTWORK")
		line:SetSize(9, 1.5 * px)
		line:SetPoint("CENTER")
		line:SetColorTexture(unpack(config.deleteColor))
		line:SetRotation(math.rad(angle))
	end
	button:SetScript("OnClick", function()
		C.DeleteChannel(row.key)
	end)
	button:Hide()
	return button
end

-- The ✕ shows while the cursor is over a deletable row, in place of the unread pill.
local function UpdateRowHover(row)
	local over = row:IsMouseOver() and row.deletable
	row.delete:SetShown(over)
	row.pill:SetShown(row.unread > 0 and not over)
end

local function CreateRow()
	local ui = C.ui
	local palette = style.palette
	local row = CreateFrame("Button", nil, ui.list)
	row:SetHeight(config.rowHeight)

	row.highlight = row:CreateTexture(nil, "BACKGROUND")
	row.highlight:SetAllPoints()
	row.highlight:SetColorTexture(unpack(palette.selected))
	row.marker = row:CreateTexture(nil, "ARTWORK")
	row.marker:SetSize(2, config.rowHeight - 4)
	row.marker:SetPoint("LEFT")
	row.marker:SetColorTexture(unpack(palette.accent))

	row.text = ns.CreateFontString(row, config.sidebarFontSize, "LEFT")
	row.text:SetPoint("LEFT", 8, 0)
	row.text:SetPoint("RIGHT", -config.rowHeight, 0)

	-- The unread count, right aligned in a pill.
	row.pill = CreateFrame("Frame", nil, row)
	row.pill:SetHeight(14)
	row.pill:SetPoint("RIGHT", -4, 0)
	ns.CreateBackground(row.pill, palette.pill)
	row.pill.text = ns.CreateFontString(row.pill, config.sidebarFontSize - 3, "CENTER")
	row.pill.text:SetPoint("CENTER")
	row.pill.text:SetTextColor(unpack(palette.pillText))

	row.delete = CreateDeleteButton(row)
	row.unread = 0
	local function Hover()
		UpdateRowHover(row)
	end
	row:SetScript("OnEnter", Hover)
	row:SetScript("OnLeave", Hover)
	row.delete:SetScript("OnEnter", Hover)
	row.delete:SetScript("OnLeave", Hover)

	row:SetScript("OnClick", function()
		C.Select(row.key)
	end)
	return row
end

-- A section heading of the sidebar (not clickable).
local function CreateHeading()
	local heading = ns.CreateFontString(C.ui.list, config.sidebarFontSize - 3, "LEFT")
	heading:SetHeight(config.headerHeight)
	heading:SetJustifyV("MIDDLE")
	heading:SetTextColor(unpack(style.palette.textFaint))
	return heading
end

-- Scrolls the channel list to `offset` (clamped) and moves the scroll thumb.
local function SetSidebarScroll(offset)
	local ui = C.ui
	local listHeight = ui.listHeight or 0
	local viewHeight = ui.listScroll:GetHeight()
	offset = C.ClampSidebarScroll(offset, viewHeight, listHeight)
	ui.listScroll:SetVerticalScroll(offset)
	if viewHeight <= 0 or listHeight <= viewHeight then
		ui.thumb:Hide()
		return
	end
	ui.thumb:SetHeight(viewHeight * viewHeight / listHeight)
	ui.thumb:SetPoint("TOPRIGHT", ui.sidebar, "TOPRIGHT", 0, -viewHeight * offset / listHeight)
	ui.thumb:Show()
end

local function ShowRow(row, entry, top)
	local channel = entry.channel
	local palette = style.palette
	row.key = channel.key
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", 0, -top)
	row:SetPoint("TOPRIGHT", 0, -top)

	local selected = channel.key == C.state.selected
	local unread = C.Unread(channel)
	row.unread = unread
	row.text:SetText(entry.label)
	if selected then
		row.text:SetTextColor(unpack(palette.textStrong))
	else
		local r, g, b = C.ChannelColor(channel)
		row.text:SetTextColor(r, g, b, unread > 0 and 1 or 0.7)
	end
	row.highlight:SetShown(selected)
	row.marker:SetShown(selected)
	if unread > 0 then
		row.pill.text:SetText(unread)
		row.pill:SetWidth(row.pill.text:GetStringWidth() + 10)
	end
	row.deletable = C.store.IsDeletable(channel, config.main.enabled)
	UpdateRowHover(row)
	row:Show()
	return selected
end

-- "Main › Party": the channel in strong text, the one Main writes to in its color.
local function RefreshHeader()
	local ui, palette = C.ui, style.palette
	local channel = C.Selected()
	if not channel then
		ui.header:SetText("")
		return
	end
	local text = ns.Hex(palette.textStrong) .. C.Label(channel) .. "|r"
	local target = C.IsMain(channel.key) and C.MainTarget()
	if target then
		text = ("%s %s›|r %s%s|r"):format(
			text,
			ns.Hex(palette.textFaint),
			C.ColorCode(C.ChannelColor(target)),
			C.Label(target)
		)
	end
	ui.header:SetText(text)
end

function C.RefreshSidebar()
	local ui, store = C.ui, C.store
	local entries = C.SidebarEntries(store:Sorted(config.kindOrder))
	local tops, listHeight = C.SidebarLayout(entries, config.rowHeight, config.headerHeight)
	local rowCount, headingCount = 0, 0
	local selectedIndex
	for index, entry in ipairs(entries) do
		if entry.header then
			headingCount = headingCount + 1
			local heading = ui.headings[headingCount] or CreateHeading()
			ui.headings[headingCount] = heading
			heading:SetText(entry.header:upper())
			heading:ClearAllPoints()
			heading:SetPoint("TOPLEFT", 8, -tops[index])
			heading:SetPoint("TOPRIGHT", -4, -tops[index])
			heading:Show()
		else
			rowCount = rowCount + 1
			local row = ui.rows[rowCount] or CreateRow()
			ui.rows[rowCount] = row
			if ShowRow(row, entry, tops[index]) then
				selectedIndex = index
			end
		end
	end
	for index = rowCount + 1, #ui.rows do
		ui.rows[index]:Hide()
	end
	for index = headingCount + 1, #ui.headings do
		ui.headings[index]:Hide()
	end

	-- More channels than fit scroll; a newly selected one is scrolled into view,
	-- otherwise the list stays where the player scrolled it.
	ui.listHeight = listHeight
	ui.list:SetHeight(math.max(1, listHeight))
	local offset = ui.listScroll:GetVerticalScroll()
	local viewHeight = ui.listScroll:GetHeight()
	if selectedIndex and viewHeight > 0 and C.state.selected ~= ui.scrolledTo then
		offset = C.ScrollToRow(offset, viewHeight, tops[selectedIndex], config.rowHeight)
		ui.scrolledTo = C.state.selected
	end
	SetSidebarScroll(offset)

	RefreshHeader()
	C.RefreshInput()
end

-- The input line's placeholder (where it writes to) and its border: grey,
-- or the target channel's color while typing.
function C.RefreshInput()
	local input = C.ui.input
	local hint, target = C.InputHint(C.Selected())
	input.hint:SetText(hint)
	input.hint:SetShown(input:GetText() == "")
	if input:HasFocus() and target then
		input.border:SetColor(C.ChannelColor(target))
	else
		input.border:SetColor(unpack(config.inputBorderColor))
	end
end

local function CreateInput(frame)
	local ui = C.ui
	local input = CreateFrame("EditBox", nil, frame)
	C.ApplyFont(input)
	input:SetAutoFocus(false)
	input:SetHeight(math.max(config.rowHeight, config.fontSize + 6))
	input:SetPoint("BOTTOMLEFT", ui.sidebar, "BOTTOMRIGHT", 6, 4)
	input:SetPoint("BOTTOMRIGHT", -6, 4)
	input:SetTextInsets(4, 4, 0, 0)
	input:SetMaxLetters(255)
	ns.CreateBackground(input, config.inputBackgroundColor)
	input.border = ns.CreateBorder(input)
	input.hint = ns.CreateFontString(input, config.fontSize, "LEFT")
	input.hint:SetPoint("LEFT", 4, 0)
	input.hint:SetPoint("RIGHT", -4, 0)
	input.hint:SetTextColor(unpack(style.palette.textFaint))
	input:SetScript("OnTextChanged", function(self)
		self.hint:SetShown(self:GetText() == "")
	end)
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
		C.Pin()
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
	messages:SetPoint("TOPLEFT", ui.header, "BOTTOMLEFT", 0, -7)
	messages:SetPoint("BOTTOMRIGHT", ui.input, "TOPRIGHT", 0, 6)
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
		-- A modified click on a name whispers through a chat frame's edit box
		-- (ChatFrameUtil.SendTell), which this view doesn't have: Blizzard's chat
		-- frame takes it instead of erroring.
		SetItemRef(link, text, button, player and DEFAULT_CHAT_FRAME or self)
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
	-- The panel color without its alpha: the background's opacity is its own (below).
	local panel = style.palette.panel
	ui.background = ns.CreateBackground(frame, { panel[1], panel[2], panel[3], 1 }, -7)
	-- No glass edge: its light line reads as a second border (#77).
	ns.CreateBorder(frame)
	ns.CreateShadow(frame)
	C.GREY = ns.Hex(style.palette.textFaint)
	ui.frame = frame
	-- The background turns solid while the chat is read closely (#69); a chat
	-- that just showed starts at its opacity instead of fading to it.
	local function TargetAlpha()
		local active = frame:IsMouseOver() or C.state.typing or ui.input:HasFocus() or ui.copy:IsShown()
		return C.BackgroundAlpha(active)
	end
	frame:SetScript("OnShow", function()
		ui.background:SetAlpha(TargetAlpha())
	end)
	frame:SetScript("OnUpdate", function(_, elapsed)
		local current, target = ui.background:GetAlpha(), TargetAlpha()
		if current ~= target then
			local step = config.fadeTime > 0 and elapsed / config.fadeTime or 1
			ui.background:SetAlpha(C.Approach(current, target, step))
		end
	end)
	ui.rows = {}
	ui.headings = {}

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
	local headerLine = frame:CreateTexture(nil, "ARTWORK")
	headerLine:SetColorTexture(unpack(config.dividerColor))
	headerLine:SetHeight(ns.PixelSize(frame))
	headerLine:SetPoint("TOPLEFT", ui.header, "BOTTOMLEFT", 0, -3)
	headerLine:SetPoint("RIGHT", frame, "RIGHT", -6, 0)

	CreateInput(frame)
	CreateMessages(frame)
	C.CreateCopyView(frame)
end
