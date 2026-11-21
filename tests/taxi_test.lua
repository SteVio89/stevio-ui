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

print("taxi tests passed")
