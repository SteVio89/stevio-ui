local _, ns = ...

ns.config.actionbars = {
	enabled = true,

	-- Blizzard bar frames in layout order; positions come from ns.layout.actionBars.
	bars = { "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight" },

	-- Written into the Edit Mode layout; Layout.lua assumes 80% for the bar block width.
	iconSize = 80,
	iconPadding = 2,

	iconCrop = 0.08,
	highlightAlpha = 0.2,
	pushedAlpha = 0.35,
	checkedColor = { 1, 0.85, 0.3, 0.35 },

	-- Edit Mode percentage for the micro menu (70-200); bags are matched to it.
	menubarSize = 75,
}
