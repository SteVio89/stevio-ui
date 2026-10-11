local _, ns = ...

-- All positions are UI units relative to UIParent. At uiScale 0.8 on a 1964px
-- high screen the UI is ~960 units high, so one unit is roughly two pixels.
-- Everything hangs off the action bar block so the cluster moves as one.

local barBlockWidth = 454  -- 12 buttons at Edit Mode icon size 80% plus padding
local barBlockTop = 152    -- top edge of the third action bar row
local sideGap = 16

ns.layout = {
	barBlockWidth = barBlockWidth,
	barBlockTop = barBlockTop,

	actionBars = {
		{ point = "BOTTOM", x = 0, y = 38 },   -- bar 1 (main)
		{ point = "BOTTOM", x = 0, y = 76 },   -- bar 2 (bottom left)
		{ point = "BOTTOM", x = 0, y = 114 },  -- bar 3 (bottom right)
	},
	stanceBar = { point = "BOTTOMRIGHT", relativePoint = "BOTTOM", x = -4, y = 6 },
	petBar = { point = "BOTTOMLEFT", relativePoint = "BOTTOM", x = 4, y = 6 },

	player = { point = "TOPRIGHT", relativePoint = "BOTTOM", x = -(barBlockWidth / 2 + sideGap), y = barBlockTop },
	target = { point = "TOPLEFT", relativePoint = "BOTTOM", x = barBlockWidth / 2 + sideGap, y = barBlockTop },

	group = { point = "BOTTOM", x = 0, y = barBlockTop + 24 },

	minimap = { point = "BOTTOMRIGHT", x = -12, y = 44 },
	menubar = { point = "BOTTOMRIGHT", x = -12, y = 8 },
	bags = { point = "BOTTOMLEFT", x = 12, y = 8 },

	-- Buffs keep Blizzard's heights and only move to the right edge; the tracker
	-- overlaps them when shown, which is fine since it's hidden by default.
	buffs = { point = "TOPRIGHT", x = -12, y = -10 },
	debuffs = { point = "TOPRIGHT", x = -12, y = -155 },

	tracker = { point = "TOPRIGHT", x = -12, y = -8 },
	trackerBadge = { point = "RIGHT", x = 0, y = 0 },

	-- Top left, leaving room above for the tabs.
	chat = { point = "TOPLEFT", x = 12, y = -36 },
	chatBadge = { point = "LEFT", x = 0, y = 0 },

	-- Lower left quarter, below the chat badge and clear of the unit frames.
	damageMeter = { point = "BOTTOMLEFT", x = 12, y = 228 },
}
