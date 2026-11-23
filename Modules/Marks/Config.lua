local _, ns = ...

ns.config.marks = {
	enabled = true,

	buttonSize = 24,
	buttonGap = 2,
	-- Space between the bar's panel and the symbols.
	padding = 6,
	-- Symbols that can't be used right now (no target, or one that can't be
	-- marked) are dimmed to this alpha; the others are muted until hovered,
	-- except the symbol the target carries, which gets an accent edge.
	unusableAlpha = 0.35,
}
