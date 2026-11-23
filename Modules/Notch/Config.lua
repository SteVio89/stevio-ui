local _, ns = ...

ns.config.notch = {
	enabled = true,

	-- The island sticks out this far on each side of the notch.
	extraWidth = 60,
	padding = 8,
	rowHeight = 14,
	rowGap = 4,
	-- Space above and below the lines between XP/zone, the value grid and the buttons.
	groupGap = 10,
	separatorColor = { 1, 1, 1, 0.07 },
	barHeight = 4,
	barGap = 3,
	-- The bottom corners are round; the top stays square under the notch.
	cornerRadius = 14,

	-- Gold, bags, durability, time, system and friends in a grid: label above
	-- value, this many columns.
	gridColumns = 3,
	gridRowHeight = 26,
	gridRowGap = 8,
	-- The squares after gold, silver and copper.
	coinSize = 6,
	coinColors = {
		gold = { 0.89, 0.72, 0.29 },
		silver = { 0.73, 0.75, 0.78 },
		copper = { 0.75, 0.47, 0.29 },
	},

	-- The cursor itself is hidden behind the notch, so the hover area reaches
	-- a little below it.
	hoverBelow = 2,
	-- Once open, the island stays while the cursor is within this margin of it,
	-- and only closes after the cursor has been outside for hideDelay seconds,
	-- so brief slips past the edge (or a row disappearing) do not close it.
	islandMargin = 6,
	hideDelay = 0.3,
	-- How often the cursor position is checked.
	pollInterval = 0.05,

	updateInterval = 0.5,

	-- Used when the client reports no notch (external display, windowed mode).
	fallback = { width = 200, height = 32 },

	-- Minimap buttons of other addons (not Blizzard's) move into the island,
	-- in a grid below the other rows.
	minimapButtons = true,
	-- Muted until hovered; a button whose window is open gets an accent edge.
	buttonSize = 18,
	buttonGap = 7,
	-- Seconds after a loading screen before looking for new buttons, since
	-- addons often create theirs only once the world is shown.
	buttonScanDelay = 2,

	durabilityWarn = 0.5,
	durabilityCritical = 0.2,

	-- Text and bars use the theme (style.palette): the XP bar fades from its
	-- xpFrom to xpTo color.
	colors = {
		-- Pure black, so the island blends into the notch.
		background = { 0, 0, 0, 1 },
		warn = { 1, 0.8, 0.2 },
		critical = { 1, 0.25, 0.25 },
		xpRested = { 0, 0.39, 0.88 },
	},
	-- Opacity of the rested XP overlay, drawn in the xpRested color.
	restedAlpha = 0.4,
}
