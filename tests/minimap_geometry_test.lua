-- Run with: lua tests/minimap_geometry_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")
local ns = loadAddonFile("Modules/Minimap/Geometry.lua")
local Geometry = ns.MinimapGeometry

-- 1000 wide: the target ends at 500 + 100 + 200 = 800, the map at 1000 - 20.
check(Geometry.MapSize(1000, 100, 200, -20, 16, 1) == 164, "space between target and map")
check(Geometry.MapSize(1000, 100, 200, -20, 16, 0.75) == 123, "scaled and rounded down")
check(Geometry.MapSize(2000, 100, 200, -20, 16, 1) == 664, "grows with the screen")
check(Geometry.TargetWidth({ { unit = "player", width = 1 }, { unit = "target", width = 150 } }) == 150, "target width")
check(Geometry.TargetWidth({ { unit = "player", width = 1 } }) == 200, "fallback without a target frame")

print("minimap geometry tests passed")
