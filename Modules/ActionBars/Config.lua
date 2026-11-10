local _, ns = ...

ns.config.actionBars = {
	enabled = true,

	-- Blizzard bar frames in layout order; positions come from ns.layout.actionBars.
	-- Entry n must match entry n of ns.layout.actionBars and of barSystemIndices in ActionBars.lua.
	bars = { "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight" },

	-- Written into the Edit Mode layout; Layout.lua assumes 80% for the bar block width.
	iconSize = 80,
	iconPadding = 2,

	iconCrop = 0.08,
	highlightAlpha = 0.2,
	pushedAlpha = 0.35,
	checkedColor = { 1, 0.85, 0.3, 0.35 },

	-- Action sets switched with the button left of the bars, /sui bars or a key
	-- (out of combat only). Every set has the same slots and keybindings, only
	-- the actions in them differ. Fewer than two names hide the button.
	sets = { "Leveling", "Healing" },
	setButtonWidth = 64,
	setButtonHeight = 36,

	-- Edit Mode percentage for the micro menu (70-200); bags are matched to it.
	menubarSize = 75,
}
