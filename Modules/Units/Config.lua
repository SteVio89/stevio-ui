local _, ns = ...

ns.config.units = {
	enabled = true,

	-- Order matters: later frames anchor to earlier ones. `healthTextSize` is
	-- the font size of the "12.3k · 87%" health text inside the health bar.
	frames = {
		{ unit = "player", width = 200, healthHeight = 20, powerHeight = 6, showName = true, showCombat = true, healthTextSize = 11 },
		{ unit = "target", width = 200, healthHeight = 20, powerHeight = 6, showName = true, healthTextSize = 11 },
		{ unit = "pet", width = 120, healthHeight = 10, powerHeight = 4, anchorTo = "player", align = "RIGHT", gap = 18, healthTextSize = 8 },
		{ unit = "targettarget", width = 120, healthHeight = 10, powerHeight = 0, anchorTo = "target", align = "LEFT", gap = 8, healthTextSize = 8 },
		{ unit = "focus", width = 120, healthHeight = 10, powerHeight = 0, showName = true, healthTextSize = 8 },
	},

	combatIconSize = 16,

	-- Target of target has no change event, so it's polled.
	pollInterval = 0.2,

	-- Spell name on the left, remaining seconds on the right.
	castBar = {
		height = 14,
		fontSize = 10,
		gap = 6,
		color = { 1, 0.8, 0.2 },
		notInterruptibleColor = { 0.6, 0.6, 0.6 },
		-- The focus frame's own, smaller cast bar.
		focusHeight = 10,
		focusFontSize = 8,
	},

	-- Own debuffs (DoTs) on the target, in a row above the target's name,
	-- starting right of the group grid (see Layout.lua).
	targetAuras = {
		filter = "HARMFUL|PLAYER",
		max = 8,
		size = 18,
		spacing = 2,
	},

	classPower = {
		height = 5,
		gap = 4,
		spacing = 2,
		max = 5,
	},
}
