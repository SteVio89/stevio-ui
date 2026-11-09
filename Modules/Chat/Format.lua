local _, ns = ...

local C = ns.ChatInternal

-- Messages without a sender of their own (system notices, NPC speech, loot,
-- achievements, ...) are stored as one finished line, worded like Blizzard's
-- chat words them. `def.format` in config.events names the formatter.
-- Each gets the chat type (event name without CHAT_MSG_), the message text,
-- the sender and the channel arguments; it returns the line, or nil when the
-- message isn't shown at all.

local formatters = {}

-- Player names as Blizzard's chat shows them: the realm only for other realms.
local function PlayerName(sender)
	if not sender or sender == "" then
		return sender
	end
	return Ambiguate(sender, "none")
end

-- Blizzard's "%s says: " style prefix of `chatType`.
local function GetPrefix(chatType)
	return _G["CHAT_" .. chatType .. "_GET"] or "%s: "
end

function formatters.plain(_, text)
	return text
end

-- Blizzard's "%s says: " style prefix (CHAT_<TYPE>_GET). NPC emotes also carry
-- the name as "%s" in their own text, so prefix and text are formatted together;
-- text with a stray "%" (a player's AFK reply) falls back to the prefix alone.
function formatters.get(chatType, text, sender)
	sender = PlayerName(sender)
	local prefix = GetPrefix(chatType)
	local ok, line = pcall(format, prefix .. text, sender, sender)
	if ok then
		return line
	end
	return format(prefix, sender) .. text
end

-- Achievements name the player as "%s" inside the text.
function formatters.name(_, text, sender)
	local ok, line = pcall(format, text, "[" .. PlayerName(sender) .. "]")
	return ok and line or text
end

-- A guild member's loot names the player as "$s".
function formatters.guildLoot(_, text, sender)
	local from, to = text:find("$s", 1, true)
	if not from then
		return text
	end
	return text:sub(1, from - 1) .. "[" .. PlayerName(sender) .. "]" .. text:sub(to + 1)
end

function formatters.ignored(_, _, sender)
	return format(CHAT_IGNORED, PlayerName(sender))
end

function formatters.filtered(_, _, sender)
	return format(CHAT_FILTERED, PlayerName(sender))
end

function formatters.restricted()
	return CHAT_RESTRICTED_TRIAL
end

-- The sender of a ping is already worded by the client (it may carry the role).
function formatters.ping(chatType, text, sender)
	return format(GetPrefix(chatType), sender) .. text
end

local function NoticeTemplate(token)
	return _G["CHAT_" .. token .. "_NOTICE_BN"] or _G["CHAT_" .. token .. "_NOTICE"]
end

local function ChannelDisplayName(channelName)
	if ChatFrameUtil and ChatFrameUtil.ResolvePrefixedChannelName and channelName:find("Community:", 1, true) then
		return ChatFrameUtil.ResolvePrefixedChannelName(channelName)
	end
	return channelName
end

-- Channel notices (you joined, left, changed, ...) arrive as a token.
function formatters.notice(_, token, _, channelName, _, channelIndex)
	local template = NoticeTemplate(token)
	return template and format(template, channelIndex, ChannelDisplayName(channelName))
end

-- Notices about other players in a channel (kicked, banned, owner changed, invites).
function formatters.noticeUser(_, token, sender, channelName, otherPlayer, channelIndex)
	local template = NoticeTemplate(token)
	if not template then
		return nil
	end
	if otherPlayer and not issecretvalue(otherPlayer) and otherPlayer ~= "" then
		return format(template, channelIndex, channelName, sender, otherPlayer)
	elseif token == "INVITE" then
		return format(template, channelName, "[" .. sender .. "]")
	end
	return format(template, channelIndex, channelName, sender)
end

-- Battle.net notices arrive as a token (e.g. "FRIEND_ONLINE") plus the friend's
-- name; Blizzard's text for it is a global. Only the tokens listed in
-- `def.toast` are shown, others (requests, pending) take different arguments.
function formatters.toast(_, token, sender, _, _, _, def)
	local template = def.toast[token] and _G["BN_INLINE_TOAST_" .. token]
	return template and format(template, sender)
end

function formatters.broadcast(_, text, sender)
	if text == "" then
		return nil
	end
	return format(BN_INLINE_TOAST_BROADCAST, "[" .. sender .. "]", text)
end

function formatters.broadcastInform(_, text)
	if text == "" then
		return nil
	end
	return BN_INLINE_TOAST_BROADCAST_INFORM
end

-- Returns the finished line for a message of `def`, or nil when it isn't shown.
-- A formatter failing (a missing global string) falls back to the raw text.
function C.FormatLine(def, chatType, text, sender, channelName, otherPlayer, channelIndex)
	local formatter = formatters[def.format]
	local ok, line = pcall(formatter, chatType, text, sender, channelName, otherPlayer, channelIndex, def)
	if not ok then
		return text
	end
	return line
end
