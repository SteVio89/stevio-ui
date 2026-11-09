local _, ns = ...

local config = ns.config.chat
local C = ns.ChatInternal
local state = C.state

-- Incoming messages: which channel each one belongs to, storing it there and
-- popping up the hidden chat for it (the visibility state is in Chat.lua).

-- Whisper partners are keyed by full name (or BattleTag), group chats by type,
-- chat channels by name (see ns.ChatHistory.PublicChannel).
-- Returns key, channel options, and for "Other" the line's source channel and
-- its chat type; for Battle.net whispers the fifth value is the name to show
-- as sender. Returns nil when the channel can't be told (secret values).
local function ChannelFor(def, sender, bnetID, channelIndex, baseName)
	if def.key then
		return def.key,
			{
				kind = def.kind,
				chatType = def.chatType,
				label = def.label,
				readOnly = def.readOnly,
				silent = def.silent,
			}
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

local function Append(channel, entry)
	if state.selected == channel.key then
		C.ShowEntry(channel, ns.ChatHistory.PreviousTimed(channel.messages, #channel.messages), entry)
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
			local copy = ns.ChatHistory.Mirror(entry, key, C.Label(channel), channel.chatType)
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
