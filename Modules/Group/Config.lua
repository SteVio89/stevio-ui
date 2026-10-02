local _, ns = ...

ns.config.group = {
	enabled = true,

	-- Cell width/height live in Cell.xml (see the comment there).
	powerHeight = 6,
	spacing = 3,

	-- Groups 1 to this many are rows stacking upwards; once a higher group is
	-- used (40-player raids) the grid switches to one column per group.
	rowsUpToGroup = 5,

	iconSize = 14,
	iconsPerSide = 2,

	-- Centered between the debuff sides; must stay narrow enough for 40-player cells.
	roleIconSize = 14,

	-- "RAID" means "the player can dispel it", so the two sides split debuffs by who can remove them.
	dispellableFilter = "HARMFUL|RAID",
	otherFilter = "HARMFUL|!RAID",

	outOfRangeAlpha = 0.4,
	aggroColor = { 1, 0.1, 0.1, 1 },
	targetColor = { 1, 1, 1, 1 },
}
