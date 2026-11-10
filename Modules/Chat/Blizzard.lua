local _, ns = ...

local config = ns.config.chat
local C = ns.ChatInternal

-- The chat is hidden through alpha and disabled mouse input instead of Hide():
-- Blizzard's chat code checks IsShown() to pick and focus the input box, and
-- focusing it from addon code is restricted. Invisible-but-shown keeps all of
-- Blizzard's chat behaviour intact.

local chatFrames = {}
local tabs = {}
local editBoxes = {}
local applyingAlpha = false

-- Blizzard's chat windows are never shown: the channel view replaces them.
-- Only their input box is still used (Enter / slash commands) while typing;
-- it sits right under the channel view and is hidden together with it.
-- While the channel view is being built, `showBlizzardChat` keeps them visible
-- next to it for comparison.
local function IsSuppressed(frame)
	if editBoxes[frame] then
		return C.hidden
	end
	return not config.showBlizzardChat
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

-- Blizzard anchors the input box to its own (invisible) chat window and
-- re-anchors it now and then (docking, chat style), so the anchor is restored
-- whenever Blizzard moves it (ns.PinFrame).
local function PlaceEditBox(editBox)
	editBox:ClearAllPoints()
	editBox:SetPoint("TOPLEFT", C.ui.frame, "BOTTOMLEFT", 0, -config.editBoxGap)
	editBox:SetPoint("TOPRIGHT", C.ui.frame, "BOTTOMRIGHT", 0, -config.editBoxGap)
end

-- Blizzard stacks its chat toasts (Battle.net friend online, ...) upwards from
-- ChatAlertFrame, which sits above its own chat window. That window is at the
-- top of the screen, so the toasts ended up in the top left corner; they go
-- right under the input box instead, which stays where it is.
local function PlaceAlerts(alerts)
	alerts:ClearAllPoints()
	alerts:SetPoint("TOPLEFT", DEFAULT_CHAT_FRAME.editBox, "BOTTOMLEFT", 0, -config.alertGap)
	alerts:SetHeight(config.alertHeight)
end

local function ManageAlerts()
	if not ChatAlertFrame or not DEFAULT_CHAT_FRAME.editBox then
		return
	end
	ns.PinFrame(ChatAlertFrame, PlaceAlerts)
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
		ns.PinFrame(editBox, PlaceEditBox)
	end
end

local function ScanChatFrames()
	for _, name in ipairs(CHAT_FRAMES) do
		ManageChatFrame(_G[name])
	end
end

-- Applies the current `C.hidden` to Blizzard's chat windows, tabs and input boxes.
function C.ApplyBlizzardVisibility()
	local blizzard = config.showBlizzardChat
	for frame in pairs(chatFrames) do
		ApplyAlpha(frame)
		frame:EnableMouse(blizzard)
		frame:EnableMouseWheel(blizzard)
	end
	for tab in pairs(tabs) do
		ApplyAlpha(tab)
		tab:EnableMouse(blizzard)
	end
	for editBox in pairs(editBoxes) do
		ApplyAlpha(editBox)
		editBox:EnableMouse(not C.hidden)
	end
	ApplyAlpha(GeneralDockManager)
end

local function HideChatButtons()
	ns.KeepHidden(ChatFrameMenuButton)
	ns.KeepHidden(ChatFrameChannelButton)
	ns.KeepHidden(ChatFrameToggleVoiceDeafenButton)
	ns.KeepHidden(ChatFrameToggleVoiceMuteButton)
	ns.KeepHidden(QuickJoinToastButton)
end

-- Blizzard's chat sits right of the channel view while both are shown.
local function BlizzardChatLayout()
	local layout = ns.layout.chat
	if not config.showBlizzardChat then
		return layout
	end
	local placed = CopyTable(layout)
	placed.x = (layout.x or 0) + C.ChatWidth() + config.blizzardChatGap
	return placed
end

-- Edit Mode stores chat size split into hundreds and the remainder;
-- `Setting` is Enum.EditModeChatFrameSetting.
function C.SizeSettings(Setting, width, height)
	return {
		[Setting.WidthHundreds] = math.floor(width / 100),
		[Setting.WidthTensAndOnes] = width % 100,
		[Setting.HeightHundreds] = math.floor(height / 100),
		[Setting.HeightTensAndOnes] = height % 100,
	}
end

-- Typing in Blizzard's input box opens the chat. The hooks moved into
-- ChatFrameUtil in newer clients; older ones still have the globals.
local function HookChatActivation(name, legacy, typing)
	local function OnActivation()
		C.state.typing = typing
		C.Update()
	end
	if ChatFrameUtil and ChatFrameUtil[name] then
		hooksecurefunc(ChatFrameUtil, name, OnActivation)
	elseif _G[legacy] then
		hooksecurefunc(legacy, OnActivation)
	end
end

-- Needs the channel view (C.ui.frame) to exist, since the input box hangs under it.
function C.SetupBlizzardChat()
	ns.SetEditModeSystem(
		Enum.EditModeSystem.ChatFrame,
		nil,
		BlizzardChatLayout(),
		C.SizeSettings(Enum.EditModeChatFrameSetting, C.ChatWidth(), config.height)
	)

	HideChatButtons()
	ScanChatFrames()
	ManageAlerts()
	GuardAlpha(GeneralDockManager)
	hooksecurefunc("FCF_OpenTemporaryWindow", function()
		ScanChatFrames()
		C.ApplyBlizzardVisibility()
	end)

	HookChatActivation("ActivateChat", "ChatEdit_ActivateChat", true)
	HookChatActivation("DeactivateChat", "ChatEdit_DeactivateChat", false)
end
