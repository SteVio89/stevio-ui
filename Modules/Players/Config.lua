local _, ns = ...

ns.config.players = {
	enabled = true,

	-- Players last seen longer ago than this are deleted at login, unless they
	-- have a rated session or a note; those stay for good.
	keepUnratedDays = 90,
	-- A player who rejoins within this many seconds (a disconnect, a quick
	-- re-invite) continues the same session instead of starting a new one.
	rejoinGrace = 300,

	-- After leaving a group, a popup to rate its players; larger groups get a
	-- chat line instead.
	popupAfterGroup = true,
	popupMaxPlayers = 10,
	-- A chat line when a player with a rating or note joins your group.
	joinReminder = true,
	-- Ratings, notes and loot in player tooltips.
	showInTooltip = true,
	-- Items won with you and their Need share in the tooltip (with showInTooltip).
	lootInTooltip = true,

	-- Guilds whose members are marked in the player database (#45): Lua
	-- patterns, matched case-insensitively against the guild name, e.g.
	-- "alternative f". The mark stays when they leave the guild. Players are
	-- checked when they are in your group, targeted, under the mouse or show
	-- a nameplate.
	blockedGuilds = {},
	-- Red chat lines when a marked player is first seen, joins your group or
	-- whispers you, and a red line in their tooltip.
	blockWarnings = true,

	-- The players window (#86); it is moved by dragging its title bar and
	-- remembers where it was.
	window = { width = 1150, height = 860 },
	colors = {
		-- Roll choices in the roll bars.
		need = { 0.851, 0.349, 0.149 },
		greed = { 0.224, 0.529, 0.898 },
		transmog = { 0.098, 0.620, 0.439 },
		pass = { 0.290, 0.267, 0.345 },
		-- Verdicts "play again" and "avoid", and marked players.
		like = { 0.30, 0.75, 0.45 },
		avoid = { 0.90, 0.36, 0.36 },
		-- Low ratings and the Need warning.
		low = { 0.92, 0.62, 0.25 },
		star = { 0.95, 0.77, 0.30 },
	},
}
