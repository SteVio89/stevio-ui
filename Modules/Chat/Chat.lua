local _, ns = ...

local config = ns.config.chat
local badgeStyle = ns.config.style.badge

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
}
local unread = {} -- category -> true
local badge

local function ApplyAlpha(frame)
	applyingAlpha = true
	frame:SetAlpha(hidden and 0 or 1)
	applyingAlpha = false
end

-- Blizzard fades tabs and flashes them on new messages via SetAlpha, which
-- would make them pop up on an otherwise hidden chat.
local function GuardAlpha(frame)
	hooksecurefunc(frame, "SetAlpha", function(self)
		if hidden and not applyingAlpha then
			ApplyAlpha(self)
		end
	end)
end

local function ManageChatFrame(frame)
	if chatFrames[frame] then
		return
	end
	chatFrames[frame] = true

	local background = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
	background:SetColorTexture(unpack(config.backgroundColor))
	background:SetPoint("TOPLEFT", -4, 4)
	background:SetPoint("BOTTOMRIGHT", 4, -4)

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
		frame:EnableMouse(not hidden)
		frame:EnableMouseWheel(not hidden)
	end
	for tab in pairs(tabs) do
		ApplyAlpha(tab)
		tab:EnableMouse(not hidden)
	end
	for editBox in pairs(editBoxes) do
		ApplyAlpha(editBox)
		editBox:EnableMouse(not hidden)
	end
	ApplyAlpha(GeneralDockManager)
end

local function SegmentColor(segment)
	local info = ChatTypeInfo[segment.chatType]
	if info and info.r then
		return info.r, info.g, info.b, 1
	end
	return unpack(segment.fallbackColor)
end

local function UpdateBadge()
	for _, segment in ipairs(config.badge.segments) do
		local texture = badge.segments[segment.category]
		if not hidden then
			texture:SetColorTexture(unpack(badgeStyle.shownColor))
		elseif unread[segment.category] then
			texture:SetColorTexture(SegmentColor(segment))
		else
			texture:SetColorTexture(unpack(badgeStyle.hiddenColor))
		end
	end
end

local function Update()
	hidden = not (state.manual or state.typing or state.autoTimer)
	if state.manual then
		wipe(unread)
	end
	ApplyVisibility()
	UpdateBadge()
end

local function IsMouseOverChat()
	for frame in pairs(chatFrames) do
		if frame:IsVisible() and frame:IsMouseOver() then
			return true
		end
	end
	return false
end

local function StartAutoTimer(duration)
	if state.autoTimer then
		state.autoTimer:Cancel()
	end
	state.autoTimer = C_Timer.NewTimer(duration, function()
		-- Hiding the chat under the cursor would yank away what's being read.
		if IsMouseOverChat() then
			StartAutoTimer(1)
			return
		end
		state.autoTimer = nil
		Update()
	end)
end

-- Message contents may be secret and are never read; only the event type matters.
local function OnChatMessage(event)
	if state.manual then
		return
	end
	-- Only messages that arrive unseen count as unread; while typing they're in view.
	if hidden then
		unread[config.autoShowEvents[event]] = true
	end
	StartAutoTimer(config.autoShowDuration)
	Update()
end

BINDING_NAME_STEVIOUI_TOGGLE_CHAT = GetLocale() == "deDE" and "Chat ein-/ausblenden" or "Toggle chat"

function ns.ToggleChat()
	state.manual = not state.manual
	if state.manual and state.autoTimer then
		state.autoTimer:Cancel()
		state.autoTimer = nil
	end
	Update()
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
	local width = Clamp(math.floor(UIParent:GetWidth() * config.widthFraction), 250, 800)
	return {
		[Setting.WidthHundreds] = math.floor(width / 100),
		[Setting.WidthTensAndOnes] = width % 100,
		[Setting.HeightHundreds] = math.floor(config.height / 100),
		[Setting.HeightTensAndOnes] = config.height % 100,
	}
end

function Chat:OnEnable()
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

	for event in pairs(config.autoShowEvents) do
		ns:RegisterEvent(event, OnChatMessage)
	end

	badge = CreateBadge()
	Update()
end
