local _, ns = ...

ns.config.marks = {
	enabled = true,

	buttonSize = 24,
	buttonGap = 2,
	-- Symbols that can't be used right now (no target, or one that can't be
	-- marked) are dimmed to this alpha.
	unusableAlpha = 0.35,
	-- Border of the symbol the target carries.
	activeColor = { 1, 1, 1, 1 },
	-- Dot in the corner of a symbol whose ground marker is placed.
	groundColor = { 0.3, 0.8, 1, 1 },
	-- Seconds between checks of the placed ground markers (the game sends no event for them).
	groundRefresh = 0.5,
}
