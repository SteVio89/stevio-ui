local _, ns = ...

-- The island's geometry and row contents that need no game state. Kept free
-- of WoW API calls so it can be tested outside the game.

local Layout = {}
ns.NotchLayout = Layout

-- Stacks rows ({ shown, height, groupStart }) downwards from `top`. Rows
-- after the first shown one get `rowGap` above them, or `groupGap` if they
-- start a group. Returns the top of each shown row (nil for hidden ones) and
-- the bottom of the last.
function Layout.StackRows(rows, top, rowGap, groupGap)
	local tops = {}
	local y = top
	local first = true
	for index, row in ipairs(rows) do
		if row.shown then
			if not first then
				y = y + (row.groupStart and groupGap or rowGap)
			end
			tops[index] = y
			y = y + row.height
			first = false
		end
	end
	return tops, y
end

-- Color key of the lowest durability fraction: "critical", "warn" or "value".
function Layout.DurabilityLevel(lowest, warn, critical)
	if lowest <= critical then
		return "critical"
	elseif lowest <= warn then
		return "warn"
	end
	return "value"
end

-- "Zone – Subzone", or just the zone when the subzone is empty or the same.
function Layout.ZoneLabel(zone, subZone)
	return (subZone ~= "" and subZone ~= zone) and (zone .. " – " .. subZone) or zone
end

-- The notch in UIParent units: left and right edge, height, and how far the
-- real screen top lies above UIParent's top. The ears are the notch safe
-- regions in physical pixels (the left one's right edge and bottom, the right
-- one's left edge); without a notch between them, `fallback` ({ width,
-- height }) is centred instead.
function Layout.NotchRect(
	uiWidth,
	uiTop,
	physicalWidth,
	physicalHeight,
	leftEarRight,
	leftEarBottom,
	rightEarLeft,
	fallback
)
	local scale = uiWidth / physicalWidth
	local topOffset = physicalHeight * scale - uiTop
	if leftEarBottom > 0 and rightEarLeft > leftEarRight then
		return leftEarRight * scale, rightEarLeft * scale, leftEarBottom * scale, topOffset
	end
	local left = (uiWidth - fallback.width) / 2
	return left, left + fallback.width, fallback.height, topOffset
end
