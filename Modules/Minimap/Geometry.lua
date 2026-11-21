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
