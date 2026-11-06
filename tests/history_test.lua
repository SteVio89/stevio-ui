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
for _, c in ipairs(sorted) do keys[#keys + 1] = c.key end
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
