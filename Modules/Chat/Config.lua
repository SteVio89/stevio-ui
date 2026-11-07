local _, ns = ...

-- Channel definitions shared by several events; `With` copies one and adds fields.
local function With(base, fields)
	local def = {}
	for key, value in pairs(base) do
		def[key] = value
	end
	for key, value in pairs(fields or {}) do
		def[key] = value
	end
	return def
end

local guild = { kind = "guild", key = "guild", chatType = "GUILD", label = "Guild" }
local say = { kind = "public", key = "say", chatType = "SAY", label = "Say", quiet = true }

-- Read-only channels of finished lines without a sender; `format` names how a
-- line is worded (see Format.lua).
local system = {
	kind = "system",
	key = "system",
	chatType = "SYSTEM",
	label = "System",
	readOnly = true,
	quiet = true,
	format = "plain",
}
local npc = {
	kind = "npc",
	key = "npc",
	chatType = "MONSTER_SAY",
	label = "NPC",
	readOnly = true,
	quiet = true,
	format = "get",
}
local progress = {
	kind = "progress",
	key = "progress",
	chatType = "LOOT",
	label = "Loot & Progress",
	readOnly = true,
	quiet = true,
	format = "plain",
}

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

	-- Debugging aid: keeps Blizzard's chat visible right of the channel view
	-- (gap in pixels) to compare which messages arrive.
	showBlizzardChat = false,
	blizzardChatGap = 8,
	-- Gap (pixels) between the channel view and Blizzard's input box below it.
	editBoxGap = 2,
	-- Blizzard's chat toasts (Battle.net friend online, ...) appear under the
	-- input box: gap in pixels, and the height they are bottom-aligned in
	-- (the Battle.net toast is 50 or 63 high).
	alertGap = 4,
	alertHeight = 63,

	autoShowDuration = 8,

	-- Messages kept per channel; also what survives a /reload or relog.
	historyLimit = 200,
	sidebarWidth = 104,
	rowHeight = 18,
	-- Font size of the messages, the input line and the copy view
	-- (sidebar and header keep ns.config.style.fontSize).
	fontSize = 14,
	-- Date line shown before the first message of each day (os.date format);
	-- the history survives relogs, so the time alone isn't enough.
	dateFormat = "%a %d.%m.%Y",
	-- Lines scrolled per mouse wheel notch.
	scrollStep = 3,

	-- Sidebar order of the channel kinds.
	kindOrder = {
		group = 1,
		guild = 2,
		community = 3,
		whisper = 4,
		public = 5,
		other = 6,
		npc = 7,
		progress = 8,
		system = 9,
	},

	-- Numbered chat channels (base name, case-insensitive) that get their own
	-- sidebar channel; messages from all other channels end up in "Other".
	-- Community streams added to the chat always get their own channel.
	publicChannels = { "General", "Trade", "Allgemein", "Handel" },

	-- Chat events that feed the channels. Group channels (party, raid, instance)
	-- are one channel each, whispers get one channel per partner.
	-- Each message also briefly shows the hidden chat and lights its badge segment,
	-- except `quiet` ones (say, yell, chat channels, NPC, loot, system): they only
	-- count as unread. Events not listed here (other players joining or leaving
	-- channels, channel member lists, pet battle combat log, voice-to-text) are ignored.
	events = {
		CHAT_MSG_PARTY = { kind = "group", key = "party", chatType = "PARTY", label = "Party" },
		CHAT_MSG_PARTY_LEADER = { kind = "group", key = "party", chatType = "PARTY", label = "Party" },
		CHAT_MSG_RAID = { kind = "group", key = "raid", chatType = "RAID", label = "Raid" },
		CHAT_MSG_RAID_LEADER = { kind = "group", key = "raid", chatType = "RAID", label = "Raid" },
		CHAT_MSG_RAID_WARNING = { kind = "group", key = "raid", chatType = "RAID", label = "Raid", prefix = "[RW] " },
		CHAT_MSG_INSTANCE_CHAT = { kind = "group", key = "instance", chatType = "INSTANCE_CHAT", label = "Instance" },
		CHAT_MSG_INSTANCE_CHAT_LEADER = { kind = "group", key = "instance", chatType = "INSTANCE_CHAT", label = "Instance" },
		CHAT_MSG_GUILD = guild,
		CHAT_MSG_OFFICER = With(guild, { prefix = "[O] " }),
		CHAT_MSG_GUILD_DISCORD = guild,
		CHAT_MSG_SAY = say,
		CHAT_MSG_YELL = { kind = "public", key = "yell", chatType = "YELL", label = "Yell", quiet = true },
		-- Emotes are local like say, so they share its channel: /e (`emote`) gives the
		-- action without the name, /dance etc. (`textEmote`) the whole sentence.
		CHAT_MSG_EMOTE = With(say, { emote = true }),
		CHAT_MSG_TEXT_EMOTE = With(say, { emote = true, textEmote = true }),
		CHAT_MSG_CHANNEL = { kind = "public", chatType = "CHANNEL", channel = true, quiet = true },
		CHAT_MSG_COMMUNITIES_CHANNEL = { kind = "public", chatType = "CHANNEL", channel = true, quiet = true },
		CHAT_MSG_WHISPER = { kind = "whisper", chatType = "WHISPER" },
		CHAT_MSG_WHISPER_INFORM = { kind = "whisper", chatType = "WHISPER", outgoing = true },
		CHAT_MSG_BN_WHISPER = { kind = "whisper", chatType = "BN_WHISPER", bnet = true },
		CHAT_MSG_BN_WHISPER_INFORM = { kind = "whisper", chatType = "BN_WHISPER", bnet = true, outgoing = true },

		CHAT_MSG_MONSTER_SAY = npc,
		CHAT_MSG_MONSTER_YELL = npc,
		CHAT_MSG_MONSTER_EMOTE = npc,
		CHAT_MSG_MONSTER_WHISPER = npc,
		CHAT_MSG_MONSTER_PARTY = npc,
		CHAT_MSG_RAID_BOSS_EMOTE = npc,
		CHAT_MSG_RAID_BOSS_WHISPER = npc,

		CHAT_MSG_LOOT = progress,
		CHAT_MSG_MONEY = progress,
		CHAT_MSG_CURRENCY = progress,
		CHAT_MSG_COMBAT_XP_GAIN = progress,
		CHAT_MSG_COMBAT_HONOR_GAIN = progress,
		CHAT_MSG_COMBAT_FACTION_CHANGE = progress,
		CHAT_MSG_COMBAT_MISC_INFO = progress,
		CHAT_MSG_SKILL = progress,
		CHAT_MSG_OPENING = progress,
		CHAT_MSG_COLLECTED_APPEARANCE = progress,
		CHAT_MSG_ACHIEVEMENT = With(progress, { format = "name" }),
		CHAT_MSG_GUILD_ACHIEVEMENT = With(progress, { format = "name" }),
		CHAT_MSG_GUILD_ITEM_LOOTED = With(progress, { format = "guildLoot" }),

		-- Players coming online / going offline, /who results and other notices.
		CHAT_MSG_SYSTEM = system,
		CHAT_MSG_AFK = With(system, { format = "get" }),
		CHAT_MSG_DND = With(system, { format = "get" }),
		CHAT_MSG_IGNORED = With(system, { format = "ignored" }),
		CHAT_MSG_FILTERED = With(system, { format = "filtered" }),
		CHAT_MSG_RESTRICTED = With(system, { format = "restricted" }),
		CHAT_MSG_CHANNEL_NOTICE = With(system, { format = "notice" }),
		CHAT_MSG_CHANNEL_NOTICE_USER = With(system, { format = "noticeUser" }),
		CHAT_MSG_TRADESKILLS = system,
		CHAT_MSG_PET_INFO = system,
		CHAT_MSG_PET_BATTLE_INFO = system,
		CHAT_MSG_BG_SYSTEM_HORDE = system,
		CHAT_MSG_BG_SYSTEM_ALLIANCE = system,
		CHAT_MSG_BG_SYSTEM_NEUTRAL = system,
		CHAT_MSG_TARGETICONS = system,
		CHAT_MSG_PING = With(system, { format = "ping" }),
		CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE = system,
		-- Battle.net friends coming online / going offline.
		CHAT_MSG_BN_INLINE_TOAST_ALERT = With(system, {
			format = "toast",
			toast = { FRIEND_ONLINE = true, FRIEND_OFFLINE = true },
		}),
		CHAT_MSG_BN_INLINE_TOAST_BROADCAST = With(system, { format = "broadcast" }),
		CHAT_MSG_BN_INLINE_TOAST_BROADCAST_INFORM = With(system, { format = "broadcastInform" }),
	},

	-- Lines Blizzard writes into its chat window without a chat event; each
	-- names its channel definition (see Chat.lua for the wording).
	notices = {
		levelUp = progress,
		guildMotd = With(guild, { quiet = true }),
		system = system,
	},

	-- Addon output (/sui commands) and the /played reply: Blizzard's chat is
	-- never shown, so they go to "System" and, being an answer to something
	-- just typed, open that channel (`focus`) even while another one is open.
	-- Other addons' print() output only counts as unread (`system` above).
	print = With(system, { quiet = false, focus = true }),

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
