local _, ns = ...

-- Shared state and helpers of the chat files (Blizzard.lua, View.lua,
-- Copy.lua, Badge.lua, Format.lua, Notices.lua, Commands.lua, Receive.lua,
-- Send.lua, Chat.lua).
-- Private to the chat module. Files may call C.* functions defined in files
-- loaded after them (see stevio-ui.toc), but only at runtime, never while loading.

local config = ns.config.chat
local History = ns.ChatHistory

local C = {
	-- The channel view is hidden (alpha, see Blizzard.lua) unless one of these holds.
	hidden = false,
	state = {
		manual = false,
		typing = false,
		autoTimer = nil,
		selected = nil, -- key of the open channel
		-- Channel key Main writes to while it is picked or being typed into
		-- (nil: the channel of Main's latest line).
		mainTarget = nil,
		-- Channel key the chat goes back to when a peek (C.Peek) ends; false
		-- when none was open, nil while not peeking.
		peekReturn = nil,
	},
	store = nil,
	ui = {}, -- frame, sidebar, listScroll, list, thumb, header, messages, input, rows, copy
}
ns.ChatInternal = C

function C.ChatWidth()
	return Clamp(math.floor(UIParent:GetWidth() * config.widthFraction), 250, 800)
end

-- The player's chat color of `chatType`; before those load (or for unknown
-- types) the `fallback` color ({ r, g, b[, a] }), else white.
function C.TypeColor(chatType, fallback)
	local info = chatType and ChatTypeInfo[chatType]
	if info and info.r then
		return info.r, info.g, info.b
	end
	if fallback then
		return unpack(fallback)
	end
	return 1, 1, 1
end

-- The font of the messages, the input line and the copy view.
function C.ApplyFont(widget)
	ns.SetFont(widget, config.fontSize)
end

function C.ChannelColor(channel)
	return C.TypeColor(channel.chatType)
end

function C.ColorCode(r, g, b)
	return ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255)
end

-- Color code of time stamps and date lines; the theme's faint text color once
-- the channel view exists (View.lua).
C.GREY = "|cff808080"

function C.Day(t)
	return date(config.dateFormat, t)
end

-- A message's time of day.
function C.Time(t)
	return date("%H:%M", t)
end

-- The sender's name (`text`, already formatted) as a link that opens a whisper
-- when the message came from another character (see OnHyperlinkClick in View.lua).
local function Sender(entry, text)
	return entry.player and History.PlayerLink(entry.player, text) or text
end

-- A message line of `channel` as shown in the channel view:
-- "time [channel] sender: text"; the channel only shows in "Other" and Main
-- (where a click on it writes to that channel), the sender
-- is missing on system messages. Channel and sender take the color of the
-- channel the line came from, the text stays white;
-- emotes ("time Bob waves.") are colored as a whole in the emote color, yelled
-- lines (`tint`) in the yell color.
-- Returns the line and its base color: finished lines without a sender (loot,
-- NPC, system, ...) take their kind's chat color, like in Blizzard's chat;
-- System lines stored before they carried a kind count as SYSTEM.
-- `color(chatType)` gives a chat type's color (C.TypeColor).
function C.FormatEntry(channel, entry, color)
	local stamp = C.GREY .. (entry.time and C.Time(entry.time) or "--:--") .. "|r"
	local colorType = entry.colorType or (channel.kind == "system" and not entry.sender and "SYSTEM")
	if colorType then
		return History.Line(entry, stamp), color(colorType)
	end
	local source = entry.source and (C.ColorCode(color(entry.sourceType or channel.chatType)) .. entry.source .. "|r")
	if source and entry.sourceKey then
		source = History.ChannelLink(entry.sourceKey, source)
	end
	if entry.emote or entry.tint then
		local body = entry.sender and (Sender(entry, entry.sender) .. (entry.emote and " " or ": ") .. entry.text)
			or entry.text
		local tag = source and (" [" .. source .. "]") or ""
		return stamp .. tag .. " " .. C.ColorCode(color(entry.tint or "EMOTE")) .. body .. "|r"
	end
	-- In Main and "Other" the sender takes the color of the channel the line
	-- came from, so names stand out from the white text there too.
	local senderType = entry.sourceType or channel.chatType
	local sender = entry.sender and Sender(entry, C.ColorCode(color(senderType)) .. entry.sender .. "|r")
	return History.Line(entry, stamp, source, sender)
end

-- Names of the fixed channels, in the client's language; the saved label
-- (English) is kept for whisper partners, chat channels and communities.
local LABELS = {
	main = { "Main", "Haupt" },
	party = { "Party", "Gruppe" },
	raid = { "Raid", "Schlachtzug" },
	instance = { "Instance", "Instanz" },
	guild = { "Guild", "Gilde" },
	nearby = { "Nearby", "In der Nähe" },
	other = { "Other", "Andere" },
	npc = { "NPC", "NPC" },
	progress = { "Loot & Progress", "Beute & Fortschritt" },
	system = { "System", "System" },
	notices = { "Notices", "Meldungen" },
}

function C.Label(channel)
	local names = LABELS[channel.key]
	if names then
		return ns.T(names[1], names[2])
	end
	return channel.label
end

-- The open channel: a stored one, or the view of a sidebar heading's
-- channels (C.GroupChannel).
function C.Selected()
	local key = C.state.selected
	if key and C.IsGroupKey(key) then
		return C.GroupChannel(C.store:Sorted(config.kindOrder), key)
	end
	return key and C.store:Get(key)
end

-- Whether lines of `def` (see config.events) show in Main as well.
function C.IsMerged(def)
	return config.main.enabled and def.merge ~= nil and config.main.channels[def.merge] == true
end

function C.IsMain(key)
	return config.main.enabled and key == config.main.key
end

function C.Unread(channel)
	if C.IsMain(channel.key) then
		return C.store:MergedUnread()
	end
	return channel.unread
end

function C.MarkRead(key)
	if C.IsMain(key) then
		C.store:MarkMergedRead()
	elseif C.IsGroupKey(key) then
		local group = C.GroupChannel(C.store:Sorted(config.kindOrder), key)
		for _, channel in ipairs(group and group.members or {}) do
			C.store:MarkRead(channel.key)
		end
	else
		C.store:MarkRead(key)
	end
end

-- The channel Main writes to: the picked one, else that of Main's latest line.
function C.MainTarget()
	local picked = C.state.mainTarget and C.store:Get(C.state.mainTarget)
	if picked and not picked.readOnly then
		return picked
	end
	return C.store:ReplyChannel(config.main.key)
end

-- The placeholder of the empty input line: where Enter sends what is typed
-- there, so the line reads as an input and not as part of the history.
-- Returns the text and the channel written to (nil when only slash commands
-- work, e.g. in System or a Main without a line to answer).
function C.InputHint(channel)
	if not channel then
		return ""
	end
	local target = channel
	if C.IsMain(channel.key) then
		target = C.MainTarget()
	end
	if not target or target.readOnly then
		return ns.T("Only /commands here", "Hier nur /Befehle")
	end
	return ns.T("Write to %s ...", "An %s schreiben ..."):format(C.Label(target)), target
end

-- Opening the chat by hand (toggle key, typing, clicking) counts as reading;
-- the brief auto-show of an incoming message doesn't.
function C.Attended()
	return C.state.manual or C.state.typing
end

-- The opacity of the chat's background: nearly solid while it is read
-- closely (`active`: the cursor over it, typing, the copy view), see-through
-- otherwise (#69).
function C.BackgroundAlpha(active)
	return active and config.activeAlpha or config.openAlpha
end

-- `current` moved towards `target` by at most `step`.
function C.Approach(current, target, step)
	if current < target then
		return math.min(current + step, target)
	end
	return math.max(current - step, target)
end

-- The opacity of a preview line `age` seconds old: full for `hold` seconds,
-- then fading out over `fadeOut`; 0 once it is gone.
function C.PreviewAlpha(age, hold, fadeOut)
	if age < hold then
		return 1
	end
	if fadeOut <= 0 then
		return 0
	end
	return math.max(0, 1 - (age - hold) / fadeOut)
end

-- Adds `item` to the preview lines `items` (oldest first), dropping the
-- oldest beyond `maxRows`.
function C.PushPreview(items, item, maxRows)
	items[#items + 1] = item
	while #items > math.max(maxRows, 0) do
		table.remove(items, 1)
	end
	return items
end

-- How many of the preview lines with heights `heights` (oldest first) to
-- drop from the front so the rest fit into `available`. The newest line is
-- always kept, even when it alone is taller.
function C.PreviewOverflow(heights, available)
	local total = 0
	for index = #heights, 1, -1 do
		total = total + heights[index]
		if total > available and index < #heights then
			return index
		end
	end
	return 0
end

-- The sidebar's sections ----------------------------------------------------

-- Chat channels (grouped by name) and the read-only log channels each come
-- under a heading.
local CHANNEL_KINDS = { public = true, other = true }
local LOG_KINDS = { npc = true, progress = true, system = true, notices = true }

-- "General - Tanaris" -> "General", "Tanaris"; nil for a name without a zone.
function C.SplitChannelLabel(label)
	return label:match("^(.-) %- (.+)$")
end

-- The sidebar's lines for `channels` (in sidebar order): { header = text }
-- or { channel = channel, label = text }. Chat channels of one name (zone
-- channels) come under that name and show only the zone; channels without a
-- zone (Trade, own ones) under "Channels". Groups keep the order in which
-- their first channel came.
function C.SidebarEntries(channels)
	local entries = {}
	local function Add(channel, label)
		entries[#entries + 1] = { channel = channel, label = label or C.Label(channel) }
	end
	local index, logHeader = 1, false
	while index <= #channels do
		local channel = channels[index]
		if CHANNEL_KINDS[channel.kind] then
			local groups, order = {}, {}
			while channels[index] and CHANNEL_KINDS[channels[index].kind] do
				local current = channels[index]
				local base, zone = C.SplitChannelLabel(C.Label(current))
				local key = base or ""
				if not groups[key] then
					groups[key] = {}
					order[#order + 1] = key
				end
				table.insert(groups[key], { channel = current, label = zone })
				index = index + 1
			end
			for _, key in ipairs(order) do
				entries[#entries + 1] = {
					header = key ~= "" and key or ns.T("Channels", "Kanäle"),
					group = key ~= "" and ("group:name:" .. key:lower()) or "group:channels",
				}
				for _, item in ipairs(groups[key]) do
					Add(item.channel, item.label)
				end
			end
		else
			if LOG_KINDS[channel.kind] and not logHeader then
				entries[#entries + 1] = { header = ns.T("Log", "Protokoll"), group = "group:log" }
				logHeader = true
			end
			Add(channel)
			index = index + 1
		end
	end
	return entries
end

-- A click on a heading opens all channels under it as one (#78): the lines
-- of each, merged in the order they came, named by their row's label like
-- the lines in Main. Such a view is keyed by its heading's `group`.
function C.IsGroupKey(key)
	return key ~= nil and key:sub(1, 6) == "group:"
end

-- The lines of the channels `members`, oldest first, each a copy naming its
-- channel (`labels[key]`, see History.Mirror); lines of the same time keep
-- the members' order.
function C.GroupMessages(members, labels)
	local lines = {}
	for _, channel in ipairs(members) do
		for _, entry in ipairs(channel.messages) do
			lines[#lines + 1] = {
				entry = History.Mirror(entry, channel.key, labels[channel.key], channel.chatType),
				order = #lines,
			}
		end
	end
	table.sort(lines, function(a, b)
		local ta, tb = a.entry.time or 0, b.entry.time or 0
		if ta ~= tb then
			return ta < tb
		end
		return a.order < b.order
	end)
	local messages = {}
	for i, line in ipairs(lines) do
		messages[i] = line.entry
	end
	return messages
end

-- Its lines are only merged when they are read.
local GroupView = {
	__index = function(group, field)
		if field == "messages" then
			local messages = C.GroupMessages(group.members, group.labels)
			rawset(group, "messages", messages)
			return messages
		end
	end,
}

-- The view of the heading keyed `key` among `channels` (in sidebar order):
-- a read-only channel of the rows under that heading (`members`, with their
-- row labels in `labels` by key) whose unread count is theirs together.
-- nil when there is no such heading (any more).
function C.GroupChannel(channels, key)
	local group
	for _, entry in ipairs(C.SidebarEntries(channels)) do
		if entry.header then
			if group then
				break
			end
			if entry.group == key then
				group = { key = key, kind = "group", label = entry.header, readOnly = true, unread = 0, last = 0 }
				group.members, group.labels = {}, {}
			end
		elseif group then
			local channel = entry.channel
			group.members[#group.members + 1] = channel
			group.labels[channel.key] = entry.label
			group.unread = group.unread + C.Unread(channel)
			group.last = math.max(group.last, channel.last or 0)
		end
	end
	return group and setmetatable(group, GroupView)
end

-- Each entry's top (from the list's top) and the list's height: headings
-- are `headerHeight`, channels `rowHeight` high.
function C.SidebarLayout(entries, rowHeight, headerHeight)
	local tops, y = {}, 0
	for index, entry in ipairs(entries) do
		tops[index] = y
		y = y + (entry.header and headerHeight or rowHeight)
	end
	return tops, y
end

-- Sidebar scrolling: `offset` is how far the channel list is scrolled down,
-- `viewHeight` how much of the list (`listHeight` high) fits. Returns
-- `offset` kept within the list.
function C.ClampSidebarScroll(offset, viewHeight, listHeight)
	return math.max(0, math.min(offset, listHeight - viewHeight))
end

-- The scroll offset that shows the row at `top` (`height` high) whole,
-- moving as little as possible.
function C.ScrollToRow(offset, viewHeight, top, height)
	if top < offset then
		return top
	end
	local bottom = top + height
	if bottom > offset + viewHeight then
		return bottom - viewHeight
	end
	return offset
end

-- Group tags and raid icons, as Blizzard's chat handles them ---------------

-- Before sending: localized group tags ({Heiler}) become language-independent
-- ones, so readers on other client languages get them too
-- (ChatFrameUtil.SubstituteChatMessageBeforeSend, as Blizzard's input box does).
function C.SubstituteTags(text)
	return ChatFrameUtil.SubstituteChatMessageBeforeSend(text)
end

-- On receiving: {star}, {rt1}, ... become raid icons, and group tags expand
-- where Blizzard's chat expands them (raids). `noIconReplacement` is the
-- event's 17th argument (true where icons aren't allowed, e.g. public channels).
function C.ExpandExpressions(text, chatType, noIconReplacement)
	local canExpand = ChatFrameUtil.CanChatGroupPerformExpressionExpansion(ChatFrameUtil.GetChatCategory(chatType))
	return C_ChatInfo.ReplaceIconAndGroupExpressions(text, noIconReplacement, not canExpand)
end
