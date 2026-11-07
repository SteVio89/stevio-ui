local _, ns = ...

ns.config.auras = {
	enabled = true,

	-- Written into the Edit Mode layout. Blizzard reserves room for every
	-- possible aura (32 buffs, 16 debuffs), so iconsPerRow alone decides how
	-- many rows the frames take: 32 / 16 = 2 rows of buffs, 16 / 8 = 2 rows of
	-- debuffs. Layout.lua places the debuffs and the tracker below those rows.
	buffs = { iconSize = 80, iconsPerRow = 16 },
	debuffs = { iconSize = 100, iconsPerRow = 8 },
}
