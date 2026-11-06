local _, ns = ...

ns.config.damagemeter = {
	-- The profile turns Blizzard's meter off (damageMeterEnabled), so there is
	-- nothing to place; set both back to bring it into this spot again.
	enabled = false,

	-- Written into the Edit Mode layout (Blizzard limits: width 200-600, height 120-400).
	width = 390,
	height = 210,
}
