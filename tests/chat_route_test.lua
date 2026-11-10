-- Run with: lua tests/chat_route_test.lua  (from the repo root)
-- Which channel a chat message goes to, and the entry stored for it.
local check, loadAddonFile = dofile("tests/helpers.lua")
local ns = loadAddonFile("Modules/Chat/History.lua")
local History = ns.ChatHistory

local SECRET = {}
local friends = { [7] = { battleTag = "Anna#1234" }, [8] = { battleTag = "" } }
local lookups = {
	isSecret = function(value)
		return value == SECRET
	end,
	accountInfo = function(bnetID)
		return friends[bnetID]
	end,
	channelLabel = function(baseName)
		return "Resolved " .. baseName
	end,
	ambiguate = function(name, context)
		return context .. ":" .. name
	end,
}
local publicChannels = { "General", "Trade" }

local function Route(def, sender, bnetID, channelIndex, baseName, fullName)
	return History.Route(def, sender, bnetID, channelIndex, baseName, fullName, publicChannels, lookups)
end

-- Fixed channels: the definition names the key.
do
	local def = { kind = "group", key = "party", chatType = "PARTY", label = "Party", prefix = "[x] " }
	local key, opts, source, sourceType, name = Route(def, "Bob", 0, 0, "")
	check(key == "party", "def.key is the key")
	check(opts.kind == "group" and opts.chatType == "PARTY" and opts.label == "Party", "def.key options")
	check(opts.prefix == nil and opts ~= def, "def.key options are a fresh table of channel fields")
	check(source == nil and sourceType == nil and name == nil, "def.key has no source")
	local system = { kind = "system", key = "system", chatType = "SYSTEM", label = "System", readOnly = true }
	key, opts = Route(system, nil, SECRET, SECRET, SECRET)
	check(key == "system" and opts.readOnly, "def.key ignores secret arguments")
end

-- Numbered chat channels and communities.
do
	local def = { kind = "public", chatType = "CHANNEL", channel = true, quiet = true }
	local key, opts, source, sourceType = Route(def, "Bob", 0, 3, "Community:12:3")
	check(key == "community:12:3", "community key")
	check(opts.kind == "community" and opts.chatType == "CHANNEL3", "community options")
	check(opts.label == "Resolved Community:12:3" and opts.relabel, "community label is resolved and follows renames")
	check(opts.clubId == 12 and opts.streamId == 3, "community ids")
	check(source == nil and sourceType == nil, "community has no source")

	key, opts, source, sourceType = Route(def, "Bob", 0, 2, "trade")
	check(key == "channel:trade" and opts.kind == "public", "public channel of its own")
	check(opts.chatType == "CHANNEL2" and opts.channelIndex == 2 and opts.label == "trade", "public channel options")
	check(source == nil and sourceType == nil, "public channel has no source")

	key, opts, source, sourceType = Route(def, "Bob", 0, 5, "LookingForGroup")
	check(key == "other" and opts.kind == "other" and opts.readOnly, "other channels share Other")
	check(opts.chatType == "CHANNEL" and opts.label == "Other", "Other options")
	check(source == "LookingForGroup" and sourceType == "CHANNEL5", "Other names the line's channel")

	check(Route(def, "Bob", 0, 5, SECRET) == nil, "secret channel name")
	check(Route(def, "Bob", 0, SECRET, "Trade") == nil, "secret channel number")
	check(Route(def, "Bob", 0, 5, nil) == nil, "no channel name")
	check(Route(def, SECRET, SECRET, 2, "Trade") == "channel:trade", "channels don't need the sender")
end

-- Battle.net whispers.
do
	local def = { kind = "whisper", chatType = "BN_WHISPER", bnet = true }
	local key, opts, source, sourceType, name = Route(def, "|Kq1|k", 7, 0, "")
	check(key == "bn:Anna#1234", "BattleTag key")
	check(opts.label == "Anna" and opts.bnetID == 7 and opts.battleTag == "Anna#1234", "BattleTag options")
	check(source == nil and sourceType == nil and name == "Anna", "BattleTag name is shown as sender")

	key, opts, source, sourceType, name = Route(def, "|Kq2|k", 9, 0, "")
	check(key == "bn:9", "no account info: keyed by the session id")
	check(opts.label == "Battle.net" and opts.bnetID == 9 and opts.battleTag == nil, "session id options")
	check(source == nil and sourceType == nil and name == nil, "no BattleTag: the sender stays")
	check(Route(def, "|Kq3|k", 8, 0, "") == "bn:8", "empty BattleTag: keyed by the session id")

	check(Route(def, SECRET, 7, 0, "") == nil, "secret Battle.net sender")
	check(Route(def, "|Kq1|k", SECRET, 0, "") == nil, "secret Battle.net id")
end

-- Character whispers.
do
	local def = { kind = "whisper", chatType = "WHISPER" }
	local key, opts, source, sourceType, name = Route(def, "Bob", 0, 0, "", "Bob-Thrall")
	check(key == "whisper:Bob-Thrall", "whisper key is the full name")
	check(opts.kind == "whisper" and opts.chatType == "WHISPER", "whisper options")
	check(opts.label == "none:Bob-Thrall" and opts.target == "Bob-Thrall", "whisper label and target")
	check(source == nil and sourceType == nil and name == nil, "whisper has no source")
	check(Route(def, SECRET, 0, 0, "", false) == nil, "secret whisper sender")
end
print("route ok")

-- Stored entries.
do
	local def = { kind = "group", key = "raid", prefix = "[RW] " }
	local entry = History.BuildEntry(def, "RAID_WARNING", "pull", "Bob", "Bob-Thrall", nil, nil, 100, nil)
	check(entry.time == 100 and entry.sender == "Bob" and entry.player == "Bob-Thrall", "entry fields")
	check(entry.text == "[RW] pull", "prefix")
	check(entry.outgoing == nil and entry.emote == nil and entry.colorType == nil, "plain entry")

	entry = History.BuildEntry(
		{ kind = "whisper", outgoing = true },
		"WHISPER_INFORM",
		"hi",
		"Bob",
		false,
		nil,
		nil,
		1,
		"Me"
	)
	check(entry.sender == "Me" and entry.outgoing and entry.player == nil, "outgoing lines name the player")
	check(entry.text == "hi", "no prefix")

	entry = History.BuildEntry(
		{ kind = "whisper", outgoing = true },
		"WHISPER_INFORM",
		"hi",
		"Bob",
		false,
		nil,
		nil,
		1,
		nil
	)
	check(entry.sender == "Bob", "outgoing without a name keeps the sender")

	entry =
		History.BuildEntry({ key = "progress", format = "plain" }, "LOOT", "You receive loot.", nil, false, nil, nil, 2)
	check(entry.colorType == "LOOT" and entry.sender == nil, "finished lines take their kind's color")

	entry = History.BuildEntry({ key = "say", emote = true }, "EMOTE", "waves.", "Bob", "Bob-Thrall", nil, nil, 3)
	check(entry.emote, "emote")

	entry =
		History.BuildEntry({ kind = "public", channel = true }, "CHANNEL", "lfg", "Bob", "Bob-T", "LFG", "CHANNEL5", 4)
	check(entry.source == "LFG" and entry.sourceType == "CHANNEL5", "lines in Other name their channel")
end
print("entries ok")

print("chat route tests passed")
