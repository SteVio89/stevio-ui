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

-- The subzone worth showing next to the zone: nil when it is empty or the same.
function Layout.SubZone(zone, subZone)
	if subZone == "" or subZone == zone then
		return nil
	end
	return subZone
end

-- The value grid: `count` cells in `columns` columns across `width`, each
-- `rowHeight` high with `rowGap` between rows. Returns each cell's left, top
-- and width, and the grid's height.
function Layout.GridCells(count, width, columns, rowHeight, rowGap)
	local cellWidth = width / columns
	local cells = {}
	for index = 1, count do
		local column = (index - 1) % columns
		local line = math.floor((index - 1) / columns)
		cells[index] = { x = column * cellWidth, y = line * (rowHeight + rowGap), width = cellWidth }
	end
	local lines = math.ceil(count / columns)
	return cells, lines > 0 and (lines * rowHeight + (lines - 1) * rowGap) or 0
end

-- A colored square after each unit of money, as an inline texture.
local function Coin(color, size)
	return ("|TInterface\\Buttons\\WHITE8X8:%d:%d:0:0:8:8:0:8:0:8:%d:%d:%d|t"):format(
		size,
		size,
		math.floor(color[1] * 255 + 0.5),
		math.floor(color[2] * 255 + 0.5),
		math.floor(color[3] * 255 + 0.5)
	)
end

-- "21■ 86■ 87■": gold, silver and copper, each followed by a square in its
-- color (`colors`: gold, silver, copper), leading empty units left out.
function Layout.MoneyText(copper, colors, size)
	local gold = math.floor(copper / 10000)
	local silver = math.floor(copper / 100) % 100
	local parts = {}
	if gold > 0 then
		parts[#parts + 1] = gold .. Coin(colors.gold, size)
	end
	if gold > 0 or silver > 0 then
		parts[#parts + 1] = silver .. Coin(colors.silver, size)
	end
	parts[#parts + 1] = (copper % 100) .. Coin(colors.copper, size)
	return table.concat(parts, " ")
end

-- The notch in UIParent units: left and right edge, height, and how far the
-- real screen top lies above UIParent's top. The ears are the notch safe
-- regions in physical pixels (the left one's right edge and bottom, the right
-- one's left edge); without a notch between them, `fallback` ({ width,
-- height }) is centred instead. The last value tells whether there is a real
-- notch.
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
		return leftEarRight * scale, rightEarLeft * scale, leftEarBottom * scale, topOffset, true
	end
	local left = (uiWidth - fallback.width) / 2
	return left, left + fallback.width, fallback.height, topOffset, false
end
