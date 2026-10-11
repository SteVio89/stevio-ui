local _, ns = ...

ns.config.style = {
	texture = "Interface\\Buttons\\WHITE8X8",
	font = STANDARD_TEXT_FONT,
	fontSize = 11,
	fontFlags = "OUTLINE",

	borderColor = { 0, 0, 0, 1 },
	backgroundColor = { 0.08, 0.08, 0.08, 0.85 },

	-- Used when class/reaction can't be determined (e.g. secret identity).
	fallbackHealthColor = { 0.2, 0.75, 0.2 },
	deadColor = { 0.35, 0.35, 0.35 },
	offlineColor = { 0.35, 0.35, 0.35 },
	tappedColor = { 0.5, 0.5, 0.5 },

	-- Edge badges that toggle hidden-by-default elements (chat, tracker).
	badge = {
		width = 6,
		height = 48,
		hiddenColor = { 0.3, 0.3, 0.3, 0.6 },
		shownColor = { 0.8, 0.8, 0.8, 0.9 },
	},
}
