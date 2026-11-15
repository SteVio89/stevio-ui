local _, ns = ...

-- The eight raid symbols, kept free of WoW API calls so they can be tested
-- outside the game. `index` is the raid target index (1 star ... 8 skull,
-- SetRaidTarget).

local Symbols = {}
ns.MarkSymbols = Symbols

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

function Symbols.Texture(index)
	return "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. index
end

-- The secure action attributes of a toolbar button (symbol nil: the clear
-- button): a click runs Blizzard's "raidtarget" action on the target.
function Symbols.Attributes(symbol)
	return {
		-- Act on the mouse release. The template otherwise follows the
		-- ActionButtonUseKeyDown setting (on by default) and then ignores the
		-- release, the only click these buttons register for.
		useOnKeyDown = false,
		unit = "target",
		type1 = "raidtarget",
		action1 = symbol and "toggle" or "clear",
		marker1 = symbol and symbol.index,
	}
end
