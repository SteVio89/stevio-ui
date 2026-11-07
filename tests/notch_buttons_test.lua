-- Run with: lua tests/notch_buttons_test.lua  (from the repo root)
local ns = {}
assert(loadfile("Modules/Notch/Buttons.lua"))("stevio-ui", ns)
local Buttons = ns.NotchButtons

local function check(cond, msg)
	if not cond then
		error("FAIL: " .. msg, 2)
	end
end

local function info(extra)
	local result = { name = "DBMMinimapButton", owner = "DBM-Core", isButton = true, width = 31, height = 31 }
	for k, v in pairs(extra) do
		result[k] = v
	end
	return result
end

-- Only named buttons another addon created count; Blizzard's (no owner) and ours stay.
check(Buttons.IsAddonButton(info({}), "stevio-ui"), "addon button")
check(not Buttons.IsAddonButton(info({ owner = false }), "stevio-ui"), "Blizzard button (secure global)")
check(not Buttons.IsAddonButton(info({ owner = "stevio-ui" }), "stevio-ui"), "our own frame")
check(not Buttons.IsAddonButton(info({ name = false }), "stevio-ui"), "unnamed frame")
check(not Buttons.IsAddonButton(info({ isButton = false }), "stevio-ui"), "plain frame")
check(not Buttons.IsAddonButton(info({ width = 12, height = 12 }), "stevio-ui"), "map pin")

-- Grid: lines are centred, the last one holds the rest.
local positions, height = Buttons.Grid(0, 100, 20, 5)
check(#positions == 0 and height == 0, "empty grid")

positions, height = Buttons.Grid(2, 100, 20, 5)
check(height == 20, "one line")
check(positions[1].x == 27.5 and positions[2].x == 52.5, "single line centred")
check(positions[1].y == 0 and positions[2].y == 0, "single line on top")

-- 100 wide fits 4 of 20 + 5 gap (4 * 20 + 3 * 5 = 95).
positions, height = Buttons.Grid(5, 100, 20, 5)
check(height == 45, "two lines")
check(positions[1].x == 2.5 and positions[4].x == 77.5, "full line")
check(positions[5].x == 40 and positions[5].y == 25, "rest centred on the next line")

-- Narrower than one button still gives one column.
positions = Buttons.Grid(2, 10, 20, 5)
check(positions[2].y == 25, "at least one column")

print("notch buttons tests passed")
