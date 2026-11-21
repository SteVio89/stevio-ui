local _, ns = ...

-- Pure minimap math, kept free of WoW API calls so it can be tested outside the game.
local Geometry = {}
ns.MinimapGeometry = Geometry

-- Used when the unit list has no target frame: the target frame's default width.
Geometry.FALLBACK_TARGET_WIDTH = 200

-- The width of the target frame in `frames` (config.units.frames), or the fallback.
function Geometry.TargetWidth(frames)
	for _, spec in ipairs(frames) do
		if spec.unit == "target" then
			return spec.width
		end
	end
	return Geometry.FALLBACK_TARGET_WIDTH
end

-- Side length of the map: the space between the target frame's right edge and
-- the map's right edge (both from the layout, in UIParent units), minus
-- `gap`, scaled by `sizeScale` and rounded down.
function Geometry.MapSize(uiWidth, targetX, targetWidth, mapX, gap, sizeScale)
	local targetRight = uiWidth / 2 + targetX + targetWidth
	local mapRight = uiWidth + mapX
	return math.floor((mapRight - targetRight - gap) * sizeScale)
end

-- The strip view below the notch (Strip.lua). The map rotates with the
-- character, so straight ahead is up. Angles are in radians.

local pi, twoPi = math.pi, 2 * math.pi

-- Brings an angle into -pi..pi, so it says how far left (negative) or right
-- (positive) something is.
function Geometry.Normalize(angle)
	angle = angle % twoPi
	if angle > pi then
		angle = angle - twoPi
	end
	return angle
end

-- `facing` is GetPlayerFacing(): 0 is north, growing counter-clockwise (west
-- is pi/2). Returns where the compass direction `degrees` (0 north, 90 east)
-- lies relative to it: 0 straight ahead, negative to the left, positive to
-- the right.
function Geometry.DirectionAngle(degrees, facing)
	return Geometry.Normalize(math.rad(degrees) + facing)
end

-- Where a direction's ray from the player's arrow leaves the strip's top
-- edge, `height` above the arrow: the offset from the centre, or nil when
-- the ray leaves through a side (beyond `halfWidth`) or points backwards.
function Geometry.EdgeX(angle, height, halfWidth)
	if math.abs(angle) >= pi / 2 then
		return nil
	end
	local x = height * math.tan(angle)
	if math.abs(x) > halfWidth then
		return nil
	end
	return x
end

-- Alpha towards the strip's ends: 1 up to `fadeStart` (a fraction of the
-- half width), then falling linearly to `minAlpha` at the end.
function Geometry.EdgeAlpha(x, halfWidth, fadeStart, minAlpha)
	local fraction = math.abs(x) / halfWidth
	if fraction <= fadeStart then
		return 1
	end
	local t = math.min((fraction - fadeStart) / (1 - fadeStart), 1)
	return 1 - t * (1 - minAlpha)
end

-- Label of a compass direction in degrees: "N", "NE", ... for multiples of
-- 45, nil for the ticks between them. `names` replaces some (German "O").
local DIRECTIONS =
	{ [0] = "N", [45] = "NE", [90] = "E", [135] = "SE", [180] = "S", [225] = "SW", [270] = "W", [315] = "NW" }

function Geometry.DirectionLabel(degrees, names)
	local key = DIRECTIONS[degrees % 360]
	return key and (names and names[key] or key)
end

-- The degrees that get a tick or a letter: every `tickStep`, plus every 45
-- where the step doesn't land, in ascending order.
function Geometry.DirectionDegrees(tickStep)
	local seen, list = {}, {}
	local function add(degrees)
		if not seen[degrees] then
			seen[degrees] = true
			list[#list + 1] = degrees
		end
	end
	for degrees = 0, 359, tickStep do
		add(degrees)
	end
	for degrees = 0, 315, 45 do
		add(degrees)
	end
	table.sort(list)
	return list
end
