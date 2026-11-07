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

	-- Loot of the other group members, as "item  Name" with the name in its
	-- class color, from groupMinQuality up; their lines are dimmed to
	-- groupAlpha and stay groupHoldTime seconds instead of holdTime.
	showGroupLoot = true,
	groupMinQuality = 3,
	groupAlpha = 0.75,
	groupHoldTime = 5,
	-- Group loot rolls from the loot history, one line per drop that changes
	-- as the roll goes on: "rolling · you: Need", then the winner with their
	-- roll and yours. Rolls you passed on or didn't join are dimmed like
	-- group loot; the winner's loot message adds no second line.
	showRolls = true,
	showCurrency = true,
	-- Looted gold, silver and copper, all on one line.
	showMoney = true,
	-- Looting more of something still listed adds to that line instead of
	-- starting a new one.
	mergeRepeats = true,
}
