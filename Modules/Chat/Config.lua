local _, ns = ...

-- Channel definitions shared by several events; `With` copies one and adds
-- fields, so every event has a table of its own the options panel can change.
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

-- Their names come translated from C.Label (Shared.lua), so they carry no label.
-- `merge` names the switch in `main.channels` that shows the line in Main too.
local party = { kind = "group", key = "party", chatType = "PARTY", merge = "party" }
local raid = { kind = "group", key = "raid", chatType = "RAID", merge = "raid" }
local instance = { kind = "group", key = "instance", chatType = "INSTANCE_CHAT", merge = "instance" }
local guild = { kind = "guild", key = "guild", chatType = "GUILD", merge = "guild" }
-- Say, yell and emotes: everything said around the player, in one channel so
-- a role-play scene reads in one place (#50). Yelled lines take the yell
-- color as a whole (`tint`).
local nearby = { kind = "nearby", key = "nearby", chatType = "SAY", quiet = true }

-- Read-only channels of finished lines without a sender; `format` names how a
-- line is worded (see Format.lua).
local system = {
	kind = "system",
	key = "system",
	chatType = "SYSTEM",
	readOnly = true,
	quiet = true,
	format = "plain",
}
-- Notices about other players that pile up (crafting, ...): kept for a look,
-- but `silent`, they never count as unread or open the chat.
local notices = {
	kind = "notices",
	key = "notices",
	chatType = "SYSTEM",
	readOnly = true,
	quiet = true,
	silent = true,
	format = "plain",
}
local npc = {
	kind = "npc",
	key = "npc",
	chatType = "MONSTER_SAY",
	readOnly = true,
	quiet = true,
	format = "get",
}
local progress = {
	kind = "progress",
	key = "progress",
	chatType = "LOOT",
	readOnly = true,
	quiet = true,
	format = "plain",
}

ns.config.chat = {
	enabled = true,

	-- Written into the Edit Mode layout (Blizzard limits: width 250-800, height 120-800).
	-- Width is a share of the screen so it adapts to resolution and UI scale.
	widthFraction = 1 / 3,
	height = 300,

	-- The background (the theme's panel color) is see-through, so the open
	-- chat doesn't sit on the screen like a black block, and turns nearly
	-- solid while the cursor is over the chat or it is typed into (#69); its
	-- opacity then and otherwise, and the seconds it takes from one to the
	-- other. The text has a shadow, so it stays readable either way.
	activeAlpha = 0.85,
	openAlpha = 0.45,
	fadeTime = 0.25,
	-- Lines between the sidebar and the messages and under the header.
	dividerColor = { 1, 1, 1, 0.06 },
	-- Scroll position shown on the sidebar edge when the channels don't all fit.
	scrollThumbColor = { 1, 1, 1, 0.35 },
	-- The ✕ that deletes a channel, shown on hover.
	deleteColor = { 0.79, 0.42, 0.42, 1 },
	-- The frame of the Copy button.
	buttonBorderColor = { 1, 1, 1, 0.08 },
	-- The input line is boxed so it doesn't read as part of the history; while
	-- typing its border takes the color of the channel it writes to.
	inputBackgroundColor = { 1, 1, 1, 0.04 },
	inputBorderColor = { 1, 1, 1, 0.11 },

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

	-- Seconds an answer to /sui shows the hidden chat (see `print`).
	autoShowDuration = 8,

	-- New lines of Main and the other channels that aren't `quiet` don't pop
	-- up the hidden chat (#69): they show for a moment as lines of text where
	-- the chat sits, the newest at the bottom, up to maxRows of them. Each
	-- stays holdTime seconds (longer under the cursor), then fades out in
	-- fadeOutTime; a click opens the chat on its channel. Off, they only
	-- light the badge.
	preview = {
		enabled = true,
		maxRows = 3,
		holdTime = 6,
		fadeOutTime = 1.5,
	},

	-- Messages kept per channel; also what survives a /reload or relog.
	historyLimit = 200,
	sidebarWidth = 130,
	rowHeight = 22,
	-- Section headings in the sidebar (chat channels by name, the log); as
	-- high as a row and centered like it, so all lines are evenly spaced.
	headerHeight = 22,
	-- Font size of the messages, the input line and the copy view.
	fontSize = 16,
	-- Font size of the sidebar and the header above the messages.
	sidebarFontSize = 14,
	-- Date line shown before the first message of each day (os.date format);
	-- the history survives relogs, so the time alone isn't enough.
	dateFormat = "%a %d.%m.%Y",
	-- Lines scrolled per mouse wheel notch.
	scrollStep = 3,

	-- "Main" shows the lines switched on in `channels` together, each tagged with
	-- its channel ("[Party] Bob: ..."), so group and guild chat can be followed
	-- without switching; the channels stay as well. Its unread count is that of
	-- its lines, and reading it reads them in their channels too.
	-- Writing in Main answers in the channel of the latest line, which is kept
	-- while typing; clicking a line's tag writes to that channel instead.
	main = {
		enabled = true,
		key = "main",
		kind = "main",
		chatType = "SAY",
		-- The `merge` names of config.events; emotes, say and yell all come
		-- from the Nearby channel.
		channels = {
			party = true,
			instance = true,
			raid = true,
			guild = true,
			whisper = true,
			emote = true,
			say = false,
			yell = false,
		},
	},

	-- Sidebar order of the channel kinds.
	kindOrder = {
		main = 0,
		group = 1,
		guild = 2,
		community = 3,
		whisper = 4,
		nearby = 5,
		public = 6,
		-- Chat channels shared "Other" before #50; kept until deleted.
		other = 7,
		npc = 8,
		progress = 9,
		system = 10,
		notices = 11,
	},

	-- Every chat channel gets a sidebar channel of its own, by its full name:
	-- zone channels one per zone ("General - Elwynn Forest"). Those named here
	-- (the part before " - ", case-insensitive) are one channel wherever they
	-- are joined, e.g. Trade in every capital.
	-- Community streams added to the chat get their own channel too.
	cityChannels = { "Trade", "GuildRecruitment", "Handel", "Gildenrekrutierung" },

	-- Chat events that feed the channels. Group channels (party, raid, instance)
	-- are one channel each, whispers get one channel per partner.
	-- Each message shows as a preview line while the chat is hidden (see
	-- `preview`) and lights its badge segment, except `quiet` ones (nearby,
	-- chat channels, NPC, loot, system) that aren't shown in Main: they only
	-- count as unread. Events not listed here (other players joining or leaving
	-- channels, channel member lists, pet battle combat log, voice-to-text) are ignored.
	events = {
		CHAT_MSG_PARTY = With(party),
		CHAT_MSG_PARTY_LEADER = With(party),
		CHAT_MSG_RAID = With(raid),
		CHAT_MSG_RAID_LEADER = With(raid),
		CHAT_MSG_RAID_WARNING = With(raid, { prefix = "[RW] " }),
		CHAT_MSG_INSTANCE_CHAT = With(instance),
		CHAT_MSG_INSTANCE_CHAT_LEADER = With(instance),
		CHAT_MSG_GUILD = With(guild),
		CHAT_MSG_OFFICER = With(guild, { prefix = "[O] " }),
		CHAT_MSG_GUILD_DISCORD = With(guild),
		CHAT_MSG_SAY = With(nearby, { merge = "say" }),
		CHAT_MSG_YELL = With(nearby, { merge = "yell", tint = "YELL" }),
		-- /e (`emote`) gives the action without the name, /dance etc.
		-- (`textEmote`) the whole sentence.
		CHAT_MSG_EMOTE = With(nearby, { merge = "emote", emote = true }),
		CHAT_MSG_TEXT_EMOTE = With(nearby, { merge = "emote", emote = true, textEmote = true }),
		CHAT_MSG_CHANNEL = { kind = "public", chatType = "CHANNEL", channel = true, quiet = true },
		CHAT_MSG_COMMUNITIES_CHANNEL = { kind = "public", chatType = "CHANNEL", channel = true, quiet = true },
		CHAT_MSG_WHISPER = { kind = "whisper", chatType = "WHISPER", merge = "whisper" },
		CHAT_MSG_WHISPER_INFORM = { kind = "whisper", chatType = "WHISPER", merge = "whisper", outgoing = true },
		CHAT_MSG_BN_WHISPER = { kind = "whisper", chatType = "BN_WHISPER", merge = "whisper", bnet = true },
		CHAT_MSG_BN_WHISPER_INFORM = {
			kind = "whisper",
			chatType = "BN_WHISPER",
			merge = "whisper",
			bnet = true,
			outgoing = true,
		},

		CHAT_MSG_MONSTER_SAY = With(npc),
		CHAT_MSG_MONSTER_YELL = With(npc),
		CHAT_MSG_MONSTER_EMOTE = With(npc),
		CHAT_MSG_MONSTER_WHISPER = With(npc),
		CHAT_MSG_MONSTER_PARTY = With(npc),
		CHAT_MSG_RAID_BOSS_EMOTE = With(npc),
		CHAT_MSG_RAID_BOSS_WHISPER = With(npc),

		CHAT_MSG_LOOT = With(progress),
		CHAT_MSG_MONEY = With(progress),
		CHAT_MSG_CURRENCY = With(progress),
		CHAT_MSG_COMBAT_XP_GAIN = With(progress),
		CHAT_MSG_COMBAT_HONOR_GAIN = With(progress),
		CHAT_MSG_COMBAT_FACTION_CHANGE = With(progress),
		CHAT_MSG_COMBAT_MISC_INFO = With(progress),
		CHAT_MSG_SKILL = With(progress),
		CHAT_MSG_OPENING = With(progress),
		CHAT_MSG_COLLECTED_APPEARANCE = With(progress),
		CHAT_MSG_ACHIEVEMENT = With(progress, { format = "name" }),
		CHAT_MSG_GUILD_ACHIEVEMENT = With(progress, { format = "name" }),
		CHAT_MSG_GUILD_ITEM_LOOTED = With(progress, { format = "guildLoot" }),

		-- Players coming online / going offline, /who results and other notices.
		CHAT_MSG_SYSTEM = With(system),
		CHAT_MSG_AFK = With(system, { format = "get" }),
		CHAT_MSG_DND = With(system, { format = "get" }),
		CHAT_MSG_IGNORED = With(system, { format = "ignored" }),
		CHAT_MSG_FILTERED = With(system, { format = "filtered" }),
		CHAT_MSG_RESTRICTED = With(system, { format = "restricted" }),
		CHAT_MSG_CHANNEL_NOTICE = With(system, { format = "notice" }),
		CHAT_MSG_CHANNEL_NOTICE_USER = With(system, { format = "noticeUser" }),
		-- "Bob creates [Flask]": crafting of everyone nearby.
		CHAT_MSG_TRADESKILLS = With(notices),
		CHAT_MSG_PET_INFO = With(system),
		CHAT_MSG_PET_BATTLE_INFO = With(system),
		CHAT_MSG_BG_SYSTEM_HORDE = With(system),
		CHAT_MSG_BG_SYSTEM_ALLIANCE = With(system),
		CHAT_MSG_BG_SYSTEM_NEUTRAL = With(system),
		CHAT_MSG_TARGETICONS = With(system),
		CHAT_MSG_PING = With(system, { format = "ping" }),
		CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE = With(system),
		-- Battle.net friends coming online / going offline.
		CHAT_MSG_BN_INLINE_TOAST_ALERT = With(system, {
			format = "toast",
			toast = { FRIEND_ONLINE = true, FRIEND_OFFLINE = true },
		}),
		CHAT_MSG_BN_INLINE_TOAST_BROADCAST = With(system, { format = "broadcast" }),
		CHAT_MSG_BN_INLINE_TOAST_BROADCAST_INFORM = With(system, { format = "broadcastInform" }),
	},

	-- Lines Blizzard writes into its chat window without a chat event; each
	-- names its channel definition (see Notices.lua for the wording).
	notices = {
		levelUp = With(progress),
		guildMotd = With(guild, { quiet = true }),
		system = With(system),
	},

	-- Addon output (/sui commands): Blizzard's chat is never shown, so it goes
	-- to "System" and, being an answer to something just typed, opens that
	-- channel (`focus`) even while another one is open. Other addons' print()
	-- output and the /played reply only count as unread (`system` above).
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
