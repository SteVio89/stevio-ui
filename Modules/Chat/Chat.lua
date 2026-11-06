local _, ns = ...

local config = ns.config.chat
local style = ns.config.style
local badgeStyle = style.badge

local Chat = ns:RegisterModule("chat", {})

-- The chat is hidden through alpha and disabled mouse input instead of Hide():
-- Blizzard's chat code checks IsShown() to pick and focus the input box, and
-- focusing it from addon code is restricted. Invisible-but-shown keeps all of
-- Blizzard's chat behaviour intact.

local chatFrames = {}
local tabs = {}
local editBoxes = {}
local hidden = false
local applyingAlpha = false

local state = {
	manual = false,
	typing = false,
	autoTimer = nil,
	selected = nil, -- key of the open channel
}
local store
local badge
local ui = {} -- frame, header, messages, input, rows

-- Blizzard's chat windows are never shown: the channel view below replaces them.
-- Only their input box is still used (Enter / slash commands) while typing.
local function IsSuppressed(frame)
	return hidden or not editBoxes[frame]
end

local function ApplyAlpha(frame)
	applyingAlpha = true
	frame:SetAlpha(IsSuppressed(frame) and 0 or 1)
	applyingAlpha = false
end

-- Blizzard fades tabs and flashes them on new messages via SetAlpha, which
-- would make them pop up on an otherwise hidden chat.
local function GuardAlpha(frame)
	hooksecurefunc(frame, "SetAlpha", function(self)
		if IsSuppressed(self) and not applyingAlpha then
			ApplyAlpha(self)
		end
	end)
end

local function ManageChatFrame(frame)
	if chatFrames[frame] then
		return
	end
	chatFrames[frame] = true

	ns.KeepHidden(frame.buttonFrame)
	GuardAlpha(frame)

	local tab = _G[frame:GetName() .. "Tab"]
	if tab and not tabs[tab] then
		tabs[tab] = true
		GuardAlpha(tab)
	end

	-- Blizzard parents the input box to UIParent, so it doesn't inherit the chat's alpha.
	local editBox = frame.editBox
	if editBox and not editBoxes[editBox] then
		editBoxes[editBox] = true
		GuardAlpha(editBox)
	end
end

local function ScanChatFrames()
	for _, name in ipairs(CHAT_FRAMES) do
		ManageChatFrame(_G[name])
	end
end

local function ApplyVisibility()
	for frame in pairs(chatFrames) do
		ApplyAlpha(frame)
		frame:EnableMouse(false)
		frame:EnableMouseWheel(false)
	end
	for tab in pairs(tabs) do
		ApplyAlpha(tab)
		tab:EnableMouse(false)
	end
	for editBox in pairs(editBoxes) do
		ApplyAlpha(editBox)
		editBox:EnableMouse(not hidden)
	end
	ApplyAlpha(GeneralDockManager)
	ui.frame:SetShown(not hidden)
end

local function ChatWidth()
	return Clamp(math.floor(UIParent:GetWidth() * config.widthFraction), 250, 800)
end

local function ChannelColor(channel)
	local info = ChatTypeInfo[channel.chatType]
	if info and info.r then
		return info.r, info.g, info.b
	end
	return 1, 1, 1
end

local function ColorCode(r, g, b)
	return ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255)
end

local function UpdateBadge()
	for _, segment in ipairs(config.badge.segments) do
		local texture = badge.segments[segment.category]
		if not hidden then
			texture:SetColorTexture(unpack(badgeStyle.shownColor))
		elseif store:HasUnread(segment.category) then
			local info = ChatTypeInfo[segment.chatType]
			if info and info.r then
				texture:SetColorTexture(info.r, info.g, info.b, 1)
			else
				texture:SetColorTexture(unpack(segment.fallbackColor))
			end
		else
			texture:SetColorTexture(unpack(badgeStyle.hiddenColor))
		end
	end
end

-- Opening the chat by hand (toggle key, typing, clicking) counts as reading;
-- the brief auto-show of an incoming message doesn't.
local function Attended()
	return state.manual or state.typing
end

local function FormatEntry(channel, entry)
	local r, g, b = ChannelColor(channel)
	local stamp = entry.time and date("%H:%M", entry.time) or "--:--"
	return ("|cff808080%s|r %s%s|r: %s"):format(stamp, ColorCode(r, g, b), entry.sender or "?", entry.text)
end

local function RenderMessages(channel)
	local messages = ui.messages
	messages:Clear()
	if not channel then
		return
	end
	for _, entry in ipairs(channel.messages) do
		messages:AddMessage(FormatEntry(channel, entry))
	end
	messages:ScrollToBottom()
end

local function Selected()
	return state.selected and store:Get(state.selected)
end

local RefreshSidebar

local function Select(key)
	state.selected = key
	local channel = Selected()
	if channel and Attended() then
		store:MarkRead(key)
	end
	RenderMessages(channel)
	RefreshSidebar()
end

local function DeleteChannel(key)
	if not store:Delete(key) then
		return
	end
	if state.selected == key then
		state.selected = nil
		local first = store:Sorted(config.kindOrder)[1]
		Select(first and first.key)
	else
		RefreshSidebar()
	end
	UpdateBadge()
end

local function CreateRow(index)
	local row = CreateFrame("Button", nil, ui.sidebar)
	row:SetHeight(config.rowHeight)
	row:SetPoint("TOPLEFT", 0, -(index - 1) * config.rowHeight)
	row:SetPoint("TOPRIGHT", 0, -(index - 1) * config.rowHeight)

	row.highlight = row:CreateTexture(nil, "BACKGROUND")
	row.highlight:SetAllPoints()
	row.highlight:SetColorTexture(unpack(config.selectedColor))

	row.text = ns.CreateFontString(row, nil, "LEFT")
	row.text:SetPoint("LEFT", 4, 0)
	row.text:SetPoint("RIGHT", -config.rowHeight, 0)

	row.delete = CreateFrame("Button", nil, row)
	row.delete:SetSize(config.rowHeight, config.rowHeight)
	row.delete:SetPoint("RIGHT")
	row.delete.text = ns.CreateFontString(row.delete, nil, "CENTER")
	row.delete.text:SetAllPoints()
	row.delete.text:SetText("x")
	row.delete.text:SetTextColor(unpack(config.deleteColor))
	row.delete:SetScript("OnClick", function()
		DeleteChannel(row.key)
	end)

	row:SetScript("OnClick", function()
		Select(row.key)
	end)
	return row
end

function RefreshSidebar()
	local channels = store:Sorted(config.kindOrder)
	for index, channel in ipairs(channels) do
		local row = ui.rows[index] or CreateRow(index)
		ui.rows[index] = row
		row.key = channel.key
		local r, g, b = ChannelColor(channel)
		local text = channel.label
		if channel.unread > 0 then
			text = ("%s (%d)"):format(text, channel.unread)
		end
		row.text:SetText(text)
		row.text:SetTextColor(r, g, b, channel.unread > 0 and 1 or 0.7)
		row.highlight:SetShown(channel.key == state.selected)
		row.delete:SetShown(store.IsDeletable(channel))
		row:Show()
	end
	for index = #channels + 1, #ui.rows do
		ui.rows[index]:Hide()
	end

	local channel = Selected()
	if channel then
		local r, g, b = ChannelColor(channel)
		ui.header:SetText(channel.label)
		ui.header:SetTextColor(r, g, b)
	else
		ui.header:SetText("")
	end
end

local function Update()
	hidden = not (state.manual or state.typing or state.autoTimer)
	if not state.selected or not Selected() then
		local first = store:Sorted(config.kindOrder)[1]
		state.selected = first and first.key
		RenderMessages(Selected())
	end
	if Attended() and state.selected then
		store:MarkRead(state.selected)
	end
	ApplyVisibility()
	RefreshSidebar()
	UpdateBadge()
end

local function IsMouseOverChat()
	return ui.frame:IsVisible() and ui.frame:IsMouseOver()
end

local function StartAutoTimer(duration)
	if state.autoTimer then
		state.autoTimer:Cancel()
	end
	state.autoTimer = C_Timer.NewTimer(duration, function()
		-- Hiding the chat under the cursor would yank away what's being read.
		if IsMouseOverChat() or ui.input:HasFocus() then
			StartAutoTimer(1)
			return
		end
		state.autoTimer = nil
		Update()
	end)
end

-- Whisper partners are keyed by name (or Battle.net id), group chats by type.
local function ChannelFor(def, sender, bnetID)
	if def.key then
		return def.key, { kind = def.kind, chatType = def.chatType, label = def.label }
	end
	if def.bnet then
		return "bn:" .. bnetID, { kind = def.kind, chatType = def.chatType, label = sender, bnetID = bnetID }
	end
	return "whisper:" .. sender, { kind = def.kind, chatType = def.chatType, label = sender, target = sender }
end

-- Message contents may be secret (e.g. in encounters): those can't be stored and
-- only light up the channel as unread.
local function OnChatMessage(event, text, sender, ...)
	local def = config.events[event]
	local bnetID = select(11, ...)
	local secret = issecretvalue(text) or issecretvalue(sender) or issecretvalue(bnetID)
	if secret and not def.key then
		return -- no way to tell which whisper channel this belongs to
	end
	if not secret and not def.bnet then
		sender = Ambiguate(sender, "short")
	end

	local key, opts = ChannelFor(def, sender, bnetID)
	local viewing = Attended() and state.selected == key
	if secret then
		store:AddUnreadOnly(key, opts, time())
	else
		local entry = {
			time = time(),
			sender = def.outgoing and UnitName("player") or sender,
			text = (def.prefix or "") .. text,
			outgoing = def.outgoing,
		}
		store:Add(key, opts, entry, not viewing and not def.outgoing)
		if state.selected == key then
			ui.messages:AddMessage(FormatEntry(store:Get(key), entry))
		end
	end

	-- Peek at the channel the message arrived in while the chat is hidden.
	if hidden and not def.outgoing then
		state.selected = key
		RenderMessages(store:Get(key))
	end
	if not def.outgoing then
		StartAutoTimer(config.autoShowDuration)
	end
	Update()
end

local function Send(text)
	local channel = Selected()
	if not channel or text == "" then
		return
	end
	if channel.bnetID then
		BNSendWhisper(channel.bnetID, text)
	elseif channel.kind == "whisper" then
		SendChatMessage(text, "WHISPER", nil, channel.target)
	else
		SendChatMessage(text, channel.chatType)
	end
end

local function CycleChannel(step)
	local channels = store:Sorted(config.kindOrder)
	if #channels == 0 then
		return
	end
	local index = 0
	for i, channel in ipairs(channels) do
		if channel.key == state.selected then
			index = i
		end
	end
	Select(channels[(index - 1 + step) % #channels + 1].key)
end


local german = GetLocale() == "deDE"
BINDING_NAME_STEVIOUI_TOGGLE_CHAT = german and "Chat ein-/ausblenden" or "Toggle chat"
BINDING_NAME_STEVIOUI_CHAT_INPUT = german and "Chat: Nachricht schreiben" or "Chat: write message"
BINDING_NAME_STEVIOUI_CHAT_NEXT = german and "Chat: nächster Kanal" or "Chat: next channel"
BINDING_NAME_STEVIOUI_CHAT_PREVIOUS = german and "Chat: voriger Kanal" or "Chat: previous channel"

function ns.ToggleChat()
	state.manual = not state.manual
	if state.manual and state.autoTimer then
		state.autoTimer:Cancel()
		state.autoTimer = nil
	end
	if not state.manual then
		ui.input:ClearFocus()
	end
	Update()
end

-- Opens the chat and starts typing into the selected channel.
function ns.FocusChatInput()
	if not state.manual then
		ns.ToggleChat()
	end
	ui.input:SetFocus()
end

function ns.NextChatChannel()
	CycleChannel(1)
end

function ns.PreviousChatChannel()
	CycleChannel(-1)
end

local function CreateBadge()
	local button = CreateFrame("Button", "StevioUI_ChatBadge", UIParent)
	local segments, gap = config.badge.segments, config.badge.segmentGap
	button:SetSize(badgeStyle.width, badgeStyle.height)
	ns.SetPoint(button, ns.layout.chatBadge)

	local segmentHeight = (badgeStyle.height - gap * (#segments - 1)) / #segments
	button.segments = {}
	for index, segment in ipairs(segments) do
		local frame = CreateFrame("Frame", nil, button)
		frame:SetSize(badgeStyle.width, segmentHeight)
		frame:SetPoint("TOP", 0, -(index - 1) * (segmentHeight + gap))
		ns.CreateBorder(frame)
		local texture = frame:CreateTexture(nil, "ARTWORK")
		texture:SetAllPoints()
		button.segments[segment.category] = texture
	end
	button:SetScript("OnClick", ns.ToggleChat)
	return button
end

local function HideChatButtons()
	ns.KeepHidden(ChatFrameMenuButton)
	ns.KeepHidden(ChatFrameChannelButton)
	ns.KeepHidden(ChatFrameToggleVoiceDeafenButton)
	ns.KeepHidden(ChatFrameToggleVoiceMuteButton)
	ns.KeepHidden(QuickJoinToastButton)
end

-- Edit Mode stores chat size split into hundreds and the remainder.
local function SizeSettings()
	local Setting = Enum.EditModeChatFrameSetting
	local width = ChatWidth()
	return {
		[Setting.WidthHundreds] = math.floor(width / 100),
		[Setting.WidthTensAndOnes] = width % 100,
		[Setting.HeightHundreds] = math.floor(config.height / 100),
		[Setting.HeightTensAndOnes] = config.height % 100,
	}
end

local function CreateChannelView()
	local frame = CreateFrame("Frame", "StevioUI_Chat", UIParent)
	frame:SetSize(ChatWidth(), config.height)
	ns.SetPoint(frame, ns.layout.chat)
	frame:SetFrameStrata("MEDIUM")
	frame:EnableMouse(true)
	frame:Hide()
	local background = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
	background:SetAllPoints()
	background:SetColorTexture(unpack(config.backgroundColor))
	ns.CreateBorder(frame)
	ui.frame = frame
	ui.rows = {}

	ui.sidebar = CreateFrame("Frame", nil, frame)
	ui.sidebar:SetWidth(config.sidebarWidth)
	ui.sidebar:SetPoint("TOPLEFT", 0, -4)
	ui.sidebar:SetPoint("BOTTOMLEFT")
	local divider = frame:CreateTexture(nil, "ARTWORK")
	divider:SetColorTexture(unpack(config.dividerColor))
	divider:SetWidth(ns.PixelSize(frame))
	divider:SetPoint("TOPLEFT", ui.sidebar, "TOPRIGHT")
	divider:SetPoint("BOTTOMLEFT", ui.sidebar, "BOTTOMRIGHT")

	ui.header = ns.CreateFontString(frame, nil, "LEFT")
	ui.header:SetPoint("TOPLEFT", ui.sidebar, "TOPRIGHT", 6, 0)
	ui.header:SetPoint("TOPRIGHT", -6, 0)

	local input = CreateFrame("EditBox", nil, frame)
	input:SetFont(style.font, style.fontSize, style.fontFlags)
	input:SetAutoFocus(false)
	input:SetHeight(config.rowHeight)
	input:SetPoint("BOTTOMLEFT", ui.sidebar, "BOTTOMRIGHT", 6, 2)
	input:SetPoint("BOTTOMRIGHT", -6, 2)
	input:SetMaxLetters(255)
	input:SetScript("OnEnterPressed", function(self)
		Send(self:GetText())
		self:SetText("")
		self:ClearFocus()
	end)
	input:SetScript("OnEscapePressed", input.ClearFocus)
	input:SetScript("OnTabPressed", function()
		CycleChannel(IsShiftKeyDown() and -1 or 1)
	end)
	input:SetScript("OnEditFocusGained", function()
		state.typing = true
		Update()
	end)
	input:SetScript("OnEditFocusLost", function()
		state.typing = false
		Update()
	end)
	ui.input = input

	local messages = CreateFrame("ScrollingMessageFrame", nil, frame)
	messages:SetFont(style.font, style.fontSize, style.fontFlags)
	messages:SetJustifyH("LEFT")
	messages:SetFading(false)
	messages:SetMaxLines(config.historyLimit)
	messages:SetPoint("TOPLEFT", ui.header, "BOTTOMLEFT", 0, -4)
	messages:SetPoint("BOTTOMRIGHT", input, "TOPRIGHT", 0, 4)
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
	messages:SetScript("OnHyperlinkClick", function(self, link, text, button)
		SetItemRef(link, text, button, self)
	end)
	ui.messages = messages
end

function Chat:OnEnable()
	StevioUIChatHistory = StevioUIChatHistory or {}
	store = ns.ChatHistory.New(StevioUIChatHistory, config.historyLimit)
	CreateChannelView()
	badge = CreateBadge()

	ns:SetEditModeSystem(Enum.EditModeSystem.ChatFrame, nil, ns.layout.chat, SizeSettings())

	HideChatButtons()
	ScanChatFrames()
	GuardAlpha(GeneralDockManager)
	hooksecurefunc("FCF_OpenTemporaryWindow", function()
		ScanChatFrames()
		ApplyVisibility()
	end)

	hooksecurefunc(ChatFrameUtil, "ActivateChat", function()
		state.typing = true
		Update()
	end)
	hooksecurefunc(ChatFrameUtil, "DeactivateChat", function()
		state.typing = false
		Update()
	end)

	for event in pairs(config.events) do
		ns:RegisterEvent(event, OnChatMessage)
	end

	Update()
end
