local _, ns = ...

ns.config.lootTicker = {
	enabled = true,

	-- Newest loot enters at the bottom and pushes older lines up; once all
	-- rows are taken the oldest line at the top drops out.
	-- 24 rows end below the chat, its input box and the toasts under it.
	maxRows = 24,
	width = 320,
	iconSize = 20,
	rowGap = 3,
	fontSize = 14,

	-- A line fades in, stays for holdTime seconds, then fades out slowly.
	fadeInTime = 0.2,
	holdTime = 10,
	fadeOutTime = 5,
	-- Rows glide to their new place in this many seconds.
	slideTime = 0.25,

	-- Lowest item quality shown (0 poor, 1 common, 2 uncommon, 3 rare, 4 epic, ...).
	minQuality = 0,

	-- Loot of the other group members, as "Name: item" with the name in its
	-- class color, from groupMinQuality up; their lines are dimmed to groupAlpha.
	showGroupLoot = true,
	groupMinQuality = 3,
	groupAlpha = 0.75,
	-- Every group loot roll message (selections, rolls, winners, all passed);
	-- those about other players are dimmed like their loot.
	showRolls = true,
	showCurrency = true,
	-- Looted gold, silver and copper, all on one line.
	showMoney = true,
	-- Looting more of something still listed adds to that line instead of
	-- starting a new one.
	mergeRepeats = true,
}
