local _, ns = ...

-- Shared state and helpers of the chat files (Blizzard.lua, View.lua,
-- Copy.lua, Badge.lua, Chat.lua). Private to the chat module.

local config = ns.config.chat

local C = {
	-- The channel view is hidden (alpha, see Blizzard.lua) unless one of these holds.
	hidden = false,
	state = {
		manual = false,
		typing = false,
		autoTimer = nil,
		selected = nil, -- key of the open channel
	},
	store = nil,
	ui = {}, -- frame, sidebar, header, messages, input, rows, copy
	german = ns.isGerman,
}
ns.ChatInternal = C

function C.ChatWidth()
	return Clamp(math.floor(UIParent:GetWidth() * config.widthFraction), 250, 800)
end

function C.TypeColor(chatType)
	local info = chatType and ChatTypeInfo[chatType]
	if info and info.r then
		return info.r, info.g, info.b
	end
	return 1, 1, 1
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

-- Opening the chat by hand (toggle key, typing, clicking) counts as reading;
-- the brief auto-show of an incoming message doesn't.
function C.Attended()
	return C.state.manual or C.state.typing
end
