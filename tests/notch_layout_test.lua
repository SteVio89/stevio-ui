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

check(Layout.SubZone("Stormwind", "Trade District") == "Trade District", "zone and subzone")
check(Layout.SubZone("Stormwind", "") == nil, "no subzone")
check(Layout.SubZone("Stormwind", "Stormwind") == nil, "subzone same as zone")

-- Grid: three columns across 300, rows 30 high with a gap of 6.
local cells, gridHeight = Layout.GridCells(6, 300, 3, 30, 6)
check(cells[1].x == 0 and cells[1].y == 0 and cells[1].width == 100, "first cell")
check(cells[3].x == 200 and cells[3].y == 0, "third cell ends the first row")
check(cells[4].x == 0 and cells[4].y == 36, "fourth cell starts the second row")
check(gridHeight == 66, "two rows and one gap")
cells, gridHeight = Layout.GridCells(4, 300, 3, 30, 6)
check(cells[4].y == 36 and gridHeight == 66, "a partly filled row counts")
cells, gridHeight = Layout.GridCells(0, 300, 3, 30, 6)
check(#cells == 0 and gridHeight == 0, "no cells")

-- Money: units with colored squares, leading empty ones left out.
local coins = { gold = { 1, 0, 0 }, silver = { 0, 1, 0 }, copper = { 0, 0, 1 } }
local function Plain(text)
	return (
		text:gsub("|T[^|]*:(%d+):(%d+):%d+|t", function(r, g)
			return r == "255" and "g" or g == "255" and "s" or "c"
		end)
	)
end
check(Plain(Layout.MoneyText(218687, coins, 6)) == "21g 86s 87c", "gold, silver and copper")
check(Plain(Layout.MoneyText(8607, coins, 6)) == "86s 7c", "no gold")
check(Plain(Layout.MoneyText(5, coins, 6)) == "5c", "copper only")
check(Plain(Layout.MoneyText(100000, coins, 6)) == "10g 0s 0c", "empty units after gold stay")
check(Layout.MoneyText(5, coins, 6):find("WHITE8X8:6:6:", 1, true), "square size")

-- Notch: physical pixels scaled to UIParent units (here 0.5).
local fallback = { width = 200, height = 32 }
local left, right, height, topOffset, real = Layout.NotchRect(1512, 960, 3024, 1964, 1300, 74, 1724, fallback)
check(left == 650 and right == 862 and height == 37 and real == true, "notch from the ears")
check(topOffset == 22, "screen top above UIParent")
-- No notch (zero height, or no gap between the ears): the centred fallback.
left, right, height, topOffset, real = Layout.NotchRect(1000, 600, 2000, 1200, 0, 0, 0, fallback)
check(left == 400 and right == 600 and height == 32 and topOffset == 0 and real == false, "fallback")
left = Layout.NotchRect(1000, 600, 2000, 1200, 900, 60, 900, fallback)
check(left == 400, "fallback when the ears touch")

print("notch layout tests passed")
