local _, ns = ...

local config = ns.config.chat
local C = ns.ChatInternal
local state = C.state
local History = ns.ChatHistory

-- Incoming messages: which channel each one belongs to, storing it there and
-- showing it as a preview or opening the chat for it (the visibility state is in Chat.lua).

-- Upvalues, as these run for every chat message.
local issecretvalue, Ambiguate, time = issecretvalue, Ambiguate, time

-- The game API History.Route looks things up with.
local lookups = {
	isSecret = issecretvalue,
	accountInfo = function(bnetID)
		return C_BattleNet.GetAccountInfoByID(bnetID)
	end,
	channelLabel = function(baseName)
		local resolve = ChatFrameUtil and ChatFrameUtil.ResolveChannelName
		return resolve and resolve(baseName) or baseName
	end,
	ambiguate = Ambiguate,
}

local function Append(channel, entry)
	if state.selected == channel.key then
		C.ShowEntry(channel, History.PreviousTimed(channel.messages, #channel.messages), entry)
	end
end

-- What a message of `def` arriving in channel `key` does. `mainKey` is Main's
-- key when the channel is merged into it (else false), `selected` the open
-- channel, `attended` and `hidden` the chat's state and `hasFocus()` whether
-- the input line is being typed into. Returns whether the message counts as
-- unread, the channel it shows in (Main for merged channels) and what it does
-- besides: "open" that channel in the chat, "preview" it while the chat is
-- hidden, or nothing.
function C.Delivery(def, key, mainKey, selected, attended, hidden, hasFocus)
	local viewing = attended and (selected == key or (mainKey and selected == mainKey))
	local markUnread = not viewing and not def.outgoing
	-- Lines of merged channels show in Main.
	local show = mainKey or key
	if def.outgoing then
		return markUnread, show
	end
	-- `focus` channels (answers to /sui) open, also in the open chat, unless
	-- the player is typing into another channel.
	if def.focus then
		if hidden or selected == show or not hasFocus() then
			return markUnread, show, "open"
		end
		return markUnread, show
	end
	-- Lines of Main and the other channels that aren't quiet (busy public
	-- chat, NPCs, loot, ...) show as a preview instead of popping up the
	-- hidden chat (#69).
	if hidden and (mainKey or not def.quiet) then
		return markUnread, show, "preview"
	end
	return markUnread, show
end

local function InputHasFocus()
	return C.ui.input:HasFocus()
end

-- Stores a message (`entry`, nil when its contents are secret) in channel `key`
-- and shows it according to `def` (see config.events).
function C.Receive(def, key, opts, entry)
	local main = C.IsMerged(def) and config.main
	local markUnread, show, action =
		C.Delivery(def, key, main and main.key, state.selected, C.Attended(), C.hidden, InputHasFocus)
	-- The line as it shows in `show`, for the preview.
	local shownChannel, shownEntry
	if not entry then
		C.store:AddUnreadOnly(key, opts, time(), main ~= false)
	else
		local channel = C.store:Add(key, opts, entry, markUnread, main ~= false)
		Append(channel, entry)
		shownChannel, shownEntry = channel, entry
		if main then
			local copy = History.Mirror(entry, key, C.Label(channel), channel.chatType)
			shownChannel, shownEntry = C.store:Add(main.key, main, copy, false), copy
			Append(shownChannel, copy)
		end
	end
	-- Lines whose contents are secret (chat lockdown) only light the badge.
	if action == "preview" and shownEntry and config.preview.enabled then
		C.ShowPreview(shownChannel, shownEntry)
	elseif action == "open" then
		if show ~= state.selected then
			C.Peek(show)
		end
		C.StartAutoTimer(config.autoShowDuration)
	end
	C.Update()
end

-- A finished line (`colorType` names the chat type whose color it takes) in
-- the channel of `def`, which is its own channel options too.
function C.ReceiveLine(def, text, colorType)
	C.Receive(def, def.key, def, { time = time(), text = text, colorType = colorType })
end

-- What a chat event makes: the channel def, key and options and the entry
-- (nil when the contents are secret) of a message that arrived at `now`.
-- Returns nothing for messages that aren't shown or whose channel can't be
-- told (secret values).
local function Read(event, now, text, sender, ...)
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
	elseif not secret then
		text = C.ExpandExpressions(text, chatType, select(15, ...))
	end

	-- Character names are clickable (see C.FormatEntry); Battle.net names, our
	-- own and Discord users' in guild chat (no character to whisper; Blizzard
	-- links those as Discord users) aren't.
	local full = not issecretvalue(sender) and sender and History.FullName(sender, GetNormalizedRealmName())
	local player = not secret
		and not C.IsFromDiscord(select(16, ...))
		and not def.format
		and not def.textEmote
		and not def.bnet
		and not def.outgoing
		and sender
		and sender ~= ""
		and full
	local key, opts, source, sourceType, displayName =
		History.Route(def, sender, bnetID, channelIndex, baseName, channelName, full, config.cityChannels, lookups)
	-- Lines show whisper partners with the realm when it isn't the own one, everyone else by name only.
	if not def.format and not def.textEmote and not def.bnet and not issecretvalue(sender) then
		sender = Ambiguate(sender, def.kind == "whisper" and "none" or "short")
	end
	sender = displayName or sender
	if not key then
		return
	end
	local entry = not secret
		and History.BuildEntry(
			def,
			chatType,
			text,
			sender,
			player,
			source,
			sourceType,
			now,
			def.outgoing and UnitName("player")
		)
	return def, key, opts, entry or nil
end

-- Chat lines that arrived secret during the chat lockdown (encounters,
-- Mythic+, PvP, ...): the client hands addons only their chat line id then,
-- and the line can be read by it once the lockdown is over (#38). Each is
-- { event, time, lineID, args, n, key, mainKey }, `key`/`mainKey` where its
-- placeholder went (nil when its channel couldn't be told, e.g. a whisper).
local pending = {}

local function PendingText()
	return ns.T("… (readable after the fight)", "… (nach dem Kampf lesbar)")
end

local function UnreadableText()
	return ns.T("(could not be read)", "(nicht lesbar)")
end

-- Whether a secret line of `def` with chat line id `lineID` can be read
-- later. Battle.net whispers can't: their account id stays secret, so they
-- can't be told apart. Neither can outgoing whispers, whose line names us
-- rather than who they went to.
local function CanReadLater(def, lineID)
	return not def.bnet
		and not def.outgoing
		and C_ChatInfo.GetChatLineText
		and C_ChatInfo.InChatMessagingLockdown
		and not issecretvalue(lineID)
		and type(lineID) == "number"
		and lineID > 0
end

-- Keeps what the event said for the line `lineID` (secret values are left out:
-- they are read again by line id).
local function Remember(event, now, lineID, ...)
	local n = select("#", ...)
	local args = {}
	for i = 1, n do
		local value = select(i, ...)
		if not issecretvalue(value) then
			args[i] = value
		end
	end
	local line = { event = event, time = now, lineID = lineID, args = args, n = n }
	pending[#pending + 1] = line
	return line
end

-- A whisper from a player the notes marked (#45): a warning with the reason
-- under it, in the whisper's channel.
local function WarnAfterWhisper(event, sender, def, key, opts, now)
	local warning = event == "CHAT_MSG_WHISPER" and ns.BlockedWhisperWarning and ns.BlockedWhisperWarning(sender)
	if warning then
		C.Receive(def, key, opts, { time = now, text = warning, colorType = "SYSTEM" })
	end
end

-- Message contents may be secret during the chat lockdown: those are stored as
-- a placeholder and read once it ends (C.ReadPending); without a chat line id
-- they only light up the channel as unread.
-- Whether a guild line comes from Discord: the event's discordInfo (its 18th
-- argument) names a Discord user, as Blizzard's chat checks.
function C.IsFromDiscord(discordInfo)
	if type(discordInfo) ~= "table" then
		return false
	end
	local userID = discordInfo.userID
	return not issecretvalue(userID) and userID ~= nil and userID ~= 0
end

function C.OnChatMessage(event, text, sender, ...)
	-- Like Blizzard's chat: a line whose sender is hidden in the cinematic
	-- letterbox (16th argument) only shows there, not in the chat.
	local hideSenderInLetterbox = select(14, ...)
	if not issecretvalue(hideSenderInLetterbox) and hideSenderInLetterbox then
		return
	end
	if event == "CHAT_MSG_WHISPER_INFORM" or event == "CHAT_MSG_BN_WHISPER_INFORM" then
		C.WhisperEchoed()
	end
	local now = time()
	local lineID = select(9, ...)
	local line = (issecretvalue(text) or issecretvalue(sender))
		and CanReadLater(config.events[event], lineID)
		and Remember(event, now, lineID, ...)
	local def, key, opts, entry = Read(event, now, text, sender, ...)
	if not def then
		return
	end
	if line and not entry then
		entry = History.Placeholder(now, lineID, PendingText())
		line.key = key
		line.mainKey = C.IsMerged(def) and config.main.key
	end
	C.Receive(def, key, opts, entry)
	if entry then
		WarnAfterWhisper(event, sender, def, key, opts, now)
	end
end

-- Puts `entry` (nil: the line isn't shown after all) in place of the
-- placeholder of `line`, in its channel and in Main.
local function Fill(line, entry)
	local channel = C.store:Get(line.key)
	if not channel then
		return
	end
	C.store:Fill(line.key, line.lineID, entry)
	if line.mainKey then
		local copy = entry and History.Mirror(entry, line.key, C.Label(channel), channel.chatType)
		C.store:Fill(line.mainKey, line.lineID, copy)
	end
end

-- Reads the lines kept during the chat lockdown once it is over: placeholders
-- get their message, lines whose channel wasn't known then (whispers) arrive
-- now, with the time they were sent.
function C.ReadPending()
	if #pending == 0 or C_ChatInfo.InChatMessagingLockdown() then
		return
	end
	local lines = pending
	pending = {}
	for _, line in ipairs(lines) do
		local text = C_ChatInfo.GetChatLineText(line.lineID)
		local sender = C_ChatInfo.GetChatLineSenderName(line.lineID)
		local readable = not issecretvalue(text) and not issecretvalue(sender) and text ~= nil and sender ~= nil
		local def, key, opts, entry
		if readable then
			-- One line failing to read mustn't lose the others.
			local ok
			ok, def, key, opts, entry = pcall(Read, line.event, line.time, text, sender, unpack(line.args, 1, line.n))
			if not ok then
				readable, def, key, opts, entry = false, nil, nil, nil, nil
			end
		end
		if line.key then
			if not readable then
				entry = { text = UnreadableText() }
			end
			Fill(line, entry)
		elseif entry then
			C.Receive(def, key, opts, entry)
			WarnAfterWhisper(line.event, sender, def, key, opts, line.time)
		end
	end
	C.RenderMessages(C.Selected())
	C.Update()
end

-- The chat lockdown comes with the addon restrictions (combat, encounter,
-- Mythic+, PvP); clients without it have nothing to read later.
function C.SetupLockdown()
	C.store:ForgetPending(UnreadableText())
	if not (C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.GetChatLineText) then
		return
	end
	-- A frame later: the lockdown may only be lifted once the event is through.
	local function ReadSoon()
		if #pending > 0 then
			C_Timer.After(0, C.ReadPending)
		end
	end
	if C_RestrictedActions then
		ns.RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED", ReadSoon)
	end
	ns.RegisterEvent("PLAYER_REGEN_ENABLED", ReadSoon)
end

-- Addon output (print()) normally lands in Blizzard's chat, which is never
-- shown; it goes to the System channel instead. Our own (/sui replies, see
-- ns.Print) opens it, since it answers something just typed; other addons'
-- output only counts as unread.
function C.OnPrint(...)
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
	C.ReceiveLine(def, table.concat(parts, " "), "SYSTEM")
end
