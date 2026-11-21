local _, ns = ...

ns.config.minimap = {
	enabled = true,

	-- The map fills the space right of the target frame column, minus this gap.
	gapToTarget = 16,
	-- Fraction of that space the map actually uses; it stays anchored to the
	-- bottom right corner, so a smaller map leaves more room towards the target.
	sizeScale = 0.75,
	iconScale = 0.8,
	-- Space between the map's bottom edge and the vehicle leave button below it.
	vehicleLeaveGap = 4,

	-- The strip view below the notch (the ',' key switches): the map rotates
	-- with the character and shows only what lies ahead.
	strip = {
		-- Width and height above the player's arrow. The map also shows
		-- `behind` below the arrow, so the arrow isn't cut in half.
		width = 640,
		height = 88,
		behind = 8,
		-- The map fades into the black band over this fraction of each half.
		-- Media/StripMask.tga is made for these four values; after changing
		-- them, run tools/strip_mask.py with the new ones.
		maskFade = 0.25,

		-- Direction letters and ticks along the top edge.
		tickStep = 15,
		tickHeight = 4,
		letterSize = 12,
		-- They fade from this fraction of the half width on to edgeAlpha at the ends.
		fadeStart = 0.5,
		edgeAlpha = 0.15,

		colors = {
			background = { 0, 0, 0, 1 },
			letter = { 1, 1, 1 },
			north = { 1, 0.82, 0 },
			tick = { 0.6, 0.6, 0.6 },
		},
	},
}
