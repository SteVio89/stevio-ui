local _, ns = ...

-- Channel store behind the chat: pure data, no frames, so it can be unit tested
-- outside the game (see tests/history_test.lua). A channel is
-- { key, kind, chatType, label, messages = {...}, unread, last, bnetID, battleTag,
--   target, channelIndex, clubId, streamId, readOnly, silent }. Silent channels (crafting notices, ...)
-- never count unread and never count as the latest activity.

local History = {}
ns.ChatHistory = History

local Store = {}
Store.__index = Store

-- Strips WoW escape sequences (colors, textures, hyperlinks) so text can be copied.
function History.StripMarkup(text)
	text = text:gsub("|H.-|h(.-)|h", "%1")
	text = text:gsub("|T.-|t", "")
	text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
	text = text:gsub("|r", "")
	text = text:gsub("||", "|")
	return text
end

-- One message line: time first, then the chat channel it came from (only set in
-- the shared "Other" channel), then the sender. System messages have no sender;
-- emotes (`entry.emote`) read as a sentence, "Bob waves.", without the colon
-- (text emotes like /dance carry the name in their text and have no sender).
-- `stamp`, `source` and `sender` are the already formatted (e.g. colored) parts;
-- `source` and `sender` default to the entry's own.
function History.Line(entry, stamp, source, sender)
	local parts = { stamp }
	if entry.source then
		parts[#parts + 1] = "[" .. (source or entry.source) .. "]"
	end
	if entry.sender then
		parts[#parts + 1] = (sender or entry.sender) .. (entry.emote and "" or ":")
	end
	parts[#parts + 1] = entry.text or ""
	return table.concat(parts, " ")
end

-- Whether `entry` starts a new day after `previous` (nil for the first message),
-- so the chat can put a date line before it. `day(time)` names the day (e.g.
-- the formatted date). Messages without a time never start a day.
function History.StartsDay(previous, entry, day)
	if not entry.time then
		return false
	end
	if not previous or not previous.time then
		return true
	end
	return day(previous.time) ~= day(entry.time)
end

-- The last message with a time before index `index` (nil when there is none):
-- what decides whether a message appended at `index` starts a new day.
function History.PreviousTimed(messages, index)
	for i = index - 1, 1, -1 do
		if messages[i].time then
			return messages[i]
		end
	end
end

-- Plain-text transcript of a channel, one "[stamp] [source] sender: text" line per message.
-- `stamp(time)` formats the time (defaults to the raw number); with `day(time)`
-- a "-- day --" line precedes the first message of each day.
function History.Transcript(channel, stamp, day)
	local lines = {}
	local previous
	for _, entry in ipairs(channel.messages) do
		if day and History.StartsDay(previous, entry, day) then
			lines[#lines + 1] = "-- " .. day(entry.time) .. " --"
		end
		if entry.time then
			previous = entry
		end
		local when = entry.time and (stamp and stamp(entry.time) or tostring(entry.time)) or "--:--"
		lines[#lines + 1] = History.StripMarkup(History.Line(entry, "[" .. when .. "]"))
	end
	return table.concat(lines, "\n")
end

-- Where a message in a numbered chat channel (General, Trade, ...) goes: channels
-- listed in `explicit` (base names, case-insensitive) get their own channel, all
-- others share "Other". Returns key, label and whether the channel is explicit.
function History.PublicChannel(baseName, explicit)
	local lower = baseName:lower()
	for _, name in ipairs(explicit) do
		if name:lower() == lower then
			return "channel:" .. lower, baseName, true
		end
	end
	return "other", "Other", false
end

-- Full "Name-Realm" of a player: chat events name players of the own realm
-- without the realm on some clients, so it is added to tell same-named players
-- of different realms apart and to whisper the right one. `realm` may be nil
-- (not known yet), which leaves the name as it is.
function History.FullName(name, realm)
	if name:find("-", 1, true) or not realm or realm == "" then
		return name
	end
	return name .. "-" .. realm
end

function History.WhisperKey(fullName)
	return "whisper:" .. fullName
end

-- A clickable player name in a message line: Blizzard's "player" hyperlink
-- around `text` (the already formatted name), naming `fullName`.
function History.PlayerLink(fullName, text)
	return "|Hplayer:" .. fullName .. "|h" .. text .. "|h"
end

-- The full name a "player" hyperlink (as passed to OnHyperlinkClick) names,
-- or nil for other links. Blizzard's own links carry more fields after the
-- name ("player:Name-Realm:lineID:chatType:target").
function History.LinkedPlayer(link)
	local name = link:match("^player:([^:]+)")
	if name and name ~= "" then
		return name
	end
end

-- A clickable channel tag ("[Party]") in the merged channel: picks that
-- channel as where the input line writes to (see Chat.lua).
function History.ChannelLink(key, text)
	return "|Haddon:stevioui:channel:" .. key .. "|h" .. text .. "|h"
end

-- The channel key a channel tag link names, or nil for other links.
function History.LinkedChannel(link)
	return link:match("^addon:stevioui:channel:(.+)$")
end

-- The copy of `entry` (from channel `key`, labelled `label`, colored like
-- `chatType`) shown in the merged channel: like a line in "Other" it names its
-- channel before the sender, and `sourceKey` remembers the channel to answer in.
function History.Mirror(entry, key, label, chatType)
	local copy = {}
	for field, value in pairs(entry) do
		copy[field] = value
	end
	copy.source, copy.sourceType, copy.sourceKey = label, chatType, key
	return copy
end

-- Battle.net whisper partners are keyed by BattleTag ("Name#1234"): the
-- account id may change between sessions and the Real ID name in chat events
-- can't be saved; the BattleTag stays. Lines and labels show its name part.
function History.BattleTagName(battleTag)
	return battleTag:match("^([^#]+)") or battleTag
end

function History.BattleNetKey(battleTag)
	return "bn:" .. battleTag
end

-- Community streams added to the chat are chat channels named
-- "Community:<clubId>:<streamId>". Returns both ids as numbers, or nil.
function History.CommunityIds(baseName)
	local clubId, streamId = baseName:match("^Community:(%d+):(%d+)$")
	if clubId then
		return tonumber(clubId), tonumber(streamId)
	end
end

function History.CommunityKey(clubId, streamId)
	return "community:" .. clubId .. ":" .. streamId
end

-- `saved` is the SavedVariables table (may be empty); `limit` caps messages per
-- channel; `mainOn` keeps the merged channel from being deleted.
function History.New(saved, limit, mainOn)
	saved.channels = saved.channels or {}
	return setmetatable({ db = saved, limit = limit, mainOn = mainOn }, Store)
end

function Store:Get(key)
	return self.db.channels[key]
end

-- opts: kind, chatType, label, bnetID, battleTag, target, channelIndex, readOnly, silent,
-- clubId, streamId, relabel. Created on first use; the channel number and color follow
-- the latest message, and so does the label with `relabel` (a renamed community).
function Store:Ensure(key, opts)
	local channel = self.db.channels[key]
	if not channel then
		channel = {
			key = key,
			kind = opts.kind,
			chatType = opts.chatType,
			label = opts.label,
			messages = {},
			unread = 0,
			last = 0,
			readOnly = opts.readOnly,
			silent = opts.silent,
		}
		self.db.channels[key] = channel
	end
	if opts.bnetID then
		channel.bnetID = opts.bnetID
	end
	if opts.battleTag then
		channel.battleTag = opts.battleTag
	end
	if opts.target then
		channel.target = opts.target
	end
	if opts.channelIndex then
		channel.channelIndex = opts.channelIndex
		channel.chatType = opts.chatType
	end
	if opts.clubId then
		channel.clubId, channel.streamId = opts.clubId, opts.streamId
		channel.chatType = opts.chatType
	end
	if opts.relabel then
		channel.label = opts.label
	end
	return channel
end

-- entry: { time, sender, player, text, outgoing, source, sourceType, sourceKey, emote,
-- colorType }: `sender` is nil for finished lines (system, NPC, loot, ...) and text
-- emotes, `player` is the sender's full "Name-Realm" when it is another character,
-- `emote` marks emotes, `source` names the chat channel of a message in "Other"
-- (or Main) and `sourceType` its chat type (for its color); `sourceKey` is the
-- channel a line in Main came from (see History.Mirror); `colorType` is the chat
-- type whose color a finished line takes. Returns the channel.
function Store:Add(key, opts, entry, markUnread)
	local channel = self:Ensure(key, opts)
	local messages = channel.messages
	messages[#messages + 1] = entry
	if #messages > self.limit then
		table.remove(messages, 1)
	end
	channel.last = entry.time or channel.last
	if markUnread and not channel.silent then
		channel.unread = channel.unread + 1
	end
	return channel
end

-- Messages that couldn't be read (secret) still count as unread.
function Store:AddUnreadOnly(key, opts, time)
	local channel = self:Ensure(key, opts)
	if not channel.silent then
		channel.unread = channel.unread + 1
	end
	channel.last = time or channel.last
	return channel
end

function Store:MarkRead(key)
	local channel = self.db.channels[key]
	if channel then
		channel.unread = 0
	end
end

-- `mainOn`: whether the merged channel is in use (only then is it permanent).
function Store.IsDeletable(channel, mainOn)
	return channel.kind ~= "guild" and not (mainOn and channel.kind == "main")
end

-- Removes the channel with its whole history. Guild and the merged channel are permanent.
function Store:Delete(key)
	local channel = self.db.channels[key]
	if not channel or not Store.IsDeletable(channel, self.mainOn) then
		return false
	end
	self.db.channels[key] = nil
	return true
end

function Store:HasUnread(kind)
	for _, channel in pairs(self.db.channels) do
		if channel.unread > 0 and (not kind or channel.kind == kind) then
			return true
		end
	end
	return false
end

-- The merged channel counts no unread of its own: its count is that of the
-- channels it merges (`kinds`, a set of channel kinds), and reading it reads them.
function Store:MergedUnread(kinds)
	local count = 0
	for _, channel in pairs(self.db.channels) do
		if kinds[channel.kind] then
			count = count + channel.unread
		end
	end
	return count
end

function Store:MarkKindsRead(kinds)
	for _, channel in pairs(self.db.channels) do
		if kinds[channel.kind] then
			channel.unread = 0
		end
	end
end

-- Where the merged channel `key` answers: the channel of its latest line whose
-- channel still exists and can be written to. Returns that channel or nil.
function Store:ReplyChannel(key)
	local merged = self.db.channels[key]
	if not merged then
		return nil
	end
	for i = #merged.messages, 1, -1 do
		local source = merged.messages[i].sourceKey
		local channel = source and self.db.channels[source]
		if channel and not channel.readOnly then
			return channel
		end
	end
end

-- The channel with the latest activity, or nil when there is none yet. Opening
-- the chat there shows what just happened instead of an empty channel.
function Store:MostRecent()
	local best
	for _, channel in pairs(self.db.channels) do
		if
			channel.last > 0
			and not channel.silent
			and (not best or channel.last > best.last or (channel.last == best.last and channel.key < best.key))
		then
			best = channel
		end
	end
	return best
end

-- Channels in sidebar order: by kind order, then most recent activity first.
-- Guild is always listed so it can be opened before the first message.
function Store:Sorted(kindOrder)
	self:Ensure("guild", { kind = "guild", chatType = "GUILD", label = "Guild" })
	local list = {}
	for _, channel in pairs(self.db.channels) do
		list[#list + 1] = channel
	end
	table.sort(list, function(a, b)
		local ka, kb = kindOrder[a.kind] or 99, kindOrder[b.kind] or 99
		if ka ~= kb then
			return ka < kb
		end
		if a.last ~= b.last then
			return a.last > b.last
		end
		return a.key < b.key
	end)
	return list
end
