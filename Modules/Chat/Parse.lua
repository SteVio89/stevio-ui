local _, ns = ...

-- Parsing of slash commands typed into the channel view's input: pure, no WoW
-- API, so it can be unit tested outside the game (see tests/chat_parse_test.lua).

local Parse = {}
ns.ChatParse = Parse

-- "/w Bob hi" -> "/W", "Bob hi". nil for text that isn't a command.
function Parse.Command(text)
	local command = text:match("^(/%S+)")
	if not command then
		return nil
	end
	local rest = text:sub(#command + 1):match("^%s*(.-)%s*$")
	return command:upper(), rest
end

-- Start and end of each word in `text`.
local function Words(text)
	local words = {}
	local position = 1
	while true do
		local from, to = text:find("%S+", position)
		if not from then
			return words
		end
		words[#words + 1] = { from = from, to = to }
		position = to + 1
	end
end

-- Splits "<target> <message>" for a whisper. Battle.net account names may
-- contain spaces, so the longest run of leading words that `isBattleNetName`
-- accepts wins; otherwise the target is the first word (character names have
-- no spaces). Returns target, message and whether the target is a Battle.net
-- name; nil when there is no message after the target.
function Parse.WhisperTarget(text, isBattleNetName)
	local words = Words(text)
	if #words < 2 then
		return nil
	end
	if isBattleNetName then
		for count = #words - 1, 1, -1 do
			local name = text:sub(words[1].from, words[count].to)
			if isBattleNetName(name) then
				return name, text:sub(words[count + 1].from), true
			end
		end
	end
	return text:sub(words[1].from, words[1].to), text:sub(words[2].from), false
end

-- Adds every command spelled by the globals `prefix .. 1`, `prefix .. 2`, ...
-- (upper case) to `hash` with `value`, keeping commands already in it. With
-- `marks`, each added command is also set to `mark` there.
local function AddCommands(hash, getGlobal, prefix, value, marks, mark)
	local i = 1
	local command = getGlobal(prefix .. i)
	while type(command) == "string" do
		command = command:upper()
		if hash[command] == nil then
			hash[command] = value
			if marks then
				marks[command] = mark
			end
		end
		i = i + 1
		command = getGlobal(prefix .. i)
	end
end

-- `list` and, when its metatable has one, the table behind its __index.
local function ListAndProxy(list)
	local meta = getmetatable(list)
	local proxy = type(meta) == "table" and meta.__index
	if type(proxy) == "table" then
		return { list, proxy }
	end
	return { list }
end

-- The command tables Parse.Classify looks commands up in, built from the
-- game's own lists. Blizzard's ChatFrameUtil.ImportAllListsToHash would fill
-- its hash_ tables from addon code, tainting them: Blizzard's commands would
-- then look like addon commands and run from here. `game` holds slashCmdList,
-- chatTypeInfo, getGlobal(name), isSecure(table, key) and maxEmoteIndex.
-- Chat types and emotes don't change during a session, so pass the previous
-- result as `cached` to reuse them; slash commands are read fresh each time
-- (addons may add some later).
--
-- Blizzard's import (run once at load, before any addon, and again whenever
-- its input box parses a line) moves the entries of SlashCmdList and
-- ChatTypeInfo into a proxy table behind their metatable's __index, leaving
-- the lists themselves empty. So both are read: the list (entries added since
-- the last import) and its proxy (everything imported).
function Parse.Lookups(game, cached)
	local lists = {
		chatTypeInfo = game.chatTypeInfo,
		slashCommands = {},
		secure = {},
	}
	for _, list in ipairs(ListAndProxy(game.slashCmdList)) do
		for name, handler in pairs(list) do
			local secure = game.isSecure(list, name) and true or false
			AddCommands(lists.slashCommands, game.getGlobal, "SLASH_" .. name, handler, lists.secure, secure)
		end
	end

	if cached then
		lists.chatTypes, lists.emotes = cached.chatTypes, cached.emotes
		return lists
	end
	lists.chatTypes = {}
	for _, list in ipairs(ListAndProxy(game.chatTypeInfo)) do
		for chatType in pairs(list) do
			AddCommands(lists.chatTypes, game.getGlobal, "SLASH_" .. chatType, chatType)
		end
	end
	lists.emotes = {}
	for i = 1, game.maxEmoteIndex or 0 do
		local token = game.getGlobal("EMOTE" .. i .. "_TOKEN")
		if token then
			AddCommands(lists.emotes, game.getGlobal, "EMOTE" .. i .. "_CMD", token)
		end
	end
	return lists
end

-- What a typed command (upper case, not a protected one) is, looked up in
-- `lists` (see Parse.Lookups): chatTypes (command -> chat type), chatTypeInfo
-- (chat type -> info), slashCommands (command -> handler), secure (command ->
-- whether Blizzard's own code registered it) and emotes (command -> emote
-- token). Returns "channel" and the channel number for "/1"; "chatType" and
-- the chat type; "addon" and the handler of an addon's command; "emote" and
-- the token; "blizzard" for Blizzard's own other commands; or "unknown".
function Parse.Classify(command, lists)
	local channelNumber = command:match("^/(%d+)$")
	if channelNumber then
		return "channel", channelNumber
	end
	local chatType = lists.chatTypes[command]
	local info = chatType and lists.chatTypeInfo[chatType]
	if info and not info.ignoreChatTypeProcessing then
		return "chatType", chatType
	end
	local handler = lists.slashCommands[command]
	if handler and not lists.secure[command] then
		return "addon", handler
	end
	local token = lists.emotes[command]
	if token then
		return "emote", token
	end
	if handler then
		return "blizzard"
	end
	return "unknown"
end

-- Splits "<first word> <rest>"; rest is nil when there is none.
function Parse.FirstWord(text)
	local first, rest = text:match("^(%S+)%s+(.+)$")
	if first then
		return first, rest
	end
	return text ~= "" and text or nil, nil
end
