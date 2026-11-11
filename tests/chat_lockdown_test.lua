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

local party = { kind = "group", key = "party", chatType = "PARTY" }
local ns = {
	T = function(en)
		return en
	end,
	config = {
		chat = {
			main = { enabled = true, key = "main", kind = "main", kinds = { group = true, whisper = true } },
			events = {
				CHAT_MSG_PARTY = party,
				CHAT_MSG_WHISPER = { kind = "whisper", chatType = "WHISPER" },
			},
			publicChannels = {},
			autoShowDuration = 10,
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
C.IsMerged = function(kind)
	return config.main.kinds[kind] == true
end
C.Attended = function()
	return false
end
C.Label = function(channel)
	return channel.label or channel.key
end
C.ShowEntry = function() end
C.ShowChannel = function() end
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

-- During the lockdown: a party line becomes a placeholder, a whisper can't be placed yet.
Event("CHAT_MSG_PARTY", SECRET, SECRET, 11)
lines[11] = { text = "need heal", sender = "Bob-Realm" }
Event("CHAT_MSG_PARTY", SECRET, SECRET, 12) -- the client can't read this one back
Event("CHAT_MSG_WHISPER", SECRET, SECRET, 13)
lines[13] = { text = "psst", sender = "Ann-Other" }
check(#Messages("party") == 2 and Messages("party")[1].pending == 11, "placeholder in the party channel")
check(Messages("party")[1].text:find("readable after the fight", 1, true), "placeholder says when")
check(#Messages("main") == 2 and Messages("main")[1].pending == 11, "placeholder mirrored in Main")
check(C.store:Get("party").unread == 2, "placeholders count as unread")
check(C.store:Get("whisper:Ann-Other") == nil, "whisper partner unknown during the lockdown")

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
check(whisper.messages[1].time == 100 and whisper.unread == 1, "with the time it was sent, unread")
check(rendered == 1, "the open channel is drawn again")

C.ReadPending()
check(rendered == 1, "nothing left to read")

-- Readable lines (outside the lockdown) are stored right away.
Event("CHAT_MSG_PARTY", "hi", "Bob-Realm", 14)
check(Messages("party")[3].text == "hi", "readable line stored as it comes")
print("chat lockdown tests passed")
