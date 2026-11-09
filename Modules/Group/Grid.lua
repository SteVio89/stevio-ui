local _, ns = ...

-- The group grid's geometry, kept free of game API for tests/group_grid_test.lua.

local config = ns.config.group

local MAX_GROUPS = ns.MAX_GROUPS
local UNITS_PER_GROUP = ns.UNITS_PER_GROUP

-- Up to rowsUpToGroup groups, each group is a row of five stacking upwards from
-- the bars. Bigger raids would grow too tall that way, so they switch to one
-- column per group side by side. Shared with the preview.
function ns.GetGroupLayoutMode(highestGroup)
	return highestGroup > config.rowsUpToGroup and "columns" or "rows"
end

-- Both modes span the width of all group columns, so the grid keeps one fixed
-- footprint; in row mode the five cells of a group stretch to fill it.
function ns.GetGroupGridWidth(baseWidth)
	return MAX_GROUPS * baseWidth + (MAX_GROUPS - 1) * config.spacing
end

function ns.GetGroupCellWidth(mode, baseWidth)
	if mode == "rows" then
		return (ns.GetGroupGridWidth(baseWidth) - (UNITS_PER_GROUP - 1) * config.spacing) / UNITS_PER_GROUP
	end
	return baseWidth
end

-- Offsets of a cell's BOTTOMLEFT from the container's BOTTOMLEFT.
function ns.GetGroupCellOffset(mode, groupIndex, slot, cellWidth, cellHeight)
	local stepX, stepY = cellWidth + config.spacing, cellHeight + config.spacing
	if mode == "rows" then
		return (slot - 1) * stepX, (groupIndex - 1) * stepY
	end
	return (groupIndex - 1) * stepX, (UNITS_PER_GROUP - slot) * stepY
end

-- The highest raid group among `subgroups` (group numbers by raid index,
-- possibly with holes for missing roster entries), at least 1.
function ns.HighestGroup(subgroups)
	local highest = 1
	for _, subgroup in pairs(subgroups or {}) do
		if subgroup > highest then
			highest = subgroup
		end
	end
	return highest
end
