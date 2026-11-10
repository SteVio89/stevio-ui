-- Run with: lua tests/chat_flow_test.lua  (from the repo root)
-- Decisions of the chat flow: delivering a message, cycling channels, finding
-- a Battle.net friend and routing typed commands.
local check, loadAddonFile = dofile("tests/helpers.lua")
local ns = { config = { chat = {} }, ChatInternal = { state = {} } }
loadAddonFile("Modules/Chat/History.lua", ns)
loadAddonFile("Modules/Chat/Parse.lua", ns)
loadAddonFile("Modules/Chat/Receive.lua", ns)
loadAddonFile("Modules/Chat/Send.lua", ns)
local C, History, Parse = ns.ChatInternal, ns.ChatHistory, ns.ChatParse

-- Delivering a message: unread, where it shows, opening and popping up.
do
	local focusAsked = 0
	local function focused()
		focusAsked = focusAsked + 1
		return true
	end
	local function unfocused()
		focusAsked = focusAsked + 1
		return false
	end
	local party = { kind = "group", key = "party" }

	local markUnread, show, open, popUp = C.Delivery(party, "party", false, "guild", false, true, unfocused)
	check(markUnread and show == "party" and open and popUp, "hidden chat peeks at the message's channel")

	markUnread, show, open, popUp = C.Delivery(party, "party", false, "guild", true, false, unfocused)
	check(markUnread and show == "party" and not open and popUp, "open chat stays on its channel")

	markUnread = C.Delivery(party, "party", false, "party", true, false, unfocused)
	check(not markUnread, "read while viewing the channel")
	markUnread = C.Delivery(party, "party", false, "party", false, false, unfocused)
	check(markUnread, "unread when only auto-shown")

	markUnread, show, open = C.Delivery(party, "party", "main", "main", true, false, unfocused)
	check(not markUnread and show == "main" and not open, "read while viewing Main")
	markUnread, show, open = C.Delivery(party, "party", "main", "guild", true, true, unfocused)
	check(markUnread and show == "main" and open, "merged channels show in Main")

	local say = { kind = "public", key = "say", quiet = true }
	markUnread, show, open, popUp = C.Delivery(say, "say", false, "guild", false, true, unfocused)
	check(markUnread and show == "say" and not open and not popUp, "quiet channels only count unread")

	local outgoing = { kind = "whisper", outgoing = true }
	markUnread, show, open, popUp = C.Delivery(outgoing, "whisper:Bob", "main", "guild", false, true, unfocused)
	check(not markUnread and show == "main" and not open and not popUp, "outgoing never counts unread nor pops up")

	focusAsked = 0
	local answer = { key = "system", focus = true }
	markUnread, show, open, popUp = C.Delivery(answer, "system", false, "guild", true, false, unfocused)
	check(markUnread and show == "system" and open and popUp, "focus channels open in the open chat")
	open = select(3, C.Delivery(answer, "system", false, "guild", true, false, focused))
	check(not open, "focus channels don't interrupt typing")
	check(focusAsked == 2, "input focus asked for focus channels")
	open = select(3, C.Delivery(answer, "system", false, "system", true, false, unfocused))
	check(not open and focusAsked == 2, "focus channel already open: focus not asked")
	open = select(3, C.Delivery(answer, "system", false, "guild", true, true, focused))
	check(open and focusAsked == 2, "hidden chat: focus not asked")
end
print("delivery ok")

-- Cycling channels with Tab and the bindings.
do
	local keys = { "a", "b", "c" }
	check(History.NextIndex(keys, "a", 1) == 2, "next")
	check(History.NextIndex(keys, "c", 1) == 1, "next wraps")
	check(History.NextIndex(keys, "a", -1) == 3, "previous wraps")
	check(History.NextIndex(keys, "b", -1) == 1, "previous")
	check(History.NextIndex(keys, "x", 1) == 1, "unknown selection: next is the first")
	check(History.NextIndex(keys, nil, -1) == 2, "unknown selection: previous is the second to last")
	check(History.NextIndex({ "a" }, "a", 1) == 1 and History.NextIndex({ "a" }, nil, -1) == 1, "one channel")
	check(History.NextIndex({}, nil, 1) == nil, "no channels")
end
print("cycling ok")

-- Battle.net whispers look the friend up by BattleTag.
do
	local friends = {
		{ battleTag = "Anna#1", bnetAccountID = 11 },
		{ battleTag = "Bo#2", bnetAccountID = 22 },
	}
	local asked = 0
	local function numFriends()
		asked = asked + 1
		return #friends
	end
	local function friendInfo(index)
		return friends[index]
	end
	local channel = { battleTag = "Bo#2", bnetID = 5 }
	check(C.CurrentBattleNetID(channel, numFriends, friendInfo) == 22, "friend found by BattleTag")
	check(channel.bnetID == 22, "the current id is remembered")
	channel = { battleTag = "Gone#3", bnetID = 5 }
	check(C.CurrentBattleNetID(channel, numFriends, friendInfo) == nil, "friend no longer listed")
	check(channel.bnetID == 5, "a missing friend keeps the old id stored")
	asked = 0
	check(C.CurrentBattleNetID({ bnetID = 7 }, numFriends, friendInfo) == 7, "no BattleTag: the session id")
	check(asked == 0, "no BattleTag: friend list not read")
	check(C.CurrentBattleNetID({ battleTag = "Anna#1" }, numFriends, function()
		return nil
	end) == nil, "friend info not loaded yet")
end
print("battle.net friends ok")

-- Typed commands.
do
	local secure = { ["/HELP"] = true }
	local slashCommands = {
		["/SUI"] = function() end,
		["/HELP"] = function() end,
	}
	local lists = {
		chatTypes = { ["/P"] = "PARTY", ["/W"] = "WHISPER", ["/X"] = "IGNORED", ["/Y"] = "UNKNOWN" },
		chatTypeInfo = { PARTY = {}, WHISPER = {}, IGNORED = { ignoreChatTypeProcessing = true } },
		slashCommands = slashCommands,
		isSecure = function(t, key)
			check(t == slashCommands, "secure check on the slash command list")
			return secure[key] == true
		end,
		emotes = { ["/DANCE"] = "DANCE", ["/HELP"] = "HELPME", ["/X"] = "XEMOTE" },
	}
	local kind, value = Parse.Classify("/1", lists)
	check(kind == "channel" and value == "1", "numbered channel")
	kind, value = Parse.Classify("/P", lists)
	check(kind == "chatType" and value == "PARTY", "chat type")
	kind, value = Parse.Classify("/SUI", lists)
	check(kind == "addon" and value == lists.slashCommands["/SUI"], "addon command")
	kind, value = Parse.Classify("/HELP", lists)
	check(kind == "emote" and value == "HELPME", "Blizzard's own command falls through to its emote")
	kind, value = Parse.Classify("/X", lists)
	check(kind == "emote" and value == "XEMOTE", "chat types ignoring processing fall through")
	kind = Parse.Classify("/Y", lists)
	check(kind == "unknown", "chat type without info")
	kind, value = Parse.Classify("/DANCE", lists)
	check(kind == "emote" and value == "DANCE", "emote")
	kind, value = Parse.Classify("/NOPE", lists)
	check(kind == "unknown" and value == nil, "unknown command")
	kind = Parse.Classify("/1A", lists)
	check(kind == "unknown", "not a channel number")
end
print("commands ok")

print("chat flow tests passed")
