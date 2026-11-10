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
	},
	store = nil,
	ui = {}, -- frame, sidebar, header, messages, input, rows, copy
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
-- is missing on system messages. Channel and sender take their channel's color;
-- emotes ("time Bob waves.") are colored as a whole in the emote color.
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
	if entry.emote then
		local body = entry.sender and (Sender(entry, entry.sender) .. " " .. entry.text) or entry.text
		return stamp .. " " .. C.ColorCode(color("EMOTE")) .. body .. "|r"
	end
	local source = entry.source and (C.ColorCode(color(entry.sourceType or channel.chatType)) .. entry.source .. "|r")
	if source and entry.sourceKey then
		source = History.ChannelLink(entry.sourceKey, source)
	end
	local sender = entry.sender and Sender(entry, C.ColorCode(color(channel.chatType)) .. entry.sender .. "|r")
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
	say = { "Say", "Sagen" },
	yell = { "Yell", "Schreien" },
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

-- Whether channel `kind` shows in Main as well.
function C.IsMerged(kind)
	return config.main.enabled and config.main.kinds[kind] == true
end

function C.IsMain(key)
	return config.main.enabled and key == config.main.key
end

function C.Unread(channel)
	if C.IsMain(channel.key) then
		return C.store:MergedUnread(config.main.kinds)
	end
	return channel.unread
end

function C.MarkRead(key)
	if C.IsMain(key) then
		C.store:MarkKindsRead(config.main.kinds)
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

-- Opening the chat by hand (toggle key, typing, clicking) counts as reading;
-- the brief auto-show of an incoming message doesn't.
function C.Attended()
	return C.state.manual or C.state.typing
end
