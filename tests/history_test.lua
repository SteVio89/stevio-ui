-- Run with: lua tests/history_test.lua  (from the repo root)
local ns = {}
assert(loadfile("Modules/Chat/History.lua"))("stevio-ui", ns)
local History = ns.ChatHistory

local function check(cond, msg)
	if not cond then
		error("FAIL: " .. msg, 2)
	end
end

local store = History.New({}, 3)
local party = { kind = "group", chatType = "PARTY", label = "Party" }
local whisper = { kind = "whisper", chatType = "WHISPER", label = "Bob" }

for i = 1, 5 do
	store:Add("party", party, { time = i, sender = "A", text = "m" .. i }, true)
end
local channel = store:Get("party")
check(#channel.messages == 3, "history is capped")
check(channel.messages[1].text == "m3", "oldest messages are dropped")
check(channel.unread == 5, "unread counts every message")
store:MarkRead("party")
check(channel.unread == 0, "mark read")

store:Add("whisper:Bob", whisper, { time = 10, text = "hi" }, true)
store:AddUnreadOnly("whisper:Bob", whisper, 11)
check(store:Get("whisper:Bob").unread == 2, "unread-only increments")
check(store:HasUnread("whisper") and not store:HasUnread("guild"), "unread per kind")
check(store:HasUnread(), "unread overall")

store:Add("whisper:Al", { kind = "whisper", chatType = "WHISPER", label = "Al" }, { time = 20, text = "x" }, false)
local order = { group = 1, guild = 2, whisper = 3 }
local sorted = store:Sorted(order)
local keys = {}
for _, c in ipairs(sorted) do
	keys[#keys + 1] = c.key
end
check(table.concat(keys, ",") == "party,guild,whisper:Al,whisper:Bob", "sort order: " .. table.concat(keys, ","))

check(store:Delete("whisper:Bob"), "whisper deletable")
check(store:Get("whisper:Bob") == nil, "deleted channel is gone")
check(store:Delete("party"), "group deletable")
check(not store:Delete("guild"), "guild is not deletable")
check(store:Get("guild") ~= nil, "guild stays")
check(not store:Delete("nope"), "unknown channel")

-- history survives a reload: the saved table is reused
local saved = {}
History.New(saved, 3):Add("party", party, { time = 1, text = "kept" }, false)
check(History.New(saved, 3):Get("party").messages[1].text == "kept", "persists via saved table")
print("ok")

check(History.StripMarkup("|cffff0000hi|r |Hitem:1|h[Sword]|h |TFoo:0|t||") == "hi [Sword] |", "markup is stripped")
local transcript = History.Transcript(
	{ messages = {
		{ time = 5, sender = "A", text = "|cff00ff00x|r" },
		{ sender = "B", text = "y" },
	} },
	function(t)
		return "t" .. t
	end
)
check(transcript == "[t5] A: x\n[--:--] B: y", "transcript format")

local explicit = { "Trade", "General" }
local key, label, own = History.PublicChannel("trade", explicit)
check(key == "channel:trade" and label == "trade" and own, "explicit channel gets its own channel")
key, label, own = History.PublicChannel("LookingForGroup", explicit)
check(key == "other" and label == "Other" and not own, "other channels share Other")

local publicStore = History.New({}, 3)
publicStore:Add(
	"channel:trade",
	{ kind = "public", chatType = "CHANNEL2", label = "Trade", channelIndex = 2 },
	{ time = 1, text = "a" },
	true
)
publicStore:Add(
	"channel:trade",
	{ kind = "public", chatType = "CHANNEL5", label = "Trade", channelIndex = 5 },
	{ time = 2, text = "b" },
	true
)
check(publicStore:Get("channel:trade").channelIndex == 5, "channel number follows the latest message")
check(publicStore:Get("channel:trade").chatType == "CHANNEL5", "channel color follows the channel number")
publicStore:Add(
	"other",
	{ kind = "other", chatType = "CHANNEL", label = "Other", readOnly = true },
	{ time = 3, text = "c" },
	true
)
check(publicStore:Get("other").readOnly, "Other is read-only")
check(publicStore:HasUnread("public") and publicStore:HasUnread("other"), "unread for public kinds")
print("public channels ok")

local recentStore = History.New({}, 3)
check(recentStore:MostRecent() == nil, "no recent channel without activity")
recentStore:Sorted({}) -- creates the empty guild channel
check(recentStore:MostRecent() == nil, "empty guild is not recent")
recentStore:Add("say", { kind = "public", chatType = "SAY", label = "Say" }, { time = 5, text = "a" }, true)
recentStore:AddUnreadOnly("party", party, 7)
recentStore:Add("yell", { kind = "public", chatType = "YELL", label = "Yell" }, { time = 6, text = "b" }, true)
check(recentStore:MostRecent().key == "party", "most recent channel, secret messages included")
print("most recent ok")

-- time first, then the chat channel (in "Other"), then the sender
check(History.Line({ sender = "A", text = "hi" }, "12:00") == "12:00 A: hi", "line with sender")
check(History.Line({ source = "LFG", sender = "A", text = "hi" }, "12:00") == "12:00 [LFG] A: hi", "line in Other")
check(
	History.Line({ text = "Bob has come online." }, "12:00") == "12:00 Bob has come online.",
	"system line has no sender"
)
check(
	History.Line({ source = "LFG", sender = "A", text = "hi" }, "t", "<LFG>", "<A>") == "t [<LFG>] <A>: hi",
	"formatted parts"
)
transcript = History.Transcript({
	messages = {
		{ time = 1, source = "LFG", sender = "A", text = "x" },
		{ time = 2, text = "Bob has gone offline." },
	},
}, function(t)
	return "t" .. t
end)
check(
	transcript == "[t1] [LFG] A: x\n[t2] Bob has gone offline.",
	"transcript with source and system line: " .. transcript
)
check(
	History.Line({ sender = "Bob", text = "waves happily.", emote = true }, "12:00") == "12:00 Bob waves happily.",
	"emote line has no colon"
)
check(
	History.Line({ text = "Bob dances.", emote = true }, "12:00") == "12:00 Bob dances.",
	"text emote carries the name"
)
check(
	History.Line({ sender = "Bob", text = "waves.", emote = true }, "t", nil, "<Bob>") == "t <Bob> waves.",
	"formatted emote"
)
print("line format ok")

-- a date line before the first message of each day; untimed messages don't count
local function day(t)
	return "d" .. math.floor(t / 100)
end
check(History.StartsDay(nil, { time = 5 }, day), "first message starts a day")
check(not History.StartsDay({ time = 5 }, { time = 50 }, day), "same day")
check(History.StartsDay({ time = 50 }, { time = 150 }, day), "next day")
check(not History.StartsDay({ time = 50 }, { text = "x" }, day), "untimed message starts no day")
transcript = History.Transcript({
	messages = {
		{ time = 10, sender = "A", text = "x" },
		{ time = 20, sender = "B", text = "y" },
		{ sender = "C", text = "z" },
		{ time = 120, sender = "A", text = "w" },
	},
}, function(t)
	return "t" .. t
end, day)
check(
	transcript == "-- d0 --\n[t10] A: x\n[t20] B: y\n[--:--] C: z\n-- d1 --\n[t120] A: w",
	"transcript with dates: " .. transcript
)
check(History.Transcript({ messages = { { time = 1, text = "a" } } }, nil) == "[1] a", "no date lines without day")
print("dates ok")

-- community streams added to the chat
local clubId, streamId = History.CommunityIds("Community:123:4")
check(clubId == 123 and streamId == 4, "community ids")
check(History.CommunityIds("Trade") == nil, "not a community")
check(History.CommunityKey(123, 4) == "community:123:4", "community key")
local communityStore = History.New({}, 3)
communityStore:Add(
	"community:1:2",
	{ kind = "community", chatType = "CHANNEL3", label = "Old", relabel = true, clubId = 1, streamId = 2 },
	{ time = 1, text = "a" },
	true
)
communityStore:Add(
	"community:1:2",
	{ kind = "community", chatType = "CHANNEL4", label = "New", relabel = true, clubId = 1, streamId = 2 },
	{ time = 2, text = "b" },
	true
)
local community = communityStore:Get("community:1:2")
check(community.label == "New" and community.clubId == 1 and community.streamId == 2, "community follows its name")
check(community.chatType == "CHANNEL4", "community color follows the channel number")
print("communities ok")

-- whispers are keyed by the full name, also across realms
check(History.FullName("Bob", "Aegwynn") == "Bob-Aegwynn", "own realm is added")
check(History.FullName("Bob-Thrall", "Aegwynn") == "Bob-Thrall", "other realm is kept")
check(History.FullName("Bob", nil) == "Bob", "unknown realm leaves the name")
print("whisper names ok")

-- Battle.net whispers are keyed by BattleTag
check(History.BattleTagName("Stevio#2345") == "Stevio", "BattleTag name")
check(History.BattleTagName("Plain") == "Plain", "no number")
check(History.BattleNetKey("Stevio#2345") == "bn:Stevio#2345", "BattleTag key")
print("battle.net names ok")

-- clickable player names open a whisper
local link = History.PlayerLink("Bob-Thrall", "|cffffffffBob|r")
check(link == "|Hplayer:Bob-Thrall|h|cffffffffBob|r|h", "player link: " .. link)
check(History.LinkedPlayer("player:Bob-Thrall") == "Bob-Thrall", "own player link")
check(History.LinkedPlayer("player:Bob-Thrall:42:PARTY:") == "Bob-Thrall", "Blizzard's player link")
check(History.LinkedPlayer("item:1234") == nil, "other links name no player")
check(History.LinkedPlayer("player:") == nil, "empty player link")
check(
	History.StripMarkup(History.Line({ sender = "Bob", text = "hi" }, "[12:00]", nil, link)) == "[12:00] Bob: hi",
	"copied lines drop the link"
)
print("player links ok")

-- Silent channels keep their lines but never count unread or as latest activity.
do
	local s = History.New({}, 10)
	local notices = { kind = "notices", chatType = "SYSTEM", label = "Notices", readOnly = true, silent = true }
	s:Add("guild", { kind = "guild", chatType = "GUILD", label = "Guild" }, { time = 1, text = "g" }, false)
	s:Add("notices", notices, { time = 5, text = "Bob creates [Flask]." }, true)
	s:AddUnreadOnly("notices", notices, 6)
	check(#s:Get("notices").messages == 1, "silent channel keeps its lines")
	check(s:Get("notices").unread == 0, "silent channel never counts unread")
	check(not s:HasUnread(), "silent channel adds no unread")
	check(s:MostRecent().key == "guild", "silent channel is never the latest activity")
end

-- The merged channel: mirrored lines, unread of its members, reply target.
do
	local s = History.New({}, 10, true)
	local kinds = { group = true, guild = true, whisper = true }
	local main = { kind = "main", chatType = "SAY", label = "Main" }
	local partyOpts = { kind = "group", chatType = "PARTY", label = "Party" }
	local entry = { time = 1, sender = "Bob", text = "pull" }
	s:Add("party", partyOpts, entry, true)
	local copy = History.Mirror(entry, "party", "Party", "PARTY")
	check(copy ~= entry and entry.source == nil, "mirror copies the entry")
	check(
		copy.source == "Party" and copy.sourceType == "PARTY" and copy.sourceKey == "party",
		"mirror tags its channel"
	)
	check(History.Line(copy, "12:00") == "12:00 [Party] Bob: pull", "mirrored line names its channel")
	s:Add("main", main, copy, false)
	s:Add("guild", { kind = "guild", chatType = "GUILD", label = "Guild" }, { time = 2, text = "hi" }, true)
	s:Add("main", main, History.Mirror({ time = 2, text = "hi" }, "guild", "Guild", "GUILD"), false)
	s:AddUnreadOnly("say", { kind = "public", chatType = "SAY", label = "Say" }, 3)
	check(s:Get("main").unread == 0, "merged channel has no unread of its own")
	check(s:MergedUnread(kinds) == 2, "merged unread sums its members")
	check(s:ReplyChannel("main").key == "guild", "reply goes to the latest line's channel")
	s:Get("guild").readOnly = true
	check(s:ReplyChannel("main").key == "party", "reply skips read-only channels")
	s:Delete("party")
	check(s:ReplyChannel("main") == nil, "reply skips deleted channels")
	check(not s:Delete("main"), "merged channel can't be deleted")
	s:MarkKindsRead(kinds)
	check(s:MergedUnread(kinds) == 0 and s:Get("say").unread == 1, "reading the merged channel reads only its members")

	local channelLink = History.ChannelLink("whisper:Bob-Realm", "[Bob]")
	check(History.LinkedChannel(channelLink:match("^|H(.-)|h")) == "whisper:Bob-Realm", "channel link round trip")
	check(History.LinkedChannel("player:Bob-Realm") == nil, "player links aren't channel links")
	check(History.StripMarkup(channelLink) == "[Bob]", "channel links strip for copying")
end
print("merged channel ok")

do
	local off = History.New({}, 10, false)
	off:Ensure("main", { kind = "main", chatType = "SAY", label = "Main" })
	check(off:Delete("main"), "merged channel can be deleted once turned off")
end
print("merged channel off ok")
