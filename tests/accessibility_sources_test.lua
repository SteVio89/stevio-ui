-- Run with: lua tests/accessibility_sources_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")
local ns = loadAddonFile("Modules/Accessibility/Labels.lua", {
	QuickJump = {},
	config = { accessibility = { taxi = {} } },
})
loadAddonFile("Modules/Accessibility/Taxi.lua", ns)
loadAddonFile("Modules/Accessibility/Panels.lua", ns)
local Internal = ns.AccessibilityInternal
local Panels = Internal.Panels

local function window(name, strata, level)
	return {
		name = name,
		GetFrameStrata = function()
			return strata
		end,
		GetFrameLevel = function()
			return level
		end,
	}
end

-- Topmost first: strata decide, then the frame level; unknown strata go last.
local windows = {
	window("bags", "MEDIUM", 5),
	window("odd", "UNKNOWN", 50),
	window("dialog", "DIALOG", 1),
	window("merchant", "MEDIUM", 9),
}
table.sort(windows, Panels.ByStacking)
local order = {}
for i, frame in ipairs(windows) do
	order[i] = frame.name
end
check(table.concat(order, " ") == "dialog merchant bags odd", "stacking order")

-- Cycling: the first window, then the next, and none past the last or when
-- the active window isn't open anymore.
local a, b = window("a"), window("b")
check(Panels.NextPanel({ a, b }, nil) == a, "first press")
check(Panels.NextPanel({ a, b }, a) == b, "next window")
check(Panels.NextPanel({ a, b }, b) == nil, "past the last")
check(Panels.NextPanel({ a }, b) == nil, "active window closed")
check(Panels.NextPanel({}, nil) == nil, "no windows")

-- Inside a clipping region: the centre counts, edges included.
local function rect(left, bottom, width, height)
	return {
		GetRect = function()
			return left, bottom, width, height
		end,
		GetCenter = function()
			if left then
				return left + width / 2, bottom + height / 2
			end
		end,
	}
end
local region = rect(0, 0, 100, 50)
check(Panels.IsInside(rect(40, 10, 20, 20), region), "centred inside")
check(Panels.IsInside(rect(90, 40, 20, 20), region), "centre on the corner")
check(not Panels.IsInside(rect(95, 10, 20, 20), region), "centre outside")
check(not Panels.IsInside(rect(), region), "not placed")
check(not Panels.IsInside(rect(40, 10, 20, 20), rect()), "region not placed")

-- Flight destinations: only reachable ones, by name ignoring case.
local nodes = Internal.ReachableSorted({
	{ index = 1, type = "REACHABLE", name = "stormwind", cost = 10 },
	{ index = 2, type = "CURRENT" },
	{ index = 3, type = "REACHABLE", name = "Goldshire", cost = 5 },
	{ index = 4, type = "NONE" },
	{ index = 5, type = "REACHABLE", name = "Ironforge", cost = 20 },
})
check(#nodes == 3, "reachable only")
check(nodes[1].index == 3 and nodes[2].index == 5 and nodes[3].index == 1, "sorted ignoring case")

print("accessibility sources tests passed")
