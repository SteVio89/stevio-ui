local _, ns = ...

ns.config.style = {
	texture = "Interface\\Buttons\\WHITE8X8",
	font = STANDARD_TEXT_FONT,
	fontSize = 11,
	fontFlags = "OUTLINE",
	-- Text gets a drop shadow instead of an outline; text on bright bars
	-- (health) keeps the outline and adds a thin shadow.
	textShadow = true,

	borderColor = { 0, 0, 0, 1 },

	-- "dusk" or "violet"; read once at load, a change needs /reload. Modules
	-- read the chosen theme's colors from style.palette (Core/Theme.lua),
	-- which also sets style.backgroundColor to its panel color.
	theme = "dusk",
	themes = {
		-- Blue-grey tinted black, old gold accent.
		dusk = {
			panel = { 0.047, 0.055, 0.075, 0.84 },
		},
		-- Violet tinted black, muted dark violet accent.
		violet = {
			panel = { 0.070, 0.043, 0.102, 0.86 },
		},
	},

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
