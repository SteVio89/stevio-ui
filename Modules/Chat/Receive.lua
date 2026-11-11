local _, ns = ...

local config = ns.config.chat
local C = ns.ChatInternal
local state = C.state
local History = ns.ChatHistory

-- Incoming messages: which channel each one belongs to, storing it there and
-- popping up the hidden chat for it (the visibility state is in Chat.lua).

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
-- unread, the channel it shows in (Main for merged channels), whether that
-- channel is opened and whether the chat pops up for it.
function C.Delivery(def, key, mainKey, selected, attended, hidden, hasFocus)
	local viewing = attended and (selected == key or (mainKey and selected == mainKey))
	local markUnread = not viewing and not def.outgoing
	-- Lines of merged channels pop up in Main.
	local show = mainKey or key
	-- Busy public chat only counts as unread; it doesn't pop up the hidden chat.
	if def.outgoing or def.quiet then
		return markUnread, show, false, false
	end
	-- Peek at the channel the message arrived in while the chat is hidden;
	-- `focus` channels are opened even when the chat is open, unless the
	-- player is typing into another channel.
	local open = hidden or (def.focus and selected ~= show and not hasFocus())
	return markUnread, show, open, true
end

local function InputHasFocus()
	return C.ui.input:HasFocus()
end

-- Stores a message (`entry`, nil when its contents are secret) in channel `key`
-- and shows it according to `def` (see config.events).
function C.Receive(def, key, opts, entry)
	local main = C.IsMerged(opts.kind) and config.main
	local markUnread, show, open, popUp =
		C.Delivery(def, key, main and main.key, state.selected, C.Attended(), C.hidden, InputHasFocus)
	if not entry then
		C.store:AddUnreadOnly(key, opts, time())
	else
		local channel = C.store:Add(key, opts, entry, markUnread)
		Append(channel, entry)
		if main then
			local copy = History.Mirror(entry, key, C.Label(channel), channel.chatType)
			Append(C.store:Add(main.key, main, copy, false), copy)
		end
	end
	if not popUp then
		C.Update()
		return
	end
	if open then
		C.ShowChannel(show)
	end
	C.StartAutoTimer(config.autoShowDuration)
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
	end

	-- Character names are clickable (see C.FormatEntry); Battle.net names and our own aren't.
	local full = not issecretvalue(sender) and sender and History.FullName(sender, GetNormalizedRealmName())
	local player = not secret
		and not def.format
		and not def.textEmote
		and not def.bnet
		and not def.outgoing
		and sender
		and sender ~= ""
		and full
	local key, opts, source, sourceType, displayName =
		History.Route(def, sender, bnetID, channelIndex, baseName, full, config.publicChannels, lookups)
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

-- Whether a secret line with chat line id `lineID` can be read later.
local function CanReadLater(lineID)
	return C_ChatInfo.GetChatLineText
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

-- Message contents may be secret during the chat lockdown: those are stored as
-- a placeholder and read once it ends (C.ReadPending); without a chat line id
-- they only light up the channel as unread.
function C.OnChatMessage(event, text, sender, ...)
	local now = time()
	local lineID = select(9, ...)
	local line = (issecretvalue(text) or issecretvalue(sender))
		and CanReadLater(lineID)
		and Remember(event, now, lineID, ...)
	local def, key, opts, entry = Read(event, now, text, sender, ...)
	if not def then
		return
	end
	if line and not entry then
		entry = History.Placeholder(now, lineID, PendingText())
		line.key = key
		line.mainKey = C.IsMerged(opts.kind) and config.main.key
	end
	C.Receive(def, key, opts, entry)
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
		local readable = text ~= nil and sender ~= nil and not issecretvalue(text) and not issecretvalue(sender)
		local def, key, opts, entry
		if readable then
			def, key, opts, entry = Read(line.event, line.time, text, sender, unpack(line.args, 1, line.n))
		end
		if line.key then
			if not readable then
				entry = { text = UnreadableText() }
			end
			Fill(line, entry)
		elseif entry then
			C.Receive(def, key, opts, entry)
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
