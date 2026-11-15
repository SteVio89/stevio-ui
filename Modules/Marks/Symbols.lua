local _, ns = ...

-- The eight raid symbols, kept free of WoW API calls so they can be tested
-- outside the game. `index` is the raid target index (1 star ... 8 skull,
-- SetRaidTarget), `world` the ground marker showing the same symbol
-- (PlaceRaidMarker), which is numbered differently.

local Symbols = {}
ns.MarkSymbols = Symbols

-- Blizzard's ground marker menu lists ground marker indices in this order
-- (WORLD_RAID_MARKER_ORDER in Blizzard_CompactRaidFrameManager.lua), skull to
-- star, the reverse of the raid target indices.
local WORLD_BY_POSITION = { 8, 4, 1, 7, 2, 3, 6, 5 }

-- Toolbar order: skull first, the usual kill order, like Blizzard's menu.
Symbols.LIST = {
	{ index = 8, name = { "Skull", "Totenschädel" } },
	{ index = 7, name = { "Cross", "Kreuz" } },
	{ index = 6, name = { "Square", "Quadrat" } },
	{ index = 5, name = { "Moon", "Mond" } },
	{ index = 4, name = { "Triangle", "Dreieck" } },
	{ index = 3, name = { "Diamond", "Diamant" } },
	{ index = 2, name = { "Circle", "Kreis" } },
	{ index = 1, name = { "Star", "Stern" } },
}
for position, symbol in ipairs(Symbols.LIST) do
	symbol.world = WORLD_BY_POSITION[position]
end

function Symbols.Texture(index)
	return "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. index
end

-- The secure action attributes of a toolbar button (symbol nil: the clear
-- button). Left click runs Blizzard's "raidtarget" action on the target,
-- right click (only with ground markers) its "worldmarker" action.
function Symbols.Attributes(symbol, groundMarkers)
	local attributes = {
		-- Act on the mouse release. The template otherwise follows the
		-- ActionButtonUseKeyDown setting (on by default) and then ignores the
		-- release, the only click these buttons register for.
		useOnKeyDown = false,
		unit = "target",
		type1 = "raidtarget",
		action1 = symbol and "toggle" or "clear",
		marker1 = symbol and symbol.index,
	}
	if groundMarkers then
		-- Ground markers need no target. "none" keeps Blizzard's handler from
		-- dropping the click when there is no target.
		attributes.unit2 = "none"
		attributes.type2 = "worldmarker"
		-- Without a marker index, "clear" removes all ground markers.
		attributes.action2 = symbol and "toggle" or "clear"
		attributes.marker2 = symbol and symbol.world
	end
	return attributes
end
