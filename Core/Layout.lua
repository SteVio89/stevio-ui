local _, ns = ...

-- All positions are UI units relative to UIParent. At uiScale 0.8 on a 1964px
-- high screen the UI is ~960 units high, so one unit is roughly two pixels.
-- Everything hangs off the action bar block so the cluster moves as one.

local barBlockWidth = 454 -- 12 buttons at Edit Mode icon size 80% plus padding
local barBlockTop = 152 -- top edge of the third action bar row
local sideGap = 16

ns.layout = {

	actionBars = {
		{ point = "BOTTOM", x = 0, y = 38 }, -- bar 1 (main)
		{ point = "BOTTOM", x = 0, y = 76 }, -- bar 2 (bottom left)
		{ point = "BOTTOM", x = 0, y = 114 }, -- bar 3 (bottom right)
	},
	-- Left of the main bar, the same height as one bar row.
	actionSets = { point = "BOTTOMRIGHT", relativePoint = "BOTTOM", x = -(barBlockWidth / 2 + 4), y = 38 },
	stanceBar = { point = "BOTTOMRIGHT", relativePoint = "BOTTOM", x = -4, y = 6 },
	petBar = { point = "BOTTOMLEFT", relativePoint = "BOTTOM", x = 4, y = 6 },

	player = { point = "TOPRIGHT", relativePoint = "BOTTOM", x = -(barBlockWidth / 2 + sideGap), y = barBlockTop },
	target = { point = "TOPLEFT", relativePoint = "BOTTOM", x = barBlockWidth / 2 + sideGap, y = barBlockTop },
	-- Above the target's name line (which ends at about barBlockTop + 17),
	-- right of the group grid, running towards the minimap. x counts from the
	-- grid's right edge (see ns.LayoutPosition).
	targetAuras = { point = "BOTTOMLEFT", relativePoint = "BOTTOM", x = 4, y = barBlockTop + 20 },
	-- Above the player's name line, left of the group grid: its cast bar
	-- (10 high, 6 below it) ends where the player's name line ends. Overlaps
	-- the loot ticker, which is click-through. x counts from the grid's left edge.
	focus = { point = "BOTTOMRIGHT", relativePoint = "BOTTOM", x = -4, y = barBlockTop + 36 },

	group = { point = "BOTTOM", x = 0, y = barBlockTop + 24 },

	minimap = { point = "BOTTOMRIGHT", x = -12, y = 44 },
	menubar = { point = "BOTTOMRIGHT", x = -12, y = 8 },
	bags = { point = "BOTTOMLEFT", x = 12, y = 8 },
	-- Above the bags, growing upwards where Blizzard's (turned off) damage meter would sit.
	lootTicker = { point = "BOTTOMLEFT", x = 12, y = 52 },

	-- Top right, stacked: two rows of buffs, two rows of debuffs, then the
	-- tracker, so the tracker no longer covers the auras when shown. The row
	-- heights follow the icon sizes in Modules/Auras/Config.lua (a row at 100%
	-- is about 36 units, icon plus duration text).
	buffs = { point = "TOPRIGHT", x = -12, y = -10 },
	debuffs = { point = "TOPRIGHT", x = -12, y = -76 },

	tracker = { point = "TOPRIGHT", x = -12, y = -160 },
	trackerBadge = { point = "RIGHT", x = 0, y = 0 },

	-- Top left, leaving room above for the tabs.
	chat = { point = "TOPLEFT", x = 12, y = -36 },
	chatBadge = { point = "LEFT", x = 0, y = 0 },
}

-- Positions beside the group grid, by side (1 right, -1 left): their x counts
-- from the grid's edge, so they follow its width (cell size and spacing, which
-- the options panel may change) instead of a copy of it.
local besideGroup = { targetAuras = 1, focus = -1 }

-- `layout` placed beside a grid `halfWidth` wide on `side`: a copy with x
-- moved from the grid's edge to the screen's center line.
function ns.BesideGroup(layout, side, halfWidth)
	local placed = {}
	for key, value in pairs(layout) do
		placed[key] = value
	end
	placed.x = side * halfWidth + (layout.x or 0)
	return placed
end

-- The position ns.layout[name] stands for, worked out when it is applied
-- (the group config isn't loaded yet when this file runs).
function ns.LayoutPosition(name)
	local layout = ns.layout[name]
	local side = besideGroup[name]
	if not side then
		return layout
	end
	return ns.BesideGroup(layout, side, ns.GetGroupHalfWidth())
end
