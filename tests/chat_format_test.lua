-- Run with: lua tests/chat_format_test.lua  (from the repo root)
-- Finished lines worded like Blizzard's chat (Modules/Chat/Format.lua).
local check, loadAddonFile = dofile("tests/helpers.lua")

-- The game's globals the formatters read.
local SECRET = {}
local globals = {
	format = string.format,
	Ambiguate = function(name, context)
		return name:gsub("%-.*$", "") .. "<" .. context .. ">"
	end,
	issecretvalue = function(value)
		return value == SECRET
	end,
	CHAT_SAY_GET = "%s says: ",
	CHAT_MONSTER_EMOTE_GET = "",
	CHAT_IGNORED = "%s is ignoring you.",
	CHAT_FILTERED = "%s filtered.",
	CHAT_RESTRICTED_TRIAL = "Trial accounts can't.",
	CHAT_YOU_JOINED_NOTICE = "Joined Channel: [%d. %s]",
	CHAT_KICK_NOTICE_BN = "[%d. %s] %s kicked %s.",
	CHAT_INVITE_NOTICE = "%s: %s invites you.",
	CHAT_SET_MODERATOR_NOTICE = "[%d. %s] %s is now moderator.",
	BN_INLINE_TOAST_FRIEND_ONLINE = "%s has come online.",
	BN_INLINE_TOAST_FRIEND_REQUEST = "%s wants to be friends.",
	BN_INLINE_TOAST_BROADCAST = "%s: %s",
	BN_INLINE_TOAST_BROADCAST_INFORM = "Broadcast sent.",
}
for name, value in pairs(globals) do
	_G[name] = value
end

local ns = loadAddonFile("Modules/Chat/Format.lua", { ChatInternal = {} })
local C = ns.ChatInternal
local f = C.formatters

-- get: Blizzard's "%s says: " prefix
check(f.get("SAY", "hi", "Bob-Thrall") == "Bob<none> says: hi", "get with the chat type's prefix")
check(f.get("WHISPER", "hi", "Bob") == "Bob<none>: hi", "get falls back to a plain prefix")
check(f.get("SAY", "100% done", "Bob") == "Bob<none> says: 100% done", "a stray % keeps the text as it is")
check(f.get("MONSTER_EMOTE", "%s roars.", "Onyxia") == "Onyxia<none> roars.", "NPC emotes name the sender in the text")
check(f.get("SAY", "hi", "") == " says: hi", "empty sender stays empty")
print("get ok")

-- name: achievements name the player as "%s"
check(f.name(nil, "%s earned [Thing].", "Bob") == "[Bob<none>] earned [Thing].", "name")
check(f.name(nil, "%d earned.", "Bob") == "%d earned.", "name keeps text it can't format")

-- guildLoot: "$s" names the player
check(f.guildLoot(nil, "$s receives [Sword].", "Bob") == "[Bob<none>] receives [Sword].", "guild loot with $s")
check(f.guildLoot(nil, "Someone receives [Sword].", "Bob") == "Someone receives [Sword].", "guild loot without $s")

check(f.plain(nil, "text") == "text", "plain")
check(f.ignored(nil, nil, "Bob") == "Bob<none> is ignoring you.", "ignored")
check(f.filtered(nil, nil, "Bob") == "Bob<none> filtered.", "filtered")
check(f.restricted() == "Trial accounts can't.", "restricted")
check(f.ping("SAY", "Attack", "Tank Bob") == "Tank Bob says: Attack", "ping keeps the client's sender")
print("player lines ok")

-- channel notices
check(f.notice(nil, "YOU_JOINED", nil, "Trade", nil, 2) == "Joined Channel: [2. Trade]", "notice")
check(f.notice(nil, "UNKNOWN", nil, "Trade", nil, 2) == nil, "unknown notice")
check(f.noticeUser(nil, "UNKNOWN", "Bob", "Trade", "Al", 2) == nil, "noticeUser without template")
check(
	f.noticeUser(nil, "KICK", "Bob", "Trade", "Al", 2) == "[2. Trade] Bob kicked Al.",
	"noticeUser about another player, Battle.net template first"
)
check(f.noticeUser(nil, "INVITE", "Bob", "Trade", "", 2) == "Trade: [Bob] invites you.", "noticeUser invite")
check(f.noticeUser(nil, "INVITE", "Bob", "Trade", SECRET, 2) == "Trade: [Bob] invites you.", "secret other player")
check(
	f.noticeUser(nil, "SET_MODERATOR", "Bob", "Trade", nil, 2) == "[2. Trade] Bob is now moderator.",
	"noticeUser without another player"
)
print("notices ok")

-- Battle.net
local toastDef = { toast = { FRIEND_ONLINE = true } }
check(f.toast(nil, "FRIEND_ONLINE", "Anna", nil, nil, nil, toastDef) == "Anna has come online.", "toast")
check(f.toast(nil, "FRIEND_REQUEST", "Anna", nil, nil, nil, toastDef) == nil, "unlisted toast token")
check(f.toast(nil, "FRIEND_GONE", "Anna", nil, nil, nil, { toast = { FRIEND_GONE = true } }) == nil, "unknown toast")
check(f.broadcast(nil, "hello", "Anna") == "[Anna]: hello", "broadcast")
check(f.broadcast(nil, "", "Anna") == nil, "empty broadcast")
check(f.broadcastInform(nil, "hello") == "Broadcast sent.", "broadcast inform")
check(f.broadcastInform(nil, "") == nil, "empty broadcast inform")
print("battle.net ok")

-- FormatLine
check(C.FormatLine({ format = "get" }, "SAY", "hi", "Bob") == "Bob<none> says: hi", "format line")
check(C.FormatLine({ format = "nope" }, "SAY", "raw", "Bob") == "raw", "unknown format falls back to the text")
check(C.FormatLine({ format = "ignored" }, "IGNORED", "raw", nil) == "raw", "failing formatter falls back to the text")
check(C.FormatLine({ format = "notice" }, "CHANNEL_NOTICE", "UNKNOWN", nil, "Trade", nil, 1) == nil, "hidden notice")
check(
	C.FormatLine(
		{ format = "toast", toast = { FRIEND_ONLINE = true } },
		"BN_INLINE_TOAST_ALERT",
		"FRIEND_ONLINE",
		"Anna"
	) == "Anna has come online.",
	"format line passes the definition"
)
print("format line ok")

print("chat format tests passed")
