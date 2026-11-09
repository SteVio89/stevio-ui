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

-- Whisper partners are keyed by full name (or BattleTag), group chats by type,
-- chat channels by name (see ns.ChatHistory.PublicChannel).
-- Returns key, channel options, and for "Other" the line's source channel and
-- its chat type; for Battle.net whispers the fifth value is the name to show
-- as sender. Returns nil when the channel can't be told (secret values).
local function ChannelFor(def, sender, bnetID, channelIndex, baseName)
	if def.key then
		return def.key,
			{ kind = def.kind, chatType = def.chatType, label = def.label, readOnly = def.readOnly, silent = def.silent }
	end
	if def.channel then
		if issecretvalue(baseName) or issecretvalue(channelIndex) or not baseName then
			return nil
		end
		local clubId, streamId = ns.ChatHistory.CommunityIds(baseName)
		if clubId then
			local resolve = ChatFrameUtil and ChatFrameUtil.ResolveChannelName
			local label = resolve and resolve(baseName) or baseName
			return ns.ChatHistory.CommunityKey(clubId, streamId),
				{
					kind = "community",
					chatType = "CHANNEL" .. channelIndex,
					label = label,
					relabel = true,
					clubId = clubId,
					streamId = streamId,
				}
		end
		local key, label, own = ns.ChatHistory.PublicChannel(baseName, config.publicChannels)
		if own then
			return key,
				{ kind = def.kind, chatType = "CHANNEL" .. channelIndex, label = label, channelIndex = channelIndex }
		end
		local opts = { kind = "other", chatType = def.chatType, label = label, readOnly = true }
		return key, opts, baseName, "CHANNEL" .. channelIndex
	end
	if issecretvalue(sender) or issecretvalue(bnetID) then
		return nil
	end
	if def.bnet then
		local info = C_BattleNet.GetAccountInfoByID(bnetID)
		local battleTag = info and info.battleTag
		if battleTag and battleTag ~= "" then
			local name = ns.ChatHistory.BattleTagName(battleTag)
			local opts =
				{ kind = def.kind, chatType = def.chatType, label = name, bnetID = bnetID, battleTag = battleTag }
			return ns.ChatHistory.BattleNetKey(battleTag), opts, nil, nil, name
		end
		-- No account info: keyed by the session id, as before.
		return "bn:" .. bnetID, { kind = def.kind, chatType = def.chatType, label = sender, bnetID = bnetID }
	end
	-- The full name answers the right player even across realms; the label shows
	-- the realm only for other realms, like Blizzard's chat.
	local full = ns.ChatHistory.FullName(sender, GetNormalizedRealmName())
	local label = Ambiguate(full, "none")
	return ns.ChatHistory.WhisperKey(full), { kind = def.kind, chatType = def.chatType, label = label, target = full }
end

-- Stores a message (`entry`, nil when its contents are secret) in channel `key`
-- and shows it according to `def` (see config.events).
function C.Receive(def, key, opts, entry)
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
	local _, channelName, otherPlayer, _, _, channelIndex, baseName = ...
	local bnetID = select(11, ...)
	local secret = issecretvalue(text) or issecretvalue(sender)
	local chatType = event:sub(10)
	if def.format then
		if not secret then
			text = C.FormatLine(def, chatType, text, sender, channelName, otherPlayer, channelIndex)
			if not text then
				return -- a notice that isn't shown as text
			end
		end
		sender = nil -- finished lines name whoever they are about in their text
	elseif def.textEmote then
		sender = nil -- text emotes name the sender in their text
	end

	-- Character names are clickable (see View.lua); Battle.net names and our own aren't.
	local player = not secret
		and not def.format
		and not def.textEmote
		and not def.bnet
		and not def.outgoing
		and sender
		and sender ~= ""
		and ns.ChatHistory.FullName(sender, GetNormalizedRealmName())
	local key, opts, source, sourceType, displayName = ChannelFor(def, sender, bnetID, channelIndex, baseName)
	-- Lines show whisper partners with the realm when it isn't the own one, everyone else by name only.
	if not def.format and not def.textEmote and not def.bnet and not issecretvalue(sender) then
		sender = Ambiguate(sender, def.kind == "whisper" and "none" or "short")
	end
	sender = displayName or sender
	if not key then
		return -- no way to tell which channel this belongs to
	end
	local entry = not secret
		and {
			time = time(),
			sender = def.outgoing and UnitName("player") or sender,
			player = player or nil,
			text = (def.prefix or "") .. text,
			outgoing = def.outgoing,
			emote = def.emote,
			-- Finished lines take the color of their own kind (loot, boss emote, ...).
			colorType = def.format and chatType,
			-- "Other" mixes channels, so each line names its own.
			source = source,
			sourceType = sourceType,
		}
	C.Receive(def, key, opts, entry)
end

-- Addon output (print()) normally lands in Blizzard's chat, which is never
-- shown; it goes to the System channel instead. Our own (/sui replies, see
-- ns.Print) opens it, since it answers something just typed; other addons'
-- output only counts as unread.
local function OnPrint(...)
	local def = ns.printing and config.print or config.notices.system
	local parts = {}
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if issecretvalue(value) then
			C.Receive(def, def.key, def, nil)
			return
		end
		parts[i] = tostring(value)
	end
	C.Receive(def, def.key, def, { time = time(), text = table.concat(parts, " "), colorType = "SYSTEM" })
end

-- The account id may change between sessions, so channels with a BattleTag
-- look it up again in the friend list; a friend no longer in the list gets
-- nothing rather than whoever holds the old id now.
local function CurrentBattleNetID(channel)
	if not channel.battleTag then
		return channel.bnetID
	end
	for index = 1, BNGetNumFriends() do
		local info = C_BattleNet.GetFriendAccountInfo(index)
		if info and info.battleTag == channel.battleTag then
			channel.bnetID = info.bnetAccountID
			return info.bnetAccountID
		end
	end
end

function C.Send(text)
	-- Slash commands run in any channel, read-only ones included (see Commands.lua).
	if text:sub(1, 1) == "/" then
		C.RunCommand(text)
		return
	end
	local channel = C.Selected()
	-- "Other" mixes several channels and "System" has no sender: no one to answer to.
	if not channel or text == "" or channel.readOnly then
		return
	end
	if channel.clubId then
		C_Club.SendMessage(channel.clubId, channel.streamId, text)
	elseif channel.bnetID or channel.battleTag or channel.chatType == "BN_WHISPER" then
		local bnetID = CurrentBattleNetID(channel)
		if bnetID then
			C_BattleNet.SendWhisper(bnetID, text)
		end
	elseif channel.kind == "whisper" then
		C_ChatInfo.SendChatMessage(text, "WHISPER", nil, channel.target)
	elseif channel.channelIndex then
		C_ChatInfo.SendChatMessage(text, "CHANNEL", nil, channel.channelIndex)
	else
		C_ChatInfo.SendChatMessage(text, channel.chatType)
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
	ns.Print(ns.T("%d chat channels", "%d Chatkanäle"):format(#channels))
	for _, channel in ipairs(channels) do
		ns.PrintLine(
			ns.T("  %s%s|r [%s] %d messages, %d unread%s", "  %s%s|r [%s] %d Nachrichten, %d ungelesen%s"):format(
				C.ColorCode(C.ChannelColor(channel)),
				C.Label(channel),
				channel.key,
				#channel.messages,
				channel.unread,
				channel.key == state.selected and ns.T(" (selected)", " (ausgewählt)") or ""
			)
		)
	end
end

function Chat:OnEnable()
	StevioUIChatHistory = StevioUIChatHistory or {}
	C.store = ns.ChatHistory.New(StevioUIChatHistory, config.historyLimit)
	-- Battle.net account ids from an earlier session may belong to someone else
	-- now; channels without a BattleTag can't look theirs up again, so they lose it.
	for _, channel in pairs(StevioUIChatHistory.channels) do
		if channel.bnetID and not channel.battleTag then
			channel.bnetID = nil
		end
	end
	C.CreateChannelView()
	C.CreateBadge()

	-- Registered first, so messages are stored even if a Blizzard hook below fails.
	for event in pairs(config.events) do
		ns:RegisterEvent(event, OnChatMessage)
	end
	ns:RegisterSlashCommand("chat", PrintChannels)
	hooksecurefunc("print", OnPrint)

	C.SetupBlizzardChat()
	C.SetupNotices()

	C.Update()
end
