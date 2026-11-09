-- Run with: lua tests/menubar_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")

-- Stand-ins for the game's Clamp and Core/EditModeLayout.lua's EditModeStep.
function Clamp(value, min, max) -- luacheck: ignore 111
	if value > max then
		return max
	elseif value < min then
		return min
	end
	return value
end

local ns = loadAddonFile("Modules/ActionBars/Menubar.lua", {
	EditModeStep = function(value, minimum, step)
		return (value - minimum) / step
	end,
})
local Menubar = ns.Menubar

-- Steps of 5% above the minimum, rounded to the nearest step.
check(Menubar.SizeSetting(70, 70) == 0, "micro minimum")
check(Menubar.SizeSetting(75, 70) == 1, "one step")
check(Menubar.SizeSetting(200, 70) == 26, "micro maximum")
check(Menubar.SizeSetting(77, 70) == 1, "rounds down below half a step")
check(Menubar.SizeSetting(77.5, 70) == 2, "rounds half a step up")
check(Menubar.SizeSetting(78, 75) == 1, "bags round up")

-- The bag percentage follows the height ratio within 75-200.
check(Menubar.BagPercent(100, 0.8) == 80, "scaled by the ratio")
check(Menubar.BagPercent(75, 0.8) == 75, "clamped to the bag minimum")
check(Menubar.BagPercent(150, 2) == 200, "clamped to the maximum")

print("menubar tests passed")
