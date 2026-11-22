-- Run with: lua tests/chat_lockdown_test.lua  (from the repo root)
-- Chat lines that arrive secret during the chat lockdown (encounters, ...)
-- are kept as placeholders and read once it is over (#38).
local check, loadAddonFile = dofile("tests/helpers.lua")

-- The client: secret values are tables marked as such; chat lines are read
-- back by line id once the lockdown is over.
local SECRET = setmetatable({}, {
	__tostring = function()
		return "secret"
	end,
})
local lockdown = true
local lines = {}
_G.issecretvalue = function(value)
	return value == SECRET
end
_G.Ambiguate = function(name)
	return (name:gsub("%-.*", ""))
end
_G.time = function()
	return 100
end
_G.GetNormalizedRealmName = function()
	return "Realm"
end
_G.UnitName = function()
	return "Me"
end
_G.C_ChatInfo = {
	InChatMessagingLockdown = function()
		return lockdown
	end,
	GetChatLineText = function(lineID)
		if lockdown then
			return SECRET
		end
		return lines[lineID] and lines[lineID].text
	end,
	GetChatLineSenderName = function(lineID)
		if lockdown then
			return SECRET
		end
		return lines[lineID] and lines[lineID].sender
	end,
}

local party = { kind = "group", key = "party", chatType = "PARTY", merge = "party" }
local ns = {
	T = function(en)
		return en
	end,
	config = {
		chat = {
			main = { enabled = true, key = "main", kind = "main", channels = { party = true, whisper = true } },
			events = {
				CHAT_MSG_PARTY = party,
				CHAT_MSG_WHISPER = { kind = "whisper", chatType = "WHISPER", merge = "whisper" },
				CHAT_MSG_BN_WHISPER = { kind = "whisper", chatType = "BN_WHISPER", merge = "whisper", bnet = true },
				CHAT_MSG_GUILD = { kind = "group", key = "guild", chatType = "GUILD" },
			},
			cityChannels = {},
			autoShowDuration = 10,
			preview = { enabled = true },
		},
	},
	ChatInternal = { state = {}, hidden = true },
}
loadAddonFile("Modules/Chat/History.lua", ns)
loadAddonFile("Modules/Chat/Receive.lua", ns)
local C, History = ns.ChatInternal, ns.ChatHistory
local config = ns.config.chat

C.store = History.New({}, 10, true)
C.store:Ensure("main", config.main)
C.ui = {
	input = {
		HasFocus = function()
			return false
		end,
	},
}
local rendered = 0
C.IsMerged = function(def)
	return def.merge ~= nil and config.main.channels[def.merge] == true
end
C.Attended = function()
	return false
end
C.Label = function(channel)
	return channel.label or channel.key
end
C.ShowEntry = function() end
C.Peek = function() end
local previews = {}
C.ShowPreview = function(channel, entry)
	previews[#previews + 1] = { key = channel.key, entry = entry }
end
C.StartAutoTimer = function() end
C.Update = function() end
C.Selected = function() end
C.RenderMessages = function()
	rendered = rendered + 1
end

-- A chat event: text, sender, then the rest up to the line id (11th argument).
local function Event(event, text, sender, lineID)
	C.OnChatMessage(event, text, sender, "", "", "", "", 0, 0, "", 0, lineID, SECRET, SECRET)
end

local function Messages(key)
	return C.store:Get(key).messages
end

-- Whispers from players the notes marked get a warning line under them (#45).
ns.BlockedWhisperWarning = function(sender)
	return sender:match("^Ann") and "Careful, Ann is marked: guild <X>" or nil
end

-- During the lockdown: a party line becomes a placeholder, a whisper can't be placed yet.
Event("CHAT_MSG_PARTY", SECRET, SECRET, 11)
lines[11] = { text = "need heal", sender = "Bob-Realm" }
Event("CHAT_MSG_PARTY", SECRET, SECRET, 12) -- the client can't read this one back
Event("CHAT_MSG_WHISPER", SECRET, SECRET, 13)
lines[13] = { text = "psst", sender = "Ann-Other" }
Event("CHAT_MSG_BN_WHISPER", SECRET, SECRET, 15) -- its account id stays secret: not kept
lines[15] = { text = "lost", sender = "Cid" }
check(#Messages("party") == 2 and Messages("party")[1].pending == 11, "placeholder in the party channel")
check(Messages("party")[1].text:find("readable after the fight", 1, true), "placeholder says when")
check(#Messages("main") == 2 and Messages("main")[1].pending == 11, "placeholder mirrored in Main")
check(C.store:Get("party").unread == 2, "placeholders count as unread")
check(C.store:Get("whisper:Ann-Other") == nil, "whisper partner unknown during the lockdown")
check(
	#previews == 2 and previews[1].key == "main" and previews[1].entry.pending == 11,
	"placeholders preview from Main"
)

C.ReadPending()
check(Messages("party")[1].pending == 11 and rendered == 0, "nothing read while still locked down")

-- The lockdown ends.
lockdown = false
_G.time = function()
	return 500
end
C.ReadPending()
local filled = Messages("party")[1]
check(filled.text == "need heal" and filled.sender == "Bob" and filled.player == "Bob-Realm", "party line filled")
check(filled.time == 100 and not filled.pending, "keeps the time it arrived")
check(Messages("main")[1].text == "need heal" and Messages("main")[1].sourceKey == "party", "Main copy filled")
check(Messages("party")[2].text == "(could not be read)", "unreadable line says so")
check(C.store:Get("party").unread == 2, "filling doesn't count unread again")
local whisper = C.store:Get("whisper:Ann-Other")
check(whisper and whisper.messages[1].text == "psst", "whisper arrives after the lockdown")
check(whisper.messages[1].time == 100, "with the time it was sent")
check(whisper.messages[2].text:find("Ann is marked", 1, true) and whisper.messages[2].time == 100, "warned after")
check(whisper.unread == 2, "unread, with the warning")
check(rendered == 1, "the open channel is drawn again")
check(#C.store:Sorted({}) == 4, "no channel for the Battle.net whisper") -- main, party, guild, Ann

C.ReadPending()
check(rendered == 1, "nothing left to read")

-- Readable lines (outside the lockdown) are stored right away.
Event("CHAT_MSG_PARTY", "hi", "Bob-Realm", 14)
check(Messages("party")[3].text == "hi", "readable line stored as it comes")
-- A character whisper: no Battle.net account id.
local function Whisper(text, sender, lineID)
	C.OnChatMessage("CHAT_MSG_WHISPER", text, sender, "", "", "", "", 0, 0, "", 0, lineID, 0, "")
end
Whisper("hello", "Ann-Other", 16)
local annLines = C.store:Get("whisper:Ann-Other").messages
check(annLines[3].text == "hello" and annLines[4].text:find("marked", 1, true), "readable whisper warned right away")
Whisper("yo", "Bob-Realm", 17)
check(#C.store:Get("whisper:Bob-Realm").messages == 1, "unmarked whisperer: no warning")

-- Like Blizzard's chat: a line hidden in the cinematic letterbox (16th
-- argument) isn't stored; a Discord user in guild chat (18th) has no
-- clickable character name.
local function Guild(text, sender, lineID, hideSender, discordInfo)
	C.OnChatMessage(
		"CHAT_MSG_GUILD",
		text,
		sender,
		"",
		"",
		"",
		"",
		0,
		0,
		"",
		0,
		lineID,
		0,
		"",
		nil,
		nil,
		hideSender,
		nil,
		discordInfo
	)
end
Guild("from a cutscene", "Bob-Realm", 18, true)
check(C.store:Get("guild") == nil or #C.store:Get("guild").messages == 0, "letterbox line not stored")
Guild("hi from discord", "Dee", 19, false, { userID = 77 })
local guildLines = C.store:Get("guild").messages
check(
	guildLines[#guildLines].text == "hi from discord" and not guildLines[#guildLines].player,
	"Discord user not linked"
)
Guild("hi from game", "Bob-Realm", 20, false, { userID = 0 })
check(guildLines[#guildLines].player == "Bob-Realm", "character in guild chat linked")
check(not C.IsFromDiscord(nil) and not C.IsFromDiscord({ userID = SECRET }), "no or secret Discord info")
print("letterbox and Discord ok")

print("chat lockdown tests passed")
