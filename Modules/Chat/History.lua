local _, ns = ...

-- Channel store behind the chat: pure data, no frames, so it can be unit tested
-- outside the game (see tests/history_test.lua). A channel is
-- { key, kind, chatType, label, messages = {...}, unread, last, bnetID, target,
--   channelIndex, readOnly }.

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

-- Plain-text transcript of a channel, one "[stamp] sender: text" line per message.
-- `stamp(time)` formats the time (defaults to the raw number).
function History.Transcript(channel, stamp)
	local lines = {}
	for _, entry in ipairs(channel.messages) do
		local when = entry.time and (stamp and stamp(entry.time) or tostring(entry.time)) or "--:--"
		lines[#lines + 1] = History.StripMarkup(("[%s] %s: %s"):format(when, entry.sender or "?", entry.text or ""))
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

-- `saved` is the SavedVariables table (may be empty); `limit` caps messages per channel.
function History.New(saved, limit)
	saved.channels = saved.channels or {}
	return setmetatable({ db = saved, limit = limit }, Store)
end

function Store:Get(key)
	return self.db.channels[key]
end

-- opts: kind, chatType, label, bnetID, target, channelIndex, readOnly.
-- Created on first use; the channel number and color follow the latest message.
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
		}
		self.db.channels[key] = channel
	end
	if opts.bnetID then
		channel.bnetID = opts.bnetID
	end
	if opts.target then
		channel.target = opts.target
	end
	if opts.channelIndex then
		channel.channelIndex = opts.channelIndex
		channel.chatType = opts.chatType
	end
	return channel
end

-- entry: { time, sender, text, outgoing }. Returns the channel.
function Store:Add(key, opts, entry, markUnread)
	local channel = self:Ensure(key, opts)
	local messages = channel.messages
	messages[#messages + 1] = entry
	if #messages > self.limit then
		table.remove(messages, 1)
	end
	channel.last = entry.time or channel.last
	if markUnread then
		channel.unread = channel.unread + 1
	end
	return channel
end

-- Messages that couldn't be read (secret) still count as unread.
function Store:AddUnreadOnly(key, opts, time)
	local channel = self:Ensure(key, opts)
	channel.unread = channel.unread + 1
	channel.last = time or channel.last
	return channel
end

function Store:MarkRead(key)
	local channel = self.db.channels[key]
	if channel then
		channel.unread = 0
	end
end

function Store.IsDeletable(channel)
	return channel.kind ~= "guild"
end

-- Removes the channel with its whole history. Guild is permanent.
function Store:Delete(key)
	local channel = self.db.channels[key]
	if not channel or not Store.IsDeletable(channel) then
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
