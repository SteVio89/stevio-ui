local _, ns = ...

ns.config.units = {
	enabled = true,

	-- Order matters: later frames anchor to earlier ones.
	frames = {
		{ unit = "player", width = 200, healthHeight = 20, powerHeight = 6, showName = true, showCombat = true },
		{ unit = "target", width = 200, healthHeight = 20, powerHeight = 6, showName = true },
		{ unit = "pet", width = 120, healthHeight = 10, powerHeight = 4, anchorTo = "player", align = "RIGHT", gap = 18 },
		{ unit = "targettarget", width = 120, healthHeight = 10, powerHeight = 0, anchorTo = "target", align = "LEFT", gap = 8 },
	},

	combatIconSize = 16,

	-- Target of target has no change event, so it's polled.
	pollInterval = 0.2,

	castBar = {
		height = 8,
		gap = 6,
		color = { 1, 0.8, 0.2 },
		notInterruptibleColor = { 0.6, 0.6, 0.6 },
	},

	classPower = {
		height = 5,
		gap = 4,
		spacing = 2,
		max = 5,
	},
}
