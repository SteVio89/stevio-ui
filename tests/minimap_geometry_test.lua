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

local pi = math.pi
local function near(a, b)
	return a and math.abs(a - b) < 1e-9
end

check(near(Geometry.Normalize(3 * pi / 2), -pi / 2), "three quarters right is a quarter left")
check(near(Geometry.Normalize(-3 * pi / 2), pi / 2), "three quarters left is a quarter right")
check(near(Geometry.Normalize(0.5), 0.5), "small angles stay")

-- Facing north: east lies to the right. Facing west (pi/2): north lies to the right.
check(near(Geometry.DirectionAngle(90, 0), pi / 2), "east is right while facing north")
check(near(Geometry.DirectionAngle(0, pi / 2), pi / 2), "north is right while facing west")
check(near(Geometry.DirectionAngle(270, pi / 2), 0), "W ahead while facing west")
check(near(math.abs(Geometry.DirectionAngle(180, 0)), pi), "south is behind")

-- A strip 88 high above the arrow and 640 wide.
check(Geometry.EdgeX(0, 88, 320) == 0, "ahead is the centre")
check(near(Geometry.EdgeX(pi / 4, 88, 320), 88), "45 degrees right leaves the top edge 88 to the right")
check(near(Geometry.EdgeX(-pi / 4, 88, 320), -88), "45 degrees left")
check(Geometry.EdgeX(math.rad(75), 88, 320) == nil, "steep angles leave through the side")
check(near(Geometry.EdgeX(math.rad(74), 88, 320), 88 * math.tan(math.rad(74))), "74 degrees still on top")
check(Geometry.EdgeX(pi / 2, 88, 320) == nil, "straight to the side")
check(Geometry.EdgeX(pi, 88, 320) == nil, "behind")

check(Geometry.EdgeAlpha(100, 320, 0.5, 0.2) == 1, "full alpha near the centre")
check(near(Geometry.EdgeAlpha(-320, 320, 0.5, 0.2), 0.2), "minimum at the end")
check(near(Geometry.EdgeAlpha(240, 320, 0.5, 0.2), 0.6), "half way through the fade")

check(Geometry.DirectionLabel(0) == "N" and Geometry.DirectionLabel(360) == "N", "north")
check(Geometry.DirectionLabel(315) == "NW", "north west")
check(Geometry.DirectionLabel(15) == nil, "a tick")
check(Geometry.DirectionLabel(90, { E = "O" }) == "O", "translated")

local degrees = Geometry.DirectionDegrees(15)
check(#degrees == 24 and degrees[1] == 0 and degrees[24] == 345, "every 15 degrees")
degrees = Geometry.DirectionDegrees(30)
check(#degrees == 16, "30 degree ticks plus the letters at 45, 135, ...: " .. #degrees)
check(degrees[2] == 30 and degrees[3] == 45, "ascending, letters in between")

check(Geometry.StripMapSize(640, 88) == 664, "band corners fit at any angle")
check(Geometry.MaskIndex(0, 120) == 0, "facing north")
check(Geometry.MaskIndex(pi / 2, 120) == 30, "facing west: a quarter")
check(Geometry.MaskIndex(-pi / 2, 120) == 90, "facing east: three quarters")
check(Geometry.MaskIndex(2 * pi - 0.001, 120) == 0, "just short of a full turn rounds to north")
check(Geometry.MaskIndex(math.rad(4), 120) == 1, "nearest step")
check(Geometry.MaskIndex(pi / 2, 120, -1) == 90, "the other way round")
check(Geometry.MaskIndex(0, 120, -1) == 0, "north either way")

print("minimap geometry tests passed")
