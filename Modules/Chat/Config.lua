local _, ns = ...

ns.config.chat = {
	enabled = true,

	-- Written into the Edit Mode layout (Blizzard limits: width 250-800, height 120-800).
	-- Width is a share of the screen so it adapts to resolution and UI scale.
	widthFraction = 1 / 3,
	height = 200,

	backgroundColor = { 0, 0, 0, 1 },
	selectedColor = { 1, 1, 1, 0.12 },
	dividerColor = { 0.3, 0.3, 0.3, 1 },
	deleteColor = { 0.8, 0.3, 0.3, 1 },

	-- Temporary while the channel chat is being built: keeps Blizzard's chat
	-- visible right of it (gap in pixels) to compare which messages arrive.
	showBlizzardChat = true,
	blizzardChatGap = 8,

	autoShowDuration = 8,

	-- Messages kept per channel; also what survives a /reload or relog.
	historyLimit = 200,
	sidebarWidth = 104,
	rowHeight = 18,
	-- Font size of the messages, the input line and the copy view
	-- (sidebar and header keep ns.config.style.fontSize).
	fontSize = 14,
	-- Lines scrolled per mouse wheel notch.
	scrollStep = 3,

	-- Sidebar order of the channel kinds.
	kindOrder = { group = 1, guild = 2, whisper = 3, public = 4, other = 5, system = 6 },

	-- Numbered chat channels (base name, case-insensitive) that get their own
	-- sidebar channel; messages from all other channels end up in "Other".
	publicChannels = { "General", "Trade", "Allgemein", "Handel" },

	-- Chat events that feed the channels. Group channels (party, raid, instance)
	-- are one channel each, whispers get one channel per partner.
	-- Each message also briefly shows the hidden chat and lights its badge segment,
	-- except `quiet` ones (say, yell, chat channels, system): they only count as unread.
	-- `system` messages (players coming online / going offline, ...) have no
	-- sender and go to the read-only "System" channel.
	events = {
		CHAT_MSG_PARTY = { kind = "group", key = "party", chatType = "PARTY", label = "Party" },
		CHAT_MSG_PARTY_LEADER = { kind = "group", key = "party", chatType = "PARTY", label = "Party" },
		CHAT_MSG_RAID = { kind = "group", key = "raid", chatType = "RAID", label = "Raid" },
		CHAT_MSG_RAID_LEADER = { kind = "group", key = "raid", chatType = "RAID", label = "Raid" },
		CHAT_MSG_RAID_WARNING = { kind = "group", key = "raid", chatType = "RAID", label = "Raid", prefix = "[RW] " },
		CHAT_MSG_INSTANCE_CHAT = { kind = "group", key = "instance", chatType = "INSTANCE_CHAT", label = "Instance" },
		CHAT_MSG_INSTANCE_CHAT_LEADER = { kind = "group", key = "instance", chatType = "INSTANCE_CHAT", label = "Instance" },
		CHAT_MSG_GUILD = { kind = "guild", key = "guild", chatType = "GUILD", label = "Guild" },
		CHAT_MSG_OFFICER = { kind = "guild", key = "guild", chatType = "GUILD", label = "Guild", prefix = "[O] " },
		CHAT_MSG_SAY = { kind = "public", key = "say", chatType = "SAY", label = "Say", quiet = true },
		CHAT_MSG_YELL = { kind = "public", key = "yell", chatType = "YELL", label = "Yell", quiet = true },
		CHAT_MSG_CHANNEL = { kind = "public", chatType = "CHANNEL", channel = true, quiet = true },
		CHAT_MSG_WHISPER = { kind = "whisper", chatType = "WHISPER" },
		CHAT_MSG_WHISPER_INFORM = { kind = "whisper", chatType = "WHISPER", outgoing = true },
		CHAT_MSG_BN_WHISPER = { kind = "whisper", chatType = "BN_WHISPER", bnet = true },
		CHAT_MSG_BN_WHISPER_INFORM = { kind = "whisper", chatType = "BN_WHISPER", bnet = true, outgoing = true },
		CHAT_MSG_SYSTEM = {
			kind = "system",
			key = "system",
			chatType = "SYSTEM",
			label = "System",
			system = true,
			readOnly = true,
			quiet = true,
		},
		-- Battle.net friends coming online / going offline.
		CHAT_MSG_BN_INLINE_TOAST_ALERT = {
			kind = "system",
			key = "system",
			chatType = "SYSTEM",
			label = "System",
			system = true,
			toast = { FRIEND_ONLINE = true, FRIEND_OFFLINE = true },
			readOnly = true,
			quiet = true,
		},
	},

	-- Size and base colors come from ns.config.style.badge.
	badge = {
		segmentGap = 2,
		-- Top to bottom. Colors follow the player's chat colors; fallbacks apply before those load.
		segments = {
			{ category = "whisper", chatType = "WHISPER", fallbackColor = { 1, 0.5, 1, 1 } },
			{ category = "group", chatType = "PARTY", fallbackColor = { 0.67, 0.67, 1, 1 } },
			{ category = "guild", chatType = "GUILD", fallbackColor = { 0.25, 1, 0.25, 1 } },
		},
	},
}
