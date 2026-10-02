local _, ns = ...

ns.config.chat = {
	enabled = true,

	-- Written into the Edit Mode layout (Blizzard limits: width 250-800, height 120-800).
	-- Width is a share of the screen so it adapts to resolution and UI scale.
	widthFraction = 1 / 3,
	height = 200,

	backgroundColor = { 0, 0, 0, 1 },

	autoShowDuration = 8,

	-- Messages that briefly show the hidden chat and light up their badge segment.
	autoShowEvents = {
		CHAT_MSG_WHISPER = "whisper",
		CHAT_MSG_BN_WHISPER = "whisper",
		CHAT_MSG_PARTY = "group",
		CHAT_MSG_PARTY_LEADER = "group",
		CHAT_MSG_RAID = "group",
		CHAT_MSG_RAID_LEADER = "group",
		CHAT_MSG_RAID_WARNING = "group",
		CHAT_MSG_INSTANCE_CHAT = "group",
		CHAT_MSG_INSTANCE_CHAT_LEADER = "group",
		CHAT_MSG_GUILD = "guild",
		CHAT_MSG_OFFICER = "guild",
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
