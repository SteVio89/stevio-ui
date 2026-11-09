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

-- Stores a message (`entry`, nil when its contents are secret) in channel `key`
-- and shows it according to `def` (see config.events).
function C.Receive(def, key, opts, entry)
	local main = C.IsMerged(opts.kind) and config.main
	local viewing = C.Attended() and (state.selected == key or (main and state.selected == main.key))
	if not entry then
		C.store:AddUnreadOnly(key, opts, time())
	else
		local channel = C.store:Add(key, opts, entry, not viewing and not def.outgoing)
		Append(channel, entry)
		if main then
			local copy = History.Mirror(entry, key, C.Label(channel), channel.chatType)
			Append(C.store:Add(main.key, main, copy, false), copy)
		end
	end
	-- Lines of merged channels pop up in Main (see below).
	local show = main and main.key or key

	-- Busy public chat only counts as unread; it doesn't pop up the hidden chat.
	if def.outgoing or def.quiet then
		C.Update()
		return
	end
	-- Peek at the channel the message arrived in while the chat is hidden;
	-- `focus` channels are opened even when the chat is open, unless the
	-- player is typing into another channel.
	if C.hidden or (def.focus and state.selected ~= show and not C.ui.input:HasFocus()) then
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

-- Message contents may be secret (e.g. in encounters): those can't be stored and
-- only light up the channel as unread.
function C.OnChatMessage(event, text, sender, ...)
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
		return -- no way to tell which channel this belongs to
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
			time(),
			def.outgoing and UnitName("player")
		)
	C.Receive(def, key, opts, entry)
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
