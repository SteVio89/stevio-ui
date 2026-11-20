-- Run with: lua tests/compass_geometry_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")
local ns = loadAddonFile("Modules/Compass/Geometry.lua")
local Geometry = ns.CompassGeometry

local pi = math.pi
local function near(a, b)
	return math.abs(a - b) < 1e-9
end

check(near(Geometry.Normalize(3 * pi / 2), -pi / 2), "three quarters right is a quarter left")
check(near(Geometry.Normalize(-3 * pi / 2), pi / 2), "three quarters left is a quarter right")
check(near(Geometry.Normalize(0.5), 0.5), "small angles stay")

-- Map 1000 x 500 yards; the target is up and right of the player on the map.
local east, north, distance = Geometry.Offset(0.5, 0.5, 0.53, 0.42, 1000, 500)
check(near(east, 30) and near(north, 40) and near(distance, 50), "offset in yards, y on the map runs south")

check(near(Geometry.Bearing(0, 10), 0), "north")
check(near(Geometry.Bearing(10, 0), pi / 2), "east is clockwise of north")
check(near(Geometry.Bearing(-10, 0), -pi / 2), "west")

-- Facing north: east lies to the right. Facing west (pi/2): north lies to the right.
check(near(Geometry.RelativeAngle(pi / 2, 0), pi / 2), "east is right while facing north")
check(near(Geometry.RelativeAngle(0, pi / 2), pi / 2), "north is right while facing west")
check(near(Geometry.RelativeAngle(-pi / 2, pi / 2), 0), "west is ahead while facing west")
check(near(Geometry.DirectionAngle(180, 0), pi) or near(Geometry.DirectionAngle(180, 0), -pi), "south is behind")
check(near(Geometry.DirectionAngle(270, pi / 2), 0), "W ahead while facing west")

-- 180 degree arc over 480 units.
check(Geometry.BandX(0, pi, 480) == 0, "ahead is the centre")
check(near(Geometry.BandX(pi / 2, pi, 480), 240), "90 degrees right is the right end")
check(near(Geometry.BandX(-pi / 4, pi, 480), -120), "45 degrees left")
check(Geometry.BandX(pi / 2 + 0.01, pi, 480) == nil, "outside the arc is hidden")

check(Geometry.EdgeAlpha(0.2, pi, 0.6, 0.2) == 1, "full alpha near the centre")
check(near(Geometry.EdgeAlpha(pi / 2, pi, 0.6, 0.2), 0.2), "minimum at the end")
check(near(Geometry.EdgeAlpha(pi * 0.4, pi, 0.6, 0.2), 0.6), "half way through the fade")

check(Geometry.DistanceFactor(50, 100, 1000, 0.5) == 1, "close markers at full size")
check(near(Geometry.DistanceFactor(550, 100, 1000, 0.5), 0.75), "half way")
check(near(Geometry.DistanceFactor(5000, 100, 1000, 0.5), 0.5), "far markers at the minimum")
check(Geometry.DistanceFactor(nil, 100, 1000, 0.5) == 1, "no distance known")

local focusAngle = math.rad(5)
local rare = { angle = 0.01, priority = 0 }
local quest = { angle = -0.05, priority = 1 }
local other = { angle = 0.02, priority = 0 }
local outside = { angle = 0.2, priority = 1 }
check(Geometry.PickFocus({ rare, other }, focusAngle) == rare, "closest to the centre line")
check(Geometry.PickFocus({ rare, quest, other }, focusAngle) == quest, "tracked quest wins within the focus")
check(Geometry.PickFocus({ outside, other }, focusAngle) == other, "priority only counts within the focus")
check(Geometry.PickFocus({ outside }, focusAngle) == nil, "nothing in focus")

check(Geometry.FormatDistance(123.6) == "124 m", "rounded yards labelled m")
check(Geometry.FormatDistance(1234) == "1.2 km", "km from 1000 on")

check(Geometry.DirectionLabel(0) == "N" and Geometry.DirectionLabel(360) == "N", "north")
check(Geometry.DirectionLabel(315) == "NW", "north west")
check(Geometry.DirectionLabel(15) == nil, "a tick")
check(Geometry.DirectionLabel(90, { E = "O" }) == "O", "translated")

print("compass geometry tests passed")
