local _, ns = ...

ns.config.notes = {
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
	-- Ratings and notes in player and item tooltips.
	showInTooltip = true,

	window = { width = 780, height = 500 },

	colors = {
		star = { 1, 0.82, 0 },
		dim = { 0.5, 0.5, 0.5 },
		note = { 0.85, 0.85, 0.6 },
		selected = { 0.3, 0.5, 0.9, 0.35 },
		hover = { 1, 1, 1, 0.08 },
	},
}
