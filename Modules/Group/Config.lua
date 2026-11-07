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

	-- Own buffs and HoTs in a row along the top edge of the health bar.
	ownAuraFilter = "HELPFUL|PLAYER",
	ownAuraSize = 12,
	ownAurasMax = 5,

	-- The player name as a watermark on the health bar, behind icons and role.
	nameFontSize = 16,
	nameColor = { 0, 0, 0, 0.45 },

	-- Incoming heals (own, others') and absorb shields on the health bar, like
	-- Blizzard's raid frames; absorbs are drawn white under a striped overlay.
	myHealColor = { 11 / 255, 136 / 255, 105 / 255, 1 },
	otherHealColor = { 21 / 255, 89 / 255, 72 / 255, 1 },
	absorbColor = { 1, 1, 1, 0.35 },

	-- Centered between the debuff sides; must stay narrow enough for 40-player cells.
	roleIconSize = 14,

	-- "RAID" means "the player can dispel it", so the two sides split debuffs by who can remove them.
	dispellableFilter = "HARMFUL|RAID",
	otherFilter = "HARMFUL|!RAID",

	outOfRangeAlpha = 0.4,
	aggroColor = { 1, 0.1, 0.1, 1 },
	targetColor = { 1, 1, 1, 1 },
}
