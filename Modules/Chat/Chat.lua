local _, ns = ...

local config = ns.config.chat
local C = ns.ChatInternal
local state = C.state

local Chat = ns:RegisterModule("chat", {})

-- Chat organised in channels like Slack/Teams. This file holds the state and
-- the message flow; the frames live in View.lua, Copy.lua and Badge.lua, the
-- handling of Blizzard's own chat in Blizzard.lua and the channel store in History.lua.

function C.Select(key)
	state.selected = key
	if C.ui.copy then
		C.ui.copy:Hide()
	end
	local channel = C.Selected()
	if channel and C.Attended() then
		C.store:MarkRead(key)
	end
	C.RenderMessages(channel)
	C.RefreshSidebar()
end

-- Where the chat opens when no channel is picked: the latest activity, so
-- messages in quiet channels (say, General, ...) aren't hidden behind an empty
-- Guild channel.
local function DefaultKey()
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

function C.Update()
	local wasHidden = C.hidden
	C.hidden = not (state.manual or state.typing or state.autoTimer)
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
		C.store:MarkRead(state.selected)
	end
	C.ApplyBlizzardVisibility()
	C.ui.frame:SetShown(not C.hidden)
	C.RefreshSidebar()
	C.UpdateBadge()
end

local function IsMouseOverChat()
	return C.ui.frame:IsVisible() and C.ui.frame:IsMouseOver()
end

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

-- Whisper partners are keyed by name (or Battle.net id), group chats by type,
-- chat channels by name (see ns.ChatHistory.PublicChannel).
-- Returns nil when the channel can't be told (secret values).
local function ChannelFor(def, sender, bnetID, channelIndex, baseName)
	if def.key then
		return def.key, { kind = def.kind, chatType = def.chatType, label = def.label, readOnly = def.readOnly }
	end
	if def.channel then
		if issecretvalue(baseName) or issecretvalue(channelIndex) or not baseName then
			return nil
		end
		local key, label, own = ns.ChatHistory.PublicChannel(baseName, config.publicChannels)
		if own then
			return key, { kind = def.kind, chatType = "CHANNEL" .. channelIndex, label = label, channelIndex = channelIndex }
		end
		local opts = { kind = "other", chatType = def.chatType, label = label, readOnly = true }
		return key, opts, baseName, "CHANNEL" .. channelIndex
	end
	if issecretvalue(sender) or issecretvalue(bnetID) then
		return nil
	end
	if def.bnet then
		return "bn:" .. bnetID, { kind = def.kind, chatType = def.chatType, label = sender, bnetID = bnetID }
	end
	return "whisper:" .. sender, { kind = def.kind, chatType = def.chatType, label = sender, target = sender }
end

-- Battle.net notices arrive as a token (e.g. "FRIEND_ONLINE") plus the friend's
-- name; Blizzard's text for it is a global. Only the tokens listed in `toast`
-- are shown, others (broadcasts, requests) take different arguments.
local function SystemText(def, text, sender)
	if def.toast then
		local template = def.toast[text] and _G["BN_INLINE_TOAST_" .. text]
		return template and template:format(sender)
	end
	return text
end

-- Stores a message (`entry`, nil when its contents are secret) in channel `key`
-- and shows it according to `def` (see config.events).
local function Receive(def, key, opts, entry)
	local viewing = C.Attended() and state.selected == key
	if not entry then
		C.store:AddUnreadOnly(key, opts, time())
	else
		local channel = C.store:Add(key, opts, entry, not viewing and not def.outgoing)
		if state.selected == key then
			C.ShowEntry(channel, C.PreviousTimed(channel.messages, #channel.messages), entry)
		end
	end

	-- Busy public chat only counts as unread; it doesn't pop up the hidden chat.
	if def.outgoing or def.quiet then
		C.Update()
		return
	end
	-- Peek at the channel the message arrived in while the chat is hidden;
	-- `focus` channels are opened even when the chat is open, unless the
	-- player is typing into another channel.
	if C.hidden or (def.focus and state.selected ~= key and not C.ui.input:HasFocus()) then
		state.selected = key
		if C.ui.copy then
			C.ui.copy:Hide()
		end
		C.RenderMessages(C.store:Get(key))
	end
	StartAutoTimer(config.autoShowDuration)
	C.Update()
end

-- Message contents may be secret (e.g. in encounters): those can't be stored and
-- only light up the channel as unread.
local function OnChatMessage(event, text, sender, ...)
	local def = config.events[event]
	local channelIndex, baseName = select(6, ...)
	local bnetID = select(11, ...)
	local secret = issecretvalue(text) or issecretvalue(sender)
	if def.system or def.textEmote then
		if def.system and not secret then
			text = SystemText(def, text, sender)
			if not text then
				return -- a Battle.net notice that isn't shown as text
			end
		end
		sender = nil -- system messages have none, text emotes name it in their text
	elseif not issecretvalue(sender) and not def.bnet then
		sender = Ambiguate(sender, "short")
	end

	local key, opts, source, sourceType = ChannelFor(def, sender, bnetID, channelIndex, baseName)
	if not key then
		return -- no way to tell which channel this belongs to
	end
	local entry = not secret
		and {
			time = time(),
			sender = def.outgoing and UnitName("player") or sender,
			text = (def.prefix or "") .. text,
			outgoing = def.outgoing,
			emote = def.emote,
			-- "Other" mixes channels, so each line names its own.
			source = source,
			sourceType = sourceType,
		}
	Receive(def, key, opts, entry)
end

-- Addon output (print(), e.g. /sui) normally lands in Blizzard's chat, which is
-- never shown; it goes to the System channel instead and opens it, since it
-- usually answers something just typed.
local function OnPrint(...)
	local parts = {}
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if issecretvalue(value) then
			Receive(config.print, config.print.key, config.print, nil)
			return
		end
		parts[i] = tostring(value)
	end
	Receive(config.print, config.print.key, config.print, { time = time(), text = table.concat(parts, " ") })
end

function C.Send(text)
	local channel = C.Selected()
	-- "Other" mixes several channels and "System" has no sender: no one to answer to.
	if not channel or text == "" or channel.readOnly then
		return
	end
	if channel.bnetID then
		BNSendWhisper(channel.bnetID, text)
	elseif channel.kind == "whisper" then
		SendChatMessage(text, "WHISPER", nil, channel.target)
	elseif channel.channelIndex then
		SendChatMessage(text, "CHANNEL", nil, channel.channelIndex)
	else
		SendChatMessage(text, channel.chatType)
	end
end

function C.CycleChannel(step)
	local channels = C.store:Sorted(config.kindOrder)
	if #channels == 0 then
		return
	end
	local index = 0
	for i, channel in ipairs(channels) do
		if channel.key == state.selected then
			index = i
		end
	end
	C.Select(channels[(index - 1 + step) % #channels + 1].key)
end

BINDING_NAME_STEVIOUI_TOGGLE_CHAT = C.german and "Chat ein-/ausblenden" or "Toggle chat"
BINDING_NAME_STEVIOUI_CHAT_INPUT = C.german and "Chat: Nachricht schreiben" or "Chat: write message"
BINDING_NAME_STEVIOUI_CHAT_NEXT = C.german and "Chat: nächster Kanal" or "Chat: next channel"
BINDING_NAME_STEVIOUI_CHAT_PREVIOUS = C.german and "Chat: voriger Kanal" or "Chat: previous channel"

function ns.ToggleChat()
	state.manual = not state.manual
	if state.manual and state.autoTimer then
		state.autoTimer:Cancel()
		state.autoTimer = nil
	end
	if not state.manual then
		C.ui.input:ClearFocus()
	end
	C.Update()
end

-- Opens the chat and starts typing into the selected channel.
function ns.FocusChatInput()
	if not state.manual then
		ns.ToggleChat()
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
	print(("|cff33ff99%s|r: %d chat channels"):format(ns.name, #channels))
	for _, channel in ipairs(channels) do
		print(
			("  %s%s|r [%s] %d messages, %d unread%s"):format(
				C.ColorCode(C.ChannelColor(channel)),
				channel.label,
				channel.key,
				#channel.messages,
				channel.unread,
				channel.key == state.selected and " (selected)" or ""
			)
		)
	end
end

function Chat:OnEnable()
	StevioUIChatHistory = StevioUIChatHistory or {}
	C.store = ns.ChatHistory.New(StevioUIChatHistory, config.historyLimit)
	C.CreateChannelView()
	C.CreateBadge()

	-- Registered first, so messages are stored even if a Blizzard hook below fails.
	for event in pairs(config.events) do
		ns:RegisterEvent(event, OnChatMessage)
	end
	ns:RegisterSlashCommand("chat", PrintChannels)
	hooksecurefunc("print", OnPrint)

	C.SetupBlizzardChat()

	C.Update()
end
