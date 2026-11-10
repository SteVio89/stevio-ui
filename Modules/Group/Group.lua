local _, ns = ...

local config = ns.config.group

local Group = ns.RegisterModule("group", {})

local MAX_GROUPS = ns.MAX_GROUPS
local UNITS_PER_GROUP = ns.UNITS_PER_GROUP
local CELL_TEMPLATE = "StevioUIGroupCellTemplate"

function ns.GetGroupCellSize()
	local template = C_XMLUtil.GetTemplateInfo(CELL_TEMPLATE)
	return template.width, template.height
end

-- Half the grid's width, rounded up; what sits beside it (Layout.lua) counts from there.
function ns.GetGroupHalfWidth()
	local baseWidth = ns.GetGroupCellSize()
	return math.ceil(ns.GetGroupGridWidth(baseWidth) / 2)
end

function ns.CreateGroupContainer(baseWidth, cellHeight)
	local container = CreateFrame("Frame", nil, UIParent)
	container:SetSize(ns.GetGroupGridWidth(baseWidth), cellHeight)
	ns.SetPoint(container, ns.layout.group)
	return container
end

local function ApplyHeaderMode(header, groupIndex, mode, container, cellWidth, cellHeight)
	-- Cells only change width here, out of combat; all of them exist already (see PrecreateCells).
	-- The header only adds anchors for the new "point" and keeps the old ones on
	-- shown cells, so both would pull each cell into a diagonal staircase.
	for slot = 1, UNITS_PER_GROUP do
		local cell = header:GetAttribute("child" .. slot)
		if cell then
			cell:SetWidth(cellWidth)
			cell:ClearAllPoints()
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

function ns.GetHighestUsedGroup()
	if not IsInRaid() then
		return 1
	end
	local subgroups = {}
	for i = 1, GetNumGroupMembers() do
		local _, _, subgroup = GetRaidRosterInfo(i)
		subgroups[i] = subgroup
	end
	return ns.HighestGroup(subgroups)
end

-- Alpha instead of Hide because headers are secure and may be in combat lockdown.
function ns.SetLiveGroupAlpha(alpha)
	for _, header in ipairs(ns.groupHeaders or {}) do
		header:SetAlpha(alpha)
	end
end

function Group:OnEnable()
	local baseWidth, cellHeight = ns.GetGroupCellSize()
	local container = ns.CreateGroupContainer(baseWidth, cellHeight)
	local currentMode

	local headers = {}
	for groupIndex = 1, MAX_GROUPS do
		headers[groupIndex] = CreateHeader(groupIndex)
		PrecreateCells(headers[groupIndex])
	end
	-- Also read by the preview and keyboard healing.
	ns.groupHeaders = headers

	-- Secure headers can't be re-anchored in combat; a roster change mid-fight
	-- switches the layout once combat ends.
	local function UpdateMode()
		local mode = ns.GetGroupLayoutMode(ns.GetHighestUsedGroup())
		if mode == currentMode then
			return
		end
		currentMode = mode
		local cellWidth = ns.GetGroupCellWidth(mode, baseWidth)
		for groupIndex, header in ipairs(headers) do
			ApplyHeaderMode(header, groupIndex, mode, container, cellWidth, cellHeight)
		end
	end
	UpdateMode()

	ns.RegisterEvent("GROUP_ROSTER_UPDATE", function()
		ns.RunAfterCombat(UpdateMode)
	end)

	-- All of Blizzard's group frames, the classic party frame too: the grid replaces them.
	ns.HideBlizzard(PartyFrame)
	ns.HideBlizzard(CompactPartyFrame)
	ns.HideBlizzard(CompactRaidFrameContainer)
	ns.HideBlizzard(CompactRaidFrameManager)
end
