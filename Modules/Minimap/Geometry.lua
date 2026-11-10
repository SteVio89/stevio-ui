local _, ns = ...

-- Pure minimap math, kept free of WoW API calls so it can be tested outside the game.
local Geometry = {}
ns.MinimapGeometry = Geometry

-- Side length of the map: the space between the target frame's right edge and
-- the map's right edge (both from the layout, in UIParent units), minus
-- `gap`, scaled by `sizeScale` and rounded down.
function Geometry.MapSize(uiWidth, targetX, targetWidth, mapX, gap, sizeScale)
	local targetRight = uiWidth / 2 + targetX + targetWidth
	local mapRight = uiWidth + mapX
	return math.floor((mapRight - targetRight - gap) * sizeScale)
end
