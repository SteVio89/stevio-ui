local _, ns = ...

ns.config.compass = {
	enabled = true,

	-- The black band below the notch (or the top edge without one).
	width = 480,
	height = 22,
	-- Height of each label line below the band (name and distance).
	labelHeight = 16,

	-- Degrees the band covers; a marker at its end is half of this to the side.
	fov = 180,
	-- Markers within this many degrees of the centre get a label line each.
	focusAngle = 5,
	-- Markers further away (in yards) are hidden, except the map pin, the
	-- corpse and a tracked vignette.
	-- 0 shows the whole zone.
	maxDistance = 0,

	-- Ticks between the direction letters, in degrees.
	tickStep = 15,
	tickHeight = 4,
	letterSize = 12,
	markerSize = 16,
	groupSize = 6,

	-- Letters, ticks and markers fade from this fraction of the half arc on
	-- to edgeAlpha at the band's ends.
	fadeStart = 0.5,
	edgeAlpha = 0.15,
	-- Markers shrink and dim from `near` to `far` yards, down to these.
	near = 100,
	far = 1000,
	farScale = 0.6,
	farAlpha = 0.5,

	-- How often the markers are collected again (moving group members).
	refreshInterval = 0.5,

	markers = {
		mapPin = true,
		quests = true,
		worldQuests = true,
		vignettes = true,
		group = true,
		corpse = true,
	},

	colors = {
		background = { 0, 0, 0, 1 },
		letter = { 1, 1, 1 },
		north = { 1, 0.82, 0 },
		tick = { 0.6, 0.6, 0.6 },
		label = { 1, 1, 1 },
		distance = { 0.6, 0.6, 0.6 },
	},
}
