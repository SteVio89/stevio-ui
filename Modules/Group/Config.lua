local _, ns = ...

ns.config.group = {
	enabled = true,

	-- Cell width/height live in Cell.xml (see the comment there).
	powerHeight = 3,
	spacing = 3,

	-- Groups 1 to this many are rows stacking upwards; once a higher group is
	-- used (40-player raids) the grid switches to one column per group.
	rowsUpToGroup = 5,

	-- The cell from top to bottom: name and role, debuffs on the right (the
	-- dispellable ones first), own HoTs on the left, then the power bar.
	iconSize = 14,
	debuffsMax = 3,

	-- Own buffs and HoTs in a row along the bottom of the health bar.
	ownAuraFilter = "HELPFUL|PLAYER",
	ownAuraSize = 9,
	ownAurasMax = 5,

	-- The name is light with a shadow, or dark on bright class colors (priest,
	-- rogue, hunter: relative luminance above this) when the class is known.
	nameFontSize = 11,
	darkNameLuminance = 0.5,
	darkNameColor = { 0.05, 0.05, 0.06, 0.85 },
	-- Health bar background of the dead and disconnected.
	deadTrackColor = { 0.08, 0.09, 0.11 },

	-- Incoming heals (own, others') and absorb shields on the health bar, like
	-- Blizzard's raid frames; absorbs are drawn white under a striped overlay.
	myHealColor = { 11 / 255, 136 / 255, 105 / 255, 1 },
	otherHealColor = { 21 / 255, 89 / 255, 72 / 255, 1 },
	absorbColor = { 1, 1, 1, 0.35 },

	-- Top right, for tanks and healers only.
	roleIconSize = 10,

	-- "RAID" means "the player can dispel it"; those come first, with a blue edge.
	dispellableFilter = "HARMFUL|RAID",
	otherFilter = "HARMFUL|!RAID",

	dispelColor = { 0.24, 0.55, 1, 1 },

	outOfRangeAlpha = 0.38,
	aggroColor = { 0.88, 0.28, 0.28, 1 },
	targetColor = { 0.95, 0.94, 0.92, 1 },
}
