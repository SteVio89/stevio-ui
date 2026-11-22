-- Run with: lua tests/taxi_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")
local Taxi
loadAddonFile("Modules/Taxi/Taxi.lua", {
	config = { taxi = {} },
	RegisterModule = function(_, module)
		Taxi = module
		return module
	end,
})

-- Flight destinations: only reachable ones, by name ignoring case.
local nodes = Taxi.ReachableSorted({
	{ index = 1, type = "REACHABLE", name = "stormwind", cost = 10 },
	{ index = 2, type = "CURRENT" },
	{ index = 3, type = "REACHABLE", name = "Goldshire", cost = 5 },
	{ index = 4, type = "NONE" },
	{ index = 5, type = "REACHABLE", name = "Ironforge", cost = 20 },
})
check(#nodes == 3, "reachable only")
check(nodes[1].index == 3 and nodes[2].index == 5 and nodes[3].index == 1, "sorted ignoring case")

-- Cost column: nothing for free flights, like Blizzard's flight map.
local function Money(copper)
	return copper .. "c"
end
check(Taxi.CostText(0, Money) == "", "free flight")
check(Taxi.CostText(nil, Money) == "", "no cost known")
check(Taxi.CostText(150, Money) == "150c", "paid flight")

-- Panel height: the rows plus padding, at most the map's height (the rest scrolls).
check(Taxi.PanelHeight(3, 18, 6, 500) == 66, "short list")
check(Taxi.PanelHeight(50, 18, 6, 500) == 500, "long list capped at the map")
check(Taxi.PanelHeight(50, 18, 6, nil) == 912, "no cap")

print("taxi tests passed")
