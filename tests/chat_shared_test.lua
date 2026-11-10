-- Run with: lua tests/chat_shared_test.lua  (from the repo root)
-- Helpers shared by the chat files (Modules/Chat/Shared.lua) and the Edit
-- Mode size of Blizzard's chat (Modules/Chat/Blizzard.lua).
local check, loadAddonFile = dofile("tests/helpers.lua")

-- The game's globals the helpers read.
local globals = {
	date = function(dateFormat, t)
		return dateFormat == "%H:%M" and ("t" .. t) or ("d" .. t)
	end,
}
for name, value in pairs(globals) do
	_G[name] = value
end

local ns = {
	config = { style = {} },
	T = function(english)
		return english
	end,
}
loadAddonFile("Modules/Chat/Config.lua", ns)
loadAddonFile("Modules/Chat/History.lua", ns)
loadAddonFile("Modules/Chat/Shared.lua", ns)
loadAddonFile("Modules/Chat/Blizzard.lua", ns)
local C, History = ns.ChatInternal, ns.ChatHistory
local config = ns.config.chat

-- Colors and labels.
check(C.ColorCode(1, 0.5, 0) == "|cffff7f00", "color code: " .. C.ColorCode(1, 0.5, 0))
check(C.ColorCode(0, 0, 0) == "|cff000000", "black")
check(C.Label({ key = "party", label = "Saved" }) == "Party", "fixed channels are named in the client's language")
check(C.Label({ key = "progress", label = "x" }) == "Loot & Progress", "progress label")
check(C.Label({ key = "whisper:Bob", label = "Bob" }) == "Bob", "other channels keep their saved label")
check(C.Time(5) == "t5" and C.Day(5) == "d5", "time and day")
print("labels ok")

-- Main: unread of its members, reading it, the channel it writes to.
do
	C.store = History.New({}, 10, true)
	local main = config.main
	C.store:Ensure(main.key, main)
	local party = { kind = "group", chatType = "PARTY", label = "Party" }
	local guild = { kind = "guild", chatType = "GUILD", label = "Guild" }
	local say = { kind = "public", chatType = "SAY", label = "Say" }
	C.store:Add("party", party, { time = 1, text = "a" }, true)
	C.store:Add(main.key, main, History.Mirror({ time = 1, text = "a" }, "party", "Party", "PARTY"), false)
	C.store:Add("guild", guild, { time = 2, text = "b" }, true)
	C.store:Add(main.key, main, History.Mirror({ time = 2, text = "b" }, "guild", "Guild", "GUILD"), false)
	C.store:Add("say", say, { time = 3, text = "c" }, true)

	check(C.IsMain("main") and not C.IsMain("party"), "is main")
	check(C.IsMerged("group") and not C.IsMerged("public"), "merged kinds")
	check(C.Unread(C.store:Get("main")) == 2, "Main counts the unread of its members")
	check(C.Unread(C.store:Get("say")) == 1, "other channels count their own")

	check(C.MainTarget().key == "guild", "Main writes to its latest line's channel")
	C.state.mainTarget = "party"
	check(C.MainTarget().key == "party", "a picked channel wins")
	C.store:Get("party").readOnly = true
	check(C.MainTarget().key == "guild", "a read-only pick falls back to the latest line")
	C.state.mainTarget = "gone"
	check(C.MainTarget().key == "guild", "a deleted pick falls back to the latest line")
	C.state.mainTarget = nil
	C.store:Get("party").readOnly = nil

	C.MarkRead("main")
	check(C.Unread(C.store:Get("main")) == 0, "reading Main reads its members")
	check(C.store:Get("party").unread == 0 and C.store:Get("guild").unread == 0, "members are read")
	check(C.store:Get("say").unread == 1, "other channels stay unread")
	C.MarkRead("say")
	check(C.store:Get("say").unread == 0, "mark read")
end
print("main ok")

-- Message lines in the channel view.
do
	local function color(chatType)
		local colors = { PARTY = { 1, 0, 0 }, GUILD = { 0, 1, 0 }, EMOTE = { 0, 0, 1 }, LOOT = { 1, 1, 0 } }
		local c = colors[chatType] or { 1, 1, 1 }
		return c[1], c[2], c[3]
	end
	local party = { kind = "group", chatType = "PARTY" }
	local grey = C.GREY

	local line, r, g, b = C.FormatEntry(party, { time = 5, sender = "Bob", text = "hi" }, color)
	check(
		line == grey .. "t5|r |cffff0000Bob|r: hi" and r == nil and g == nil and b == nil,
		"line with sender: " .. line
	)

	line = C.FormatEntry(party, { sender = "Bob", text = "hi" }, color)
	check(line == grey .. "--:--|r |cffff0000Bob|r: hi", "untimed line")

	line = C.FormatEntry(party, { time = 5, sender = "Bob", player = "Bob-Thrall", text = "hi" }, color)
	check(line == grey .. "t5|r |Hplayer:Bob-Thrall|h|cffff0000Bob|r|h: hi", "clickable sender: " .. line)

	line, r, g, b = C.FormatEntry({ kind = "progress" }, { time = 5, text = "Loot.", colorType = "LOOT" }, color)
	check(line == grey .. "t5|r Loot." and r == 1 and g == 1 and b == 0, "finished line takes its kind's color")

	line, r, g, b = C.FormatEntry({ kind = "system" }, { time = 5, text = "Old." }, color)
	check(line == grey .. "t5|r Old." and r == 1 and g == 1 and b == 1, "old system lines count as SYSTEM")

	line = C.FormatEntry(party, { time = 5, sender = "Bob", text = "waves.", emote = true }, color)
	check(line == grey .. "t5|r |cff0000ffBob waves.|r", "emote: " .. line)
	line = C.FormatEntry(party, { time = 5, text = "Bob dances.", emote = true }, color)
	check(line == grey .. "t5|r |cff0000ffBob dances.|r", "text emote")

	line = C.FormatEntry({ kind = "other", chatType = "CHANNEL" }, {
		time = 5,
		sender = "Bob",
		text = "lfg",
		source = "LFG",
		sourceType = "GUILD",
	}, color)
	check(line == grey .. "t5|r [|cff00ff00LFG|r] |cffffffffBob|r: lfg", "line in Other: " .. line)

	line = C.FormatEntry({ kind = "main", chatType = "SAY" }, {
		time = 5,
		sender = "Bob",
		text = "hi",
		source = "Party",
		sourceType = "PARTY",
		sourceKey = "party",
	}, color)
	check(
		line == grey .. "t5|r [|Haddon:stevioui:channel:party|h|cffff0000Party|r|h] |cffffffffBob|r: hi",
		"line in Main links its channel: " .. line
	)
end
print("lines ok")

-- Edit Mode size of Blizzard's chat.
do
	local Setting = { WidthHundreds = 1, WidthTensAndOnes = 2, HeightHundreds = 3, HeightTensAndOnes = 4 }
	local size = C.SizeSettings(Setting, 640, 300)
	check(size[1] == 6 and size[2] == 40 and size[3] == 3 and size[4] == 0, "size split into hundreds and the rest")
	size = C.SizeSettings(Setting, 99, 800)
	check(size[1] == 0 and size[2] == 99 and size[3] == 8 and size[4] == 0, "small width")
end
print("size ok")

print("chat shared tests passed")
