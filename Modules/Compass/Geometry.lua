local _, ns = ...

-- Pure compass math, kept free of WoW API calls so it can be tested outside
-- the game. Angles are in radians. Map positions are 0..1 across the map,
-- x towards the east and y towards the south, as the map APIs return them.

local Geometry = {}
ns.CompassGeometry = Geometry

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

-- From the player's map position to a target's on the same map, given the
-- map's size in yards: how far east and north it lies, and the distance.
function Geometry.Offset(playerX, playerY, targetX, targetY, mapWidth, mapHeight)
	local east = (targetX - playerX) * mapWidth
	local north = (playerY - targetY) * mapHeight
	return east, north, math.sqrt(east * east + north * north)
end

-- Compass bearing of an offset: 0 is north, growing clockwise (east is pi/2).
function Geometry.Bearing(east, north)
	return math.atan2(east, north)
end

-- `facing` is GetPlayerFacing(): 0 is north, growing counter-clockwise (west
-- is pi/2). Returns where `bearing` lies relative to it: 0 straight ahead,
-- negative to the left, positive to the right.
function Geometry.RelativeAngle(bearing, facing)
	return Geometry.Normalize(bearing + facing)
end

-- The same for a compass direction in degrees (0 north, 90 east).
function Geometry.DirectionAngle(degrees, facing)
	return Geometry.RelativeAngle(math.rad(degrees), facing)
end

-- Horizontal offset from the band's centre for a relative angle, or nil
-- outside the arc of `fov` radians that the band of `width` covers.
function Geometry.BandX(angle, fov, width)
	local half = fov / 2
	if math.abs(angle) > half then
		return nil
	end
	return angle / half * width / 2
end

-- Alpha towards the band's ends: 1 up to `fadeStart` (a fraction of the half
-- arc), then falling linearly to `minAlpha` at the end.
function Geometry.EdgeAlpha(angle, fov, fadeStart, minAlpha)
	local fraction = math.abs(angle) / (fov / 2)
	if fraction <= fadeStart then
		return 1
	end
	local t = math.min((fraction - fadeStart) / (1 - fadeStart), 1)
	return 1 - t * (1 - minAlpha)
end

-- Scale (or alpha) by distance: 1 up to `near`, falling linearly to `min` at
-- `far` and beyond. Without a distance (no map size) it stays 1.
function Geometry.DistanceFactor(distance, near, far, min)
	if not distance or distance <= near then
		return 1
	end
	local t = math.min((distance - near) / (far - near), 1)
	return 1 - t * (1 - min)
end

-- The marker that gets the label: among the markers ({ angle, priority })
-- within `focusAngle` of the centre, the highest priority wins, then the one
-- closest to the centre line. Returns nil when none is close enough.
function Geometry.PickFocus(markers, focusAngle)
	local best
	for _, marker in ipairs(markers) do
		local offCentre = math.abs(marker.angle)
		if offCentre <= focusAngle then
			if
				not best
				or marker.priority > best.priority
				or (marker.priority == best.priority and offCentre < math.abs(best.angle))
			then
				best = marker
			end
		end
	end
	return best
end

-- "124 m" (game yards, labelled m), "1.2 km" from 1000 on.
function Geometry.FormatDistance(yards)
	if yards >= 1000 then
		return ("%.1f km"):format(yards / 1000)
	end
	return ("%d m"):format(math.floor(yards + 0.5))
end

-- Label of a compass direction in degrees: "N", "NE", ... for multiples of
-- 45, nil for the ticks between them.
local DIRECTIONS = { [0] = "N", [45] = "NE", [90] = "E", [135] = "SE", [180] = "S", [225] = "SW", [270] = "W", [315] = "NW" }

function Geometry.DirectionLabel(degrees, names)
	local key = DIRECTIONS[degrees % 360]
	return key and (names and names[key] or key)
end
