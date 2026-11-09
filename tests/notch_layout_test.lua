-- Run with: lua tests/notch_layout_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")
local ns = loadAddonFile("Modules/Notch/Layout.lua")
local Layout = ns.NotchLayout

-- Rows: the first shown one gets no gap, even if it starts a group; hidden
-- rows take no space; a group start gets the group gap.
local tops, bottom = Layout.StackRows({
	{ shown = false, height = 14 },
	{ shown = true, height = 21, groupStart = true },
	{ shown = true, height = 14 },
	{ shown = false, height = 14, groupStart = true },
	{ shown = true, height = 14, groupStart = true },
}, 40, 4, 8)
check(tops[1] == nil and tops[4] == nil, "hidden rows have no top")
check(tops[2] == 40, "first shown row without gap")
check(tops[3] == 40 + 21 + 4, "row gap")
check(tops[5] == 65 + 14 + 8, "group gap")
check(bottom == 87 + 14, "bottom of the last row")
tops, bottom = Layout.StackRows({ { shown = false, height = 14 } }, 40, 4, 8)
check(next(tops) == nil and bottom == 40, "nothing shown")

-- Durability: the boundaries belong to the worse level.
check(Layout.DurabilityLevel(0.9, 0.5, 0.2) == "value", "fine")
check(Layout.DurabilityLevel(0.5, 0.5, 0.2) == "warn", "warn at the boundary")
check(Layout.DurabilityLevel(0.3, 0.5, 0.2) == "warn", "warn")
check(Layout.DurabilityLevel(0.2, 0.5, 0.2) == "critical", "critical at the boundary")
check(Layout.DurabilityLevel(0, 0.5, 0.2) == "critical", "broken")

check(Layout.ZoneLabel("Stormwind", "Trade District") == "Stormwind – Trade District", "zone and subzone")
check(Layout.ZoneLabel("Stormwind", "") == "Stormwind", "no subzone")
check(Layout.ZoneLabel("Stormwind", "Stormwind") == "Stormwind", "subzone same as zone")

-- Notch: physical pixels scaled to UIParent units (here 0.5).
local fallback = { width = 200, height = 32 }
local left, right, height, topOffset = Layout.NotchRect(1512, 960, 3024, 1964, 1300, 74, 1724, fallback)
check(left == 650 and right == 862 and height == 37, "notch from the ears")
check(topOffset == 22, "screen top above UIParent")
-- No notch (zero height, or no gap between the ears): the centred fallback.
left, right, height, topOffset = Layout.NotchRect(1000, 600, 2000, 1200, 0, 0, 0, fallback)
check(left == 400 and right == 600 and height == 32 and topOffset == 0, "fallback")
left = Layout.NotchRect(1000, 600, 2000, 1200, 900, 60, 900, fallback)
check(left == 400, "fallback when the ears touch")

print("notch layout tests passed")
