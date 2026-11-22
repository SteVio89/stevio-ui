local _, ns = ...

-- Shared state and helpers of the chat files (Blizzard.lua, View.lua,
-- Copy.lua, Badge.lua, Format.lua, Notices.lua, Commands.lua, Receive.lua,
-- Send.lua, Chat.lua).
-- Private to the chat module. Files may call C.* functions defined in files
-- loaded after them (see stevio-ui.toc), but only at runtime, never while loading.

local config = ns.config.chat
local style = ns.config.style
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
	widget:SetFont(style.font, config.fontSize, style.fontFlags)
end

function C.ChannelColor(channel)
	return C.TypeColor(channel.chatType)
end

function C.ColorCode(r, g, b)
	return ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255)
end

-- Color code of time stamps and date lines.
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

function C.Selected()
	return C.state.selected and C.store:Get(C.state.selected)
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

-- Sidebar scrolling: `offset` is how far the channel list is scrolled down,
-- `viewHeight` how much of it fits. Returns `offset` kept within the list.
function C.ClampSidebarScroll(offset, viewHeight, count, rowHeight)
	return math.max(0, math.min(offset, count * rowHeight - viewHeight))
end

-- The scroll offset that shows row `index` whole, moving as little as possible.
function C.ScrollToRow(offset, viewHeight, index, rowHeight)
	local top = (index - 1) * rowHeight
	if top < offset then
		return top
	end
	local bottom = top + rowHeight
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
