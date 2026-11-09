local _, ns = ...

-- Shared state and helpers of the chat files (Blizzard.lua, View.lua,
-- Copy.lua, Badge.lua, Format.lua, Notices.lua, Commands.lua, Chat.lua).
-- Private to the chat module. Files may call C.* functions defined in files
-- loaded after them (see stevio-ui.toc), but only at runtime, never while loading.

local config = ns.config.chat
local style = ns.config.style

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

function C.Day(t)
	return date(config.dateFormat, t)
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
