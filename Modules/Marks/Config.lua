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
}
