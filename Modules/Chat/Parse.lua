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

-- What a typed command (upper case, not a protected one) is, looked up in
-- `lists`: chatTypes (command -> chat type), chatTypeInfo (chat type -> info),
-- slashCommands (command -> handler), isSecure(table, key) and emotes
-- (command -> emote token). Returns "channel" and the channel number for
-- "/1"; "chatType" and the chat type; "addon" and the handler of an addon's
-- command; "emote" and the token; or "unknown".
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
	-- Commands registered by Blizzard's own code are secure variables; addon
	-- commands are not.
	local handler = lists.slashCommands[command]
	if handler and not lists.isSecure(lists.slashCommands, command) then
		return "addon", handler
	end
	local token = lists.emotes[command]
	if token then
		return "emote", token
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
