local _, ns = ...

local config = ns.config.chat
local C = ns.ChatInternal
local state = C.state

local Chat = ns.RegisterModule("chat", {})

-- Chat organised in channels like Slack/Teams. This file holds the visibility
-- state, channel switching and the setup; incoming messages are handled in
-- Receive.lua and outgoing ones in Send.lua. The frames live in View.lua,
-- Copy.lua, Preview.lua and Badge.lua, the handling of Blizzard's own chat in Blizzard.lua,
-- the wording of finished lines in Format.lua, lines without a chat event in
-- Notices.lua, typed slash commands in Commands.lua and the channel store in
-- History.lua.

-- Picking a channel in the open chat is opening it by hand.
function C.Select(key)
	-- A channel picked by hand stays, also when picked during a peek.
	state.peekReturn = nil
	if not C.hidden then
		C.Pin()
	end
	local channel = C.ShowChannel(key)
	if channel and C.Attended() then
		C.MarkRead(key)
	end
	C.RefreshSidebar()
end

-- Where the chat opens when no channel is picked: Main (#65), without it the
-- latest activity, so messages in quiet channels (say, General, ...) aren't
-- hidden behind an empty Guild channel.
local function DefaultKey()
	if config.main.enabled then
		return config.main.key
	end
	local recent = C.store:MostRecent()
	if recent then
		return recent.key
	end
	local first = C.store:Sorted(config.kindOrder)[1]
	return first and first.key
end

local function IsEmpty(channel)
	return #channel.messages == 0 and channel.unread == 0
end

function C.DeleteChannel(key)
	if not C.store:Delete(key) then
		return
	end
	if state.selected == key then
		state.selected = nil
		C.Select(DefaultKey())
	else
		C.RefreshSidebar()
	end
	C.UpdateBadge()
end

-- Shows channel `key` in the chat that pops up for an answer to /sui (see Receive.lua)
-- until it hides again: the channel open before comes back then, so the
-- messages at login don't leave the chat on System (#65).
function C.Peek(key)
	if not C.Attended() and state.peekReturn == nil then
		state.peekReturn = state.selected or false
	end
	C.ShowChannel(key)
end

function C.Update()
	local wasHidden = C.hidden
	C.hidden = not (state.manual or state.typing or state.autoTimer)
	if C.hidden and state.peekReturn ~= nil then
		local key = state.peekReturn
		state.peekReturn = nil
		if key and key ~= state.selected then
			C.ShowChannel(key)
		end
	end
	local channel = C.Selected()
	-- An empty channel picked by hand stays open; one left over from before
	-- the chat was hidden gives way to where something happened.
	if not channel or (wasHidden and not C.hidden and IsEmpty(channel)) then
		local key = DefaultKey()
		if key ~= state.selected or not channel then
			state.selected = key
			C.RenderMessages(C.Selected())
		end
	end
	if C.Attended() and state.selected then
		C.MarkRead(state.selected)
	end
	C.ApplyBlizzardVisibility()
	C.ui.frame:SetShown(not C.hidden)
	-- The open chat shows the lines the preview did.
	if not C.hidden then
		C.ClearPreview()
	end
	C.RefreshSidebar()
	C.UpdateBadge()
end

local function IsMouseOverChat()
	return C.ui.frame:IsVisible() and C.ui.frame:IsMouseOver()
end

-- Shows the chat for `duration` seconds (see Receive.lua).
local function StartAutoTimer(duration)
	if state.autoTimer then
		state.autoTimer:Cancel()
	end
	state.autoTimer = C_Timer.NewTimer(duration, function()
		-- Hiding the chat under the cursor would yank away what's being read.
		if IsMouseOverChat() or C.ui.input:HasFocus() or C.ui.copy:IsShown() then
			StartAutoTimer(1)
			return
		end
		state.autoTimer = nil
		C.Update()
	end)
end
C.StartAutoTimer = StartAutoTimer

-- Keeps the chat open until it is toggled closed: anything the player does
-- with it (toggle key, typing, picking a channel, a click on a name) opens it
-- by hand. Only a chat that popped up by itself hides by itself (#37).
function C.Pin()
	state.manual = true
	-- Opened during a peek, the chat stays on the peeked channel.
	state.peekReturn = nil
	if state.autoTimer then
		state.autoTimer:Cancel()
		state.autoTimer = nil
	end
end

-- Opens the whisper channel with `fullName` ("Name-Realm"), creating it when
-- there is none yet, and starts typing into it: what a click on a player's
-- name in the chat does.
function C.OpenWhisper(fullName)
	local key = ns.ChatHistory.WhisperKey(fullName)
	C.store:Ensure(key, {
		kind = "whisper",
		chatType = "WHISPER",
		label = Ambiguate(fullName, "none"),
		target = fullName,
	})
	-- Opened first: opening a hidden chat moves on from an empty channel.
	ns.FocusChatInput()
	C.Select(key)
end

-- A right click on a player's name in the chat: a menu of what to do with
-- that character, built from the name in the link alone. Blizzard's player
-- menu works the player out from the chat line's location (line ID, GUID),
-- which our lines (replayed from the history) don't carry, and didn't resolve
-- the right name for whispers and invites (#35).
function C.ShowPlayerMenu(owner, fullName)
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(Ambiguate(fullName, "none"))
		root:CreateButton(ns.T("Whisper", "Flüstern"), function()
			C.OpenWhisper(fullName)
		end)
		root:CreateButton(ns.T("Invite", "Einladen"), function()
			C_PartyInfo.InviteUnit(ns.ChatHistory.SendName(fullName))
		end)
		if ns.Players and ns.Players.active then
			root:CreateButton(ns.T("Player info", "Spielerinfo"), function()
				ns.OpenPlayerNote(fullName)
			end)
		end
	end)
end

-- A click on a line's channel tag in Main: writes to that channel from Main.
function C.PickMainTarget(key)
	local channel = C.store:Get(key)
	if not channel or channel.readOnly then
		return
	end
	state.mainTarget = key
	ns.FocusChatInput()
	C.RefreshSidebar()
end

function C.CycleChannel(step)
	if not C.store then
		return
	end
	local channels = C.store:Sorted(config.kindOrder)
	local keys = {}
	for i, channel in ipairs(channels) do
		keys[i] = channel.key
	end
	local index = ns.ChatHistory.NextIndex(keys, state.selected, step)
	if index then
		C.Select(keys[index])
	end
end

-- Hides the chat whenever it is shown, also when it only popped up for a
-- message (#50: that press used to pin it open instead); opens it otherwise.
-- The key bindings call these even when the chat is off or failed to enable,
-- so they do nothing until its view exists, like the other toggles.
function ns.ToggleChat()
	if not C.ui.input then
		return
	end
	if C.hidden then
		C.Pin()
	else
		state.manual = false
		if state.autoTimer then
			state.autoTimer:Cancel()
			state.autoTimer = nil
		end
		C.ui.input:ClearFocus()
	end
	C.Update()
end

-- Opens the chat and starts typing into the selected channel.
function ns.FocusChatInput()
	if not C.ui.input then
		return
	end
	if not state.manual then
		C.Pin()
		C.Update()
	end
	C.ui.input:SetFocus()
end

function ns.NextChatChannel()
	C.CycleChannel(1)
end

function ns.PreviousChatChannel()
	C.CycleChannel(-1)
end

-- /sui chat: what the channel store holds, to check messages arrive at all.
local function PrintChannels()
	local channels = C.store:Sorted(config.kindOrder)
	ns.Print(ns.T("%d chat channels", "%d Chatkanäle"):format(#channels))
	for _, channel in ipairs(channels) do
		ns.PrintLine(
			ns.T("  %s%s|r [%s] %d messages, %d unread%s", "  %s%s|r [%s] %d Nachrichten, %d ungelesen%s"):format(
				C.ColorCode(C.ChannelColor(channel)),
				C.Label(channel),
				channel.key,
				#channel.messages,
				C.Unread(channel),
				channel.key == state.selected and ns.T(" (selected)", " (ausgewählt)") or ""
			)
		)
	end
end

function Chat:OnEnable()
	StevioUIChatHistory = StevioUIChatHistory or {}
	C.store = ns.ChatHistory.New(StevioUIChatHistory, config.historyLimit, config.main.enabled)
	-- Say and Yell before they became Nearby (#50).
	C.store:MergeInto({ "say", "yell" }, "nearby", { kind = "nearby", chatType = "SAY" })
	-- Battle.net account ids from an earlier session may belong to someone else
	-- now; channels without a BattleTag can't look theirs up again, so they lose it.
	for _, channel in pairs(StevioUIChatHistory.channels) do
		if channel.bnetID and not channel.battleTag then
			channel.bnetID = nil
		end
	end
	-- Turned off, Main keeps its history until deleted with `x`.
	if config.main.enabled then
		C.store:Ensure(config.main.key, config.main)
	end
	C.CreateChannelView()
	C.CreatePreview()
	C.CreateBadge()

	-- Registered first, so messages are stored even if a Blizzard hook below fails.
	for event in pairs(config.events) do
		ns.RegisterEvent(event, C.OnChatMessage)
	end
	-- Whispers the client refuses to send are named in their channel (see Send.lua).
	ns.RegisterEvent("ADDON_ACTION_BLOCKED", C.OnActionBlocked)
	ns.RegisterEvent("ADDON_ACTION_FORBIDDEN", C.OnActionBlocked)
	ns.RegisterSlashCommand("chat", PrintChannels)
	hooksecurefunc("print", C.OnPrint)

	C.SetupBlizzardChat()
	C.SetupNotices()
	C.SetupLockdown()

	C.Update()
end
