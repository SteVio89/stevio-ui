local _, ns = ...

ns.config.lootTicker = {
	enabled = true,

	-- Newest loot enters at the bottom and pushes older lines up; once all
	-- rows are taken the oldest line at the top drops out.
	maxRows = 10,
	width = 260,
	iconSize = 16,
	rowGap = 2,
	fontSize = 11,

	-- A line fades in, stays for holdTime seconds, then fades out slowly.
	fadeInTime = 0.2,
	holdTime = 10,
	fadeOutTime = 5,
	-- Rows glide to their new place in this many seconds.
	slideTime = 0.25,

	-- Lowest item quality shown (0 poor, 1 common, 2 uncommon, ...).
	minQuality = 0,
	showCurrency = true,
	-- Looting more of something still listed adds to that line instead of
	-- starting a new one.
	mergeRepeats = true,
}
