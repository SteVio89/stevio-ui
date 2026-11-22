local _, ns = ...

ns.config.settings = {
	enabled = true,

	-- The default key (^ on a German keyboard) doesn't open the console; the
	-- client doesn't persist SetConsoleKey, so it is set on every login.
	consoleKey = "F12",

	-- CVars that hold client state rather than preferences; exporting them would
	-- make the profile fight the client on every login.
	ignoredCVars = {
		"^last",
		"^closedInfoFrame",
		"[Tt]utorial",
		"^portal$",
		"^realmName$",
		"^accountName$",
		"^agentUID$",
		"^textLocale$",
		"^audioLocale$",
		"^lastCharacterIndex$",
		"^showToastWindow$",
		"Seen$",
		"^currentAddOnVersion$",
		"^addonLoadingTime",
		"^cameraSaved",
		"^engineSurvey",
		"^hwDetect$",
		"^gameTip$",
		"^currentGameMode$",
		"^hasSelectedExperiencePreset$",
		"^videoOptionsVersion$",
		"^seen",
		"Collapsed$",
		"^num%a+Categories$",
		"^numReputationHeaders$",
		"^minimapTrackedInfo",
		"^playerColorOverrides$",
		"^miniWorldMap$",
		"^spellBookMinimize$",
		"^petJournalTab$",
		"^serviceTypeFilter$",
		"^auctionHouseDurationDropdown$",
		"^EJLootClass$",
		-- The graphics API and screen resolutions belong to the machine: the same
		-- account on another computer (or screen) must keep its own.
		"^[Gg]x",
		-- Mirrors the actionBars section of the profile, which is the one place to change it.
		"^enableMultiActionBars$",
		-- Set by stevio-ui modules themselves; a profile value or override would
		-- fight them on every login (tests/config_usage_test.lua checks the list).
		"^rotateMinimap$", -- Minimap keeps the map north up
	},
}
