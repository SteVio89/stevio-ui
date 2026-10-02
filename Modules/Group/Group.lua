local _, ns = ...

local config = ns.config.group

local Group = ns:RegisterModule("group", {})

local MAX_GROUPS = 8
local UNITS_PER_GROUP = 5
local CELL_TEMPLATE = "StevioUIGroupCellTemplate"

function ns.GetGroupCellSize()
	local template = C_XMLUtil.GetTemplateInfo(CELL_TEMPLATE)
	return template.width, template.height
end

-- Up to rowsUpToGroup groups, each group is a row of five stacking upwards from
-- the bars. Bigger raids would grow too tall that way, so they switch to one
-- column per group side by side. Shared with the preview.
function ns.GetGroupLayoutMode(highestGroup)
	return highestGroup > config.rowsUpToGroup and "columns" or "rows"
end

-- Both modes span the width of all group columns, so the grid keeps one fixed
-- footprint; in row mode the five cells of a group stretch to fill it.
local function GridWidth(baseWidth)
	return MAX_GROUPS * baseWidth + (MAX_GROUPS - 1) * config.spacing
end

function ns.GetGroupCellWidth(mode, baseWidth)
	if mode == "rows" then
		return (GridWidth(baseWidth) - (UNITS_PER_GROUP - 1) * config.spacing) / UNITS_PER_GROUP
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

function ns.CreateGroupContainer(baseWidth, cellHeight)
	local container = CreateFrame("Frame", nil, UIParent)
	container:SetSize(GridWidth(baseWidth), cellHeight)
	ns.SetPoint(container, ns.layout.group)
	return container
end

local function ApplyHeaderMode(header, groupIndex, mode, container, cellWidth, cellHeight)
	-- Cells only change width here, out of combat; all of them exist already (see PrecreateCells).
	for slot = 1, UNITS_PER_GROUP do
		local cell = header:GetAttribute("child" .. slot)
		if cell then
			cell:SetWidth(cellWidth)
		end
	end

	local x, y = ns.GetGroupCellOffset(mode, groupIndex, 1, cellWidth, cellHeight)
	header:ClearAllPoints()
	-- Anchored at the first cell so groups with fewer members stay aligned.
	if mode == "rows" then
		header:SetAttribute("point", "LEFT")
		header:SetAttribute("xOffset", config.spacing)
		header:SetAttribute("yOffset", 0)
		header:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", x, y)
	else
		header:SetAttribute("point", "TOP")
		header:SetAttribute("xOffset", 0)
		header:SetAttribute("yOffset", -config.spacing)
		header:SetPoint("TOPLEFT", container, "BOTTOMLEFT", x, y + cellHeight)
	end
end

-- One header per raid group, because a single header fills rows or columns by
-- count and would wrap members of different groups together.
local function CreateHeader(groupIndex)
	local header = CreateFrame("Frame", "StevioUI_GroupHeader" .. groupIndex, UIParent, "SecureGroupHeaderTemplate")
	header:SetAttribute("template", CELL_TEMPLATE)
	header:SetAttribute("groupFilter", tostring(groupIndex))
	header:SetAttribute("showRaid", true)
	header:SetAttribute("showParty", groupIndex == 1)
	header:SetAttribute("showPlayer", true)

	-- Copied onto each cell by the header itself, which keeps working in combat.
	header:SetAttribute("_initialAttributeNames", "*type1,*type2")
	header:SetAttribute("_initialAttribute-*type1", "target")
	header:SetAttribute("_initialAttribute-*type2", "togglemenu")
	return header
end

-- Forces all cells to exist now, so joining a group mid-combat never has
-- to create (and therefore configure) secure frames under lockdown.
local function PrecreateCells(header)
	header:SetAttribute("startingIndex", 1 - UNITS_PER_GROUP)
	header:Show()
	header:SetAttribute("startingIndex", 1)
end

local function HighestUsedGroup()
	if not IsInRaid() then
		return 1
	end
	local highest = 1
	for i = 1, GetNumGroupMembers() do
		local _, _, subgroup = GetRaidRosterInfo(i)
		if subgroup and subgroup > highest then
			highest = subgroup
		end
	end
	return highest
end

-- Alpha instead of Hide because headers are secure and may be in combat lockdown.
function ns.SetLiveGroupAlpha(alpha)
	for _, header in ipairs(Group.headers or {}) do
		header:SetAlpha(alpha)
	end
end

function Group:OnEnable()
	local baseWidth, cellHeight = ns.GetGroupCellSize()
	local container = ns.CreateGroupContainer(baseWidth, cellHeight)
	local currentMode

	self.headers = {}
	for groupIndex = 1, MAX_GROUPS do
		self.headers[groupIndex] = CreateHeader(groupIndex)
		PrecreateCells(self.headers[groupIndex])
	end

	-- Secure headers can't be re-anchored in combat; a roster change mid-fight
	-- switches the layout once combat ends.
	local function UpdateMode()
		local mode = ns.GetGroupLayoutMode(HighestUsedGroup())
		if mode == currentMode then
			return
		end
		currentMode = mode
		local cellWidth = ns.GetGroupCellWidth(mode, baseWidth)
		for groupIndex, header in ipairs(self.headers) do
			ApplyHeaderMode(header, groupIndex, mode, container, cellWidth, cellHeight)
		end
	end
	UpdateMode()

	ns:RegisterEvent("GROUP_ROSTER_UPDATE", function()
		ns:RunAfterCombat(UpdateMode)
	end)

	ns.HideBlizzard(CompactPartyFrame)
	ns.HideBlizzard(CompactRaidFrameContainer)
	ns.HideBlizzard(CompactRaidFrameManager)
end
