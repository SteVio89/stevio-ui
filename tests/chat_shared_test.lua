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

-- The background's opacity (#69) and the preview lines.
check(C.BackgroundAlpha(true) == config.activeAlpha, "read closely: nearly solid")
check(C.BackgroundAlpha(false) == config.openAlpha, "otherwise see-through")
check(config.openAlpha < config.activeAlpha, "solid while read")
check(C.Approach(0.2, 0.85, 0.1) == 0.2 + 0.1, "fades up by a step")
check(C.Approach(0.8, 0.85, 0.1) == 0.85, "stops at the target")
check(C.Approach(0.85, 0.2, 0.1) == 0.85 - 0.1 and C.Approach(0.25, 0.2, 0.1) == 0.2, "fades down")
check(C.PreviewAlpha(0, 6, 2) == 1 and C.PreviewAlpha(5.9, 6, 2) == 1, "preview line held")
check(C.PreviewAlpha(7, 6, 2) == 0.5, "then fades out")
check(C.PreviewAlpha(8, 6, 2) == 0 and C.PreviewAlpha(20, 6, 2) == 0, "and is gone")
check(C.PreviewAlpha(6, 6, 0) == 0, "no fade time: gone at once")
local items = {}
for i = 1, 4 do
	C.PushPreview(items, i, 3)
end
check(#items == 3 and items[1] == 2 and items[3] == 4, "oldest preview line drops out")
check(#C.PushPreview({}, 1, 0) == 0, "no rows: no preview lines")
print("background and preview ok")

-- Main: unread of its members, reading it, the channel it writes to.
do
	C.store = History.New({}, 10, true)
	local main = config.main
	C.store:Ensure(main.key, main)
	local party = { kind = "group", chatType = "PARTY", label = "Party" }
	local guild = { kind = "guild", chatType = "GUILD", label = "Guild" }
	local say = { kind = "public", chatType = "SAY", label = "Say" }
	C.store:Add("party", party, { time = 1, text = "a" }, true, true)
	C.store:Add(main.key, main, History.Mirror({ time = 1, text = "a" }, "party", "Party", "PARTY"), false)
	C.store:Add("guild", guild, { time = 2, text = "b" }, true, true)
	C.store:Add(main.key, main, History.Mirror({ time = 2, text = "b" }, "guild", "Guild", "GUILD"), false)
	C.store:Add("say", say, { time = 3, text = "c" }, true)

	check(C.IsMain("main") and not C.IsMain("party"), "is main")
	check(C.IsMerged({ merge = "party" }) and C.IsMerged({ merge = "emote" }), "merged lines")
	check(not C.IsMerged({ merge = "say" }) and not C.IsMerged({ kind = "public" }), "lines not merged")
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

	-- The input line's placeholder names where it writes to.
	local hint, target = C.InputHint(C.store:Get("say"))
	check(hint == "Write to Say ..." and target.key == "say", "hint names the channel: " .. hint)
	C.store:Ensure("whisper:Bob-Realm", { kind = "whisper", chatType = "WHISPER", label = "Bob" })
	hint = C.InputHint(C.store:Get("whisper:Bob-Realm"))
	check(hint == "Write to Bob ...", "hint names the whisper partner: " .. hint)
	hint, target = C.InputHint(C.store:Get(main.key))
	check(hint == "Write to " .. C.MainTarget().label .. " ..." and target == C.MainTarget(), "Main names its target")
	hint, target = C.InputHint({ key = "system", label = "System", readOnly = true })
	check(hint == "Only /commands here" and target == nil, "read-only channels only take commands")
	check(C.InputHint(nil) == "", "no channel, no hint")
end
print("main ok")

-- Main's switches (#50): every `merge` of the events has one, and by default
-- Main shows group, guild, whispers and emotes but not say and yell.
do
	local channels = config.main.channels
	for event, def in pairs(config.events) do
		check(def.merge == nil or channels[def.merge] ~= nil, "switch for " .. event)
	end
	for _, name in ipairs({ "party", "instance", "raid", "guild", "whisper", "emote" }) do
		check(channels[name] == true, name .. " in Main by default")
	end
	check(channels.say == false and channels.yell == false, "say and yell not in Main by default")
	local nearby = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE" }
	for _, event in ipairs(nearby) do
		check(config.events[event].key == "nearby", event .. " in Nearby")
	end
	check(config.events.CHAT_MSG_YELL.tint == "YELL", "yelled lines take the yell color")
end
print("main switches ok")

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

	-- Nearby (#50): yelled lines take the yell color, emotes in Main name Nearby.
	local nearby = { kind = "nearby", chatType = "SAY" }
	line = C.FormatEntry(nearby, { time = 5, sender = "Bob", text = "Run!", tint = "YELL" }, function(chatType)
		if chatType == "YELL" then
			return 1, 0, 1
		end
		return color(chatType)
	end)
	check(line == grey .. "t5|r |cffff00ffBob: Run!|r", "yelled line: " .. line)
	line = C.FormatEntry({ kind = "main", chatType = "SAY" }, {
		time = 5,
		sender = "Bob",
		text = "waves.",
		emote = true,
		source = "Nearby",
		sourceType = "PARTY",
		sourceKey = "nearby",
	}, color)
	check(
		line == grey .. "t5|r [|Haddon:stevioui:channel:nearby|h|cffff0000Nearby|r|h] |cff0000ffBob waves.|r",
		"emote in Main: " .. line
	)

	line = C.FormatEntry({ kind = "other", chatType = "CHANNEL" }, {
		time = 5,
		sender = "Bob",
		text = "lfg",
		source = "LFG",
		sourceType = "GUILD",
	}, color)
	check(line == grey .. "t5|r [|cff00ff00LFG|r] |cff00ff00Bob|r: lfg", "line in Other: " .. line)

	line = C.FormatEntry({ kind = "main", chatType = "SAY" }, {
		time = 5,
		sender = "Bob",
		text = "hi",
		source = "Party",
		sourceType = "PARTY",
		sourceKey = "party",
	}, color)
	check(
		line == grey .. "t5|r [|Haddon:stevioui:channel:party|h|cffff0000Party|r|h] |cffff0000Bob|r: hi",
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

-- Group tags before sending and raid icons on receiving, through Blizzard's helpers.
do
	_G.ChatFrameUtil = {
		SubstituteChatMessageBeforeSend = function(text)
			return (text:gsub("{Heiler}", "{healer}"))
		end,
		GetChatCategory = function(chatType)
			return chatType == "RAID_LEADER" and "RAID" or chatType
		end,
		CanChatGroupPerformExpressionExpansion = function(group)
			return group == "RAID"
		end,
	}
	check(C.SubstituteTags("{Heiler} bitte") == "{healer} bitte", "localized tag made language-independent")

	local calls = {}
	_G.C_ChatInfo = {
		ReplaceIconAndGroupExpressions = function(text, noIcons, noGroups)
			calls[#calls + 1] = { text = text, noIcons = noIcons, noGroups = noGroups }
			return noIcons and text or (text:gsub("{star}", "|TStar:0|t"))
		end,
	}
	check(C.ExpandExpressions("go {star}", "PARTY", false) == "go |TStar:0|t", "raid icon")
	check(calls[1].noGroups == true, "group tags only expand in raids")
	C.ExpandExpressions("x", "RAID_LEADER", false)
	check(calls[2].noGroups == false, "raid leader lines expand group tags")
	check(C.ExpandExpressions("{star}", "CHANNEL", true) == "{star}", "no icons where the event says so")
	_G.ChatFrameUtil, _G.C_ChatInfo = nil, nil
end
print("tags and icons ok")

-- Sidebar scrolling: 10 rows of 20 in a view 70 high (list 200 high).
do
	check(C.ClampSidebarScroll(-5, 70, 200) == 0, "no scrolling above the first row")
	check(C.ClampSidebarScroll(500, 70, 200) == 130, "no scrolling past the last row")
	check(C.ClampSidebarScroll(40, 70, 200) == 40, "offsets within the list are kept")
	check(C.ClampSidebarScroll(40, 300, 200) == 0, "a list that fits doesn't scroll")
	check(C.ScrollToRow(0, 70, 20, 20) == 0, "a visible row doesn't scroll")
	check(C.ScrollToRow(0, 70, 80, 20) == 30, "a row below scrolls up to the bottom edge")
	check(C.ScrollToRow(100, 70, 20, 20) == 20, "a row above scrolls down to the top edge")
	check(C.ScrollToRow(15, 70, 0, 20) == 0, "a partly hidden row is shown whole")

	-- Headings count with their own height.
	local tops, height = C.SidebarLayout({ { channel = 1 }, { header = "x" }, { channel = 2 } }, 20, 15)
	check(tops[1] == 0 and tops[2] == 20 and tops[3] == 35, "entry tops")
	check(height == 55, "list height")
	check(C.ScrollToRow(0, 50, tops[3], 20) == 5, "a row below a heading scrolls into view")
	print("sidebar scrolling ok")
end

-- Sidebar sections: chat channels grouped by name, the log channels under one heading.
do
	local function Channel(kind, key, label)
		return { kind = kind, key = key, label = label }
	end
	local entries = C.SidebarEntries({
		Channel("main", "main", "Main"),
		Channel("guild", "guild", "Guild"),
		Channel("public", "c1", "General - Tanaris"),
		Channel("public", "c2", "Trade"),
		Channel("public", "c3", "LocalDefense - Tanaris"),
		Channel("public", "c4", "General - Feralas"),
		Channel("other", "c5", "Own"),
		Channel("npc", "npc", "NPC"),
		Channel("system", "system", "System"),
	})
	local lines = {}
	for _, entry in ipairs(entries) do
		lines[#lines + 1] = entry.header and ("# " .. entry.header) or entry.label
	end
	local expected = {
		"Main",
		"Guild",
		"# General",
		"Tanaris",
		"Feralas",
		"# Channels",
		"Trade",
		"Own",
		"# LocalDefense",
		"Tanaris",
		"# Log",
		"NPC",
		"System",
	}
	check(table.concat(lines, "|") == table.concat(expected, "|"), "sidebar sections: " .. table.concat(lines, "|"))
	check(entries[4].channel.key == "c1", "zone rows keep their channel")
	check(#C.SidebarEntries({}) == 0, "no channels, no headings")
	check(C.SplitChannelLabel("Trade") == nil, "no zone")
	local base, zone = C.SplitChannelLabel("General - Stormwind City")
	check(base == "General" and zone == "Stormwind City", "base and zone")
end
print("sidebar ok")

-- A click on a heading opens its channels as one (#78).
do
	local function Channel(kind, key, label, lines, unread)
		local messages = {}
		for i, line in ipairs(lines) do
			messages[i] = { time = line[1], text = line[2] }
		end
		return { kind = kind, key = key, label = label, messages = messages, unread = unread or 0, last = 0 }
	end
	local channels = {
		Channel("guild", "guild", "Guild", { { 1, "guild" } }),
		Channel("public", "c1", "General - Tanaris", { { 2, "t1" }, { 6, "t2" } }, 2),
		Channel("public", "c2", "Trade", { { 3, "trade" } }),
		Channel("public", "c4", "General - Feralas", { { 4, "f1" }, { 6, "f2" } }, 1),
		Channel("npc", "npc", "NPC", { { 5, "npc" } }, 3),
		Channel("system", "system", "System", { { 1, "sys" } }),
	}
	local entries = C.SidebarEntries(channels)
	check(entries[2].group == "group:name:general", "a zone group's key: " .. tostring(entries[3].group))
	check(entries[5].group == "group:channels", "the channels without a zone")
	check(entries[7].group == "group:log", "the log")
	check(C.IsGroupKey("group:log") and not C.IsGroupKey("guild") and not C.IsGroupKey(nil), "group keys")

	local general = C.GroupChannel(channels, "group:name:general")
	check(general.label == "General" and general.readOnly, "named after its heading, read-only")
	check(#general.members == 2 and general.labels.c1 == "Tanaris", "its rows, labelled as in the sidebar")
	check(general.unread == 3, "unread of its rows together: " .. general.unread)
	local lines = {}
	for _, entry in ipairs(general.messages) do
		lines[#lines + 1] = entry.source .. ":" .. entry.text
	end
	check(
		table.concat(lines, " ") == "Tanaris:t1 Feralas:f1 Tanaris:t2 Feralas:f2",
		"merged by time, same times in row order: " .. table.concat(lines, " ")
	)
	check(general.messages[1].sourceKey == "c1", "each line knows its channel")
	check(channels[2].messages[1].source == nil, "the stored lines stay as they are")

	local log = C.GroupChannel(channels, "group:log")
	check(#log.members == 2 and log.messages[1].text == "sys" and log.messages[2].text == "npc", "the log, by time")
	check(C.GroupChannel(channels, "group:name:trade") == nil, "a heading that isn't there")

	-- Reading the view reads its rows.
	local store = History.New({}, 10, false)
	for _, channel in ipairs(channels) do
		store.db.channels[channel.key] = channel
	end
	C.store = store
	C.state.selected = "group:name:general"
	check(C.Selected().label == "General", "the open view")
	C.MarkRead("group:name:general")
	check(channels[2].unread == 0 and channels[4].unread == 0 and channels[5].unread == 3, "reads only its rows")
	C.state.selected, C.store = nil, nil
end
print("heading views ok")

print("chat shared tests passed")
