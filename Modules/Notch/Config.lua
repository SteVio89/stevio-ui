local _, ns = ...

ns.config.notch = {
	enabled = true,

	-- The island sticks out this far on each side of the notch.
	extraWidth = 60,
	padding = 8,
	rowHeight = 14,
	rowGap = 4,
	-- Extra space between the character rows and the world/system rows.
	groupGap = 8,
	barHeight = 4,
	barGap = 3,

	-- The cursor itself is hidden behind the notch, so the hover area reaches
	-- a little below it.
	hoverBelow = 2,

	updateInterval = 0.5,

	-- Used when the client reports no notch (external display, windowed mode).
	fallback = { width = 200, height = 32 },

	durabilityWarn = 0.5,
	durabilityCritical = 0.2,

	colors = {
		background = { 0, 0, 0, 1 },
		barBackground = { 0.15, 0.15, 0.15, 1 },
		label = { 0.6, 0.6, 0.6 },
		value = { 1, 1, 1 },
		warn = { 1, 0.8, 0.2 },
		critical = { 1, 0.25, 0.25 },
		xp = { 0.58, 0, 0.55 },
		xpRested = { 0, 0.39, 0.88 },
		restedAlpha = 0.4,
	},
}
