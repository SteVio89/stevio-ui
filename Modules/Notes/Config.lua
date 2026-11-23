local _, ns = ...

ns.config.notes = {
	enabled = true,

	-- Item notes in item tooltips.
	showInTooltip = true,

	window = { width = 780, height = 500 },

	colors = {
		dim = { 0.5, 0.5, 0.5 },
		selected = { 0.3, 0.5, 0.9, 0.35 },
		hover = { 1, 1, 1, 0.08 },
	},
}
