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
	theme = "violet",
	themes = {
		-- Blue-grey tinted black, old gold accent.
		dusk = {
			panel = { 0.047, 0.055, 0.075, 0.84 },
			cell = { 0.027, 0.031, 0.043, 1 },
			edgeTop = { 1, 1, 1, 0.07 },
			edgeInner = { 1, 1, 1, 0.03 },
			shadow = { 0, 0, 0, 0.45 },
			textStrong = { 0.95, 0.94, 0.92 },
			text = { 0.91, 0.90, 0.88 },
			textMuted = { 0.54, 0.56, 0.60 },
			textFaint = { 0.42, 0.44, 0.49 },
			accent = { 0.78, 0.65, 0.38 },
			track = { 0.10, 0.11, 0.13, 1 },
			selected = { 1, 1, 1, 0.06 },
			pill = { 1, 1, 1, 0.10 },
			pillText = { 0.79, 0.80, 0.82 },
			xpFrom = { 0.43, 0.23, 0.62 },
			xpTo = { 0.64, 0.35, 0.82 },
			-- Hints that need attention and actions that can't be undone
			-- (the settings window's key conflicts and reset).
			warning = { 0.92, 0.62, 0.25 },
			danger = { 0.86, 0.36, 0.36 },
		},
		-- Violet tinted black, muted dark violet accent.
		violet = {
			panel = { 0.070, 0.043, 0.102, 0.86 },
			cell = { 0.043, 0.027, 0.059, 1 },
			edgeTop = { 0.77, 0.63, 1, 0.12 },
			edgeInner = { 0.77, 0.63, 1, 0.04 },
			shadow = { 0, 0, 0, 0.45 },
			textStrong = { 0.96, 0.94, 0.98 },
			text = { 0.93, 0.91, 0.95 },
			textMuted = { 0.56, 0.53, 0.63 },
			textFaint = { 0.44, 0.41, 0.50 },
			accent = { 0.52, 0.33, 0.79 },
			track = { 0.11, 0.08, 0.14, 1 },
			selected = { 0.52, 0.33, 0.79, 0.18 },
			pill = { 0.52, 0.33, 0.79, 0.30 },
			pillText = { 0.89, 0.84, 0.96 },
			xpFrom = { 0.29, 0.15, 0.50 },
			xpTo = { 0.52, 0.33, 0.79 },
			warning = { 0.95, 0.64, 0.30 },
			danger = { 0.90, 0.38, 0.42 },
		},
	},

	-- Used when class/reaction can't be determined (e.g. secret identity).
	fallbackHealthColor = { 0.2, 0.75, 0.2 },
	deadColor = { 0.35, 0.35, 0.35 },
	offlineColor = { 0.35, 0.35, 0.35 },
	tappedColor = { 0.5, 0.5, 0.5 },

	-- Edge badges that toggle hidden-by-default elements (chat, tracker).
	-- Segments that light up (new whispers) glow in their color away from the edge.
	badge = {
		width = 3,
		height = 48,
		hiddenColor = { 1, 1, 1, 0.18 },
		shownColor = { 1, 1, 1, 0.45 },
		glowWidth = 8,
	},
}
