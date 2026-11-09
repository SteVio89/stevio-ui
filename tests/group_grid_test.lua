-- Run with: lua tests/group_grid_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")
local ns = loadAddonFile("Modules/Group/Config.lua", { config = {}, MAX_GROUPS = 8, UNITS_PER_GROUP = 5 })
loadAddonFile("Modules/Group/Grid.lua", ns)

-- The default cell from Cell.xml and the default spacing from Config.lua.
local BASE_WIDTH, HEIGHT, SPACING = 80, 50, 3
check(ns.config.group.spacing == SPACING, "default spacing")

-- Rows up to group 5, columns from group 6 on.
check(ns.GetGroupLayoutMode(1) == "rows", "party in rows")
check(ns.GetGroupLayoutMode(5) == "rows", "25-player raid in rows")
check(ns.GetGroupLayoutMode(6) == "columns", "group 6 switches to columns")
check(ns.GetGroupLayoutMode(8) == "columns", "40-player raid in columns")

-- Both modes are as wide as eight columns with seven gaps.
local gridWidth = 8 * 80 + 7 * 3
check(ns.GetGroupGridWidth(BASE_WIDTH) == gridWidth, "grid width")
check(ns.GetGroupCellWidth("columns", BASE_WIDTH) == BASE_WIDTH, "column cells keep the base width")
local rowWidth = ns.GetGroupCellWidth("rows", BASE_WIDTH)
check(rowWidth == (gridWidth - 4 * 3) / 5, "row cells stretch")
check(math.abs(5 * rowWidth + 4 * SPACING - gridWidth) < 1e-9, "five row cells fill the grid")

-- Rows: members left to right, groups stacking upwards.
local x, y = ns.GetGroupCellOffset("rows", 1, 1, rowWidth, HEIGHT)
check(x == 0 and y == 0, "first row cell at the origin")
x, y = ns.GetGroupCellOffset("rows", 1, 3, rowWidth, HEIGHT)
check(x == 2 * (rowWidth + SPACING) and y == 0, "third member to the right")
x, y = ns.GetGroupCellOffset("rows", 4, 2, rowWidth, HEIGHT)
check(x == rowWidth + SPACING and y == 3 * (HEIGHT + SPACING), "group 4 three rows up")

-- Columns: groups left to right, members top to bottom, so the first member
-- sits highest and the fifth at the bottom.
x, y = ns.GetGroupCellOffset("columns", 1, 5, BASE_WIDTH, HEIGHT)
check(x == 0 and y == 0, "last member at the bottom")
x, y = ns.GetGroupCellOffset("columns", 1, 1, BASE_WIDTH, HEIGHT)
check(x == 0 and y == 4 * (HEIGHT + SPACING), "first member on top")
x, y = ns.GetGroupCellOffset("columns", 8, 3, BASE_WIDTH, HEIGHT)
check(x == 7 * (BASE_WIDTH + SPACING) and y == 2 * (HEIGHT + SPACING), "group 8 in the last column")

-- The highest used group, never below 1.
check(ns.HighestGroup(nil) == 1, "no roster")
check(ns.HighestGroup({}) == 1, "empty roster")
check(ns.HighestGroup({ 1, 1, 1 }) == 1, "all in group 1")
check(ns.HighestGroup({ 2, 1, 3, 1 }) == 3, "highest of several")
check(ns.HighestGroup({ 1, nil, 7, nil, 2 }) == 7, "holes are skipped")
check(ns.HighestGroup({ [3] = 6 }) == 6, "only a later entry")

print("group grid tests passed")
