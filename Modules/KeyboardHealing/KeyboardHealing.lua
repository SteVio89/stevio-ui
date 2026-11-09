local _, ns = ...

local KeyboardHealing = ns.RegisterModule("keyboardHealing", {})
local config = ns.config.keyboardHealing

-- Healing by keyboard: the arrow keys move a cursor over the group grid and
-- target the unit under it, so spells work as usual. While the target isn't
-- friendly (an enemy picked with Tab, or nothing), the first arrow press only
-- returns to the cursor's unit; moving starts with the next one.
--
-- All of it has to keep working in combat, so the logic lives in restricted
-- snippets; Lua only sets things up out of combat. Snippet state (gridMode,
-- cursorGroup, cursorSlot) lives in the controller's environment, which every
-- snippet wrapped against it shares.

local UNITS_PER_GROUP = ns.UNITS_PER_GROUP

-- Rows mode stacks groups upwards with members left to right; columns mode
-- puts groups side by side with members top to bottom (see Group.lua).
local NAVIGATE = [[
	local g, s = cursorGroup, cursorSlot
	local cell = g and owner:GetFrameRef("cell" .. g .. "-" .. s)
	if not (cell and cell:IsShown()) then
		g, s = nil, nil
		for group = 1, 8 do
			if owner:GetFrameRef("cell" .. group .. "-1"):IsShown() then
				g, s = group, 1
				break
			end
		end
		if not g then
			return false
		end
	elseif PlayerCanAssist("target") then
		local groupStep, slotStep = 0, 0
		if gridMode == "rows" then
			if button == "up" then groupStep = 1
			elseif button == "down" then groupStep = -1
			elseif button == "right" then slotStep = 1
			else slotStep = -1 end
		else
			if button == "right" then groupStep = 1
			elseif button == "left" then groupStep = -1
			elseif button == "down" then slotStep = 1
			else slotStep = -1 end
		end

		if slotStep ~= 0 then
			local nextCell = owner:GetFrameRef("cell" .. g .. "-" .. (s + slotStep))
			if nextCell and nextCell:IsShown() then
				s = s + slotStep
			end
		else
			-- Empty groups are skipped; a shorter group clamps to its last member.
			local group = g + groupStep
			while group >= 1 and group <= 8 and not owner:GetFrameRef("cell" .. group .. "-1"):IsShown() do
				group = group + groupStep
			end
			if group >= 1 and group <= 8 then
				g = group
				while s > 1 and not owner:GetFrameRef("cell" .. g .. "-" .. s):IsShown() do
					s = s - 1
				end
			end
		end
	end

	cursorGroup, cursorSlot = g, s
	owner:RunAttribute("UpdateCursor")
	self:SetAttribute("unit", owner:GetFrameRef("cell" .. g .. "-" .. s):GetAttribute("unit"))
	return "LeftButton"
]]

-- Parented to the cell, so it follows the cell's visibility and range alpha
-- and still marks the same slot when the roster changes in combat.
local UPDATE_CURSOR = [[
	local cursor = self:GetFrameRef("cursor")
	local cell = cursorGroup and self:GetFrameRef("cell" .. cursorGroup .. "-" .. cursorSlot)
	if cell then
		cursor:SetParent(cell)
		cursor:ClearAllPoints()
		cursor:SetAllPoints(cell)
		cursor:SetFrameLevel(cell:GetFrameLevel() + 20)
		cursor:SetAttribute("unit", cell:GetAttribute("unit"))
		cursor:Show()
	else
		cursor:SetAttribute("unit", nil)
		cursor:Hide()
	end
]]

-- A mouse click targets a cell too, so the cursor follows it.
local SYNC_FROM_CLICK = [[
	if button == "LeftButton" then
		cursorGroup, cursorSlot = self:GetAttribute("stevio-group"), self:GetAttribute("stevio-slot")
		owner:RunAttribute("UpdateCursor")
	end
]]

-- The restricted snippets above can't see Lua upvalues and spell out the 8 groups themselves.
local MAX_GROUPS = ns.MAX_GROUPS

local controller
local cursor
local testCells = {}
local testActive = false

-- The cursor stays on its cell when the target moves elsewhere (an enemy,
-- loot, or nothing); then it switches to the thinner, dimmer idle border, so
-- it still shows where the arrow keys continue without looking like the target.
-- Only the border textures change, which is allowed on a secure frame in combat.
local function UpdateCursorState()
	local unit = cursor:GetAttribute("unit")
	local isTarget = unit ~= nil and UnitIsUnit(unit, "target")
	if issecretvalue(isTarget) then
		cursor.activeBorder:SetShownFromBoolean(isTarget)
		cursor.idleBorder:SetHiddenFromBoolean(isTarget)
	else
		cursor.activeBorder:SetShown(isTarget)
		cursor.idleBorder:SetShown(not isTarget)
	end
end

local function CreateCursor()
	cursor = CreateFrame("Frame", nil, UIParent, "SecureFrameTemplate")
	cursor.activeBorder = ns.CreateBorder(cursor, 7, config.cursorSize)
	cursor.activeBorder:SetColor(unpack(config.cursorColor))
	cursor.idleBorder = ns.CreateBorder(cursor, 6, config.idleCursorSize)
	cursor.idleBorder:SetColor(unpack(config.idleCursorColor))
	-- Runs after the snippet that moved the cursor set the unit of its new cell.
	cursor:HookScript("OnAttributeChanged", function(_, name)
		if name == "unit" then
			UpdateCursorState()
		end
	end)
	cursor:Hide()
	UpdateCursorState()
	return cursor
end

local function CreateTargeter()
	local targeter = CreateFrame("Button", "StevioUI_GridTargeter", UIParent, "SecureActionButtonTemplate")
	targeter:SetAttribute("type", "target")
	-- Bindings deliver the direction as the mouse button; only the down press counts.
	targeter:SetAttribute("useOnKeyDown", true)
	targeter:RegisterForClicks("AnyDown")
	SecureHandlerWrapScript(targeter, "OnClick", controller, NAVIGATE)
	return targeter
end

local function MarkCell(cell, groupIndex, slot)
	cell:SetAttribute("stevio-group", groupIndex)
	cell:SetAttribute("stevio-slot", slot)
	SecureHandlerWrapScript(cell, "OnClick", controller, SYNC_FROM_CLICK)
end

local function PointCellRefsAt(getCell)
	for groupIndex = 1, MAX_GROUPS do
		for slot = 1, UNITS_PER_GROUP do
			SecureHandlerSetFrameRef(controller, "cell" .. groupIndex .. "-" .. slot, getCell(groupIndex, slot))
		end
	end
end

local function GetLiveCell(groupIndex, slot)
	return ns.groupHeaders[groupIndex]:GetAttribute("child" .. slot)
end

local function GetTestCell(groupIndex, slot)
	return testCells[(groupIndex - 1) * UNITS_PER_GROUP + slot]
end

local function SetCursor(mode, groupIndex, slot)
	SecureHandlerExecute(
		controller,
		("gridMode = %q; cursorGroup = %s; cursorSlot = %s; owner:RunAttribute(%q)"):format(
			mode,
			tostring(groupIndex),
			tostring(slot),
			"UpdateCursor"
		)
	)
end

local function FindPlayerCell()
	local first
	for groupIndex, header in ipairs(ns.groupHeaders) do
		for slot = 1, UNITS_PER_GROUP do
			local cell = header:GetAttribute("child" .. slot)
			local unit = cell and cell:IsShown() and cell:GetAttribute("unit")
			if unit then
				first = first or { groupIndex, slot }
				local isPlayer = UnitIsUnit(unit, "player")
				if not issecretvalue(isPlayer) and isPlayer then
					return groupIndex, slot
				end
			end
		end
	end
	if first then
		return first[1], first[2]
	end
end

local function ResetCursor()
	if testActive then
		return
	end
	SetCursor(ns.GetGroupLayoutMode(ns.GetHighestUsedGroup()), FindPlayerCell())
end

-- /sui test has no real units, so secure stand-ins cover the preview cells,
-- all targeting the player; navigation, the cursor and the Tab round trip
-- behave as in a real group.
local function GetOrCreateTestCell(index)
	local cell = testCells[index]
	if not cell then
		cell = CreateFrame("Button", nil, UIParent, "SecureUnitButtonTemplate")
		cell:RegisterForClicks("AnyUp")
		cell:SetAttribute("type1", "target")
		cell:SetAttribute("unit", "player")
		MarkCell(cell, math.ceil(index / UNITS_PER_GROUP), (index - 1) % UNITS_PER_GROUP + 1)
		testCells[index] = cell
	end
	return cell
end

local function ShowTestCells(previewCells, count, mode)
	for index, previewCell in ipairs(previewCells) do
		local cell = GetOrCreateTestCell(index)
		cell:ClearAllPoints()
		cell:SetAllPoints(previewCell)
		cell:SetFrameLevel(previewCell:GetFrameLevel() + 10)
		cell:SetShown(index <= count)
	end
	testActive = true
	PointCellRefsAt(GetTestCell)
	SetCursor(mode, 1, 1)
end

local function HideTestCells()
	if not testActive then
		return
	end
	for _, cell in ipairs(testCells) do
		cell:Hide()
	end
	testActive = false
	PointCellRefsAt(GetLiveCell)
	ResetCursor()
end

-- Secure frames can't be shown, hidden or re-referenced in combat.
function ns.OnGroupPreviewChanged(previewCells, count, mode)
	if not controller then
		return
	end
	ns.RunAfterCombat(function()
		if previewCells then
			ShowTestCells(previewCells, count, mode)
		else
			HideTestCells()
		end
	end)
end

-- The headers fill their cells in their own GROUP_ROSTER_UPDATE handler, so
-- the cursor waits a frame for them. In combat the cursor keeps its slot, whose
-- unit may now be someone else, so the border is checked against the target again.
local function RequestReset()
	C_Timer.After(0, function()
		UpdateCursorState()
		ns.RunAfterCombat(ResetCursor)
	end)
end

function KeyboardHealing:OnEnable()
	if not ns.groupHeaders then
		return
	end

	controller = CreateFrame("Frame", "StevioUI_GridCursor", UIParent, "SecureHandlerBaseTemplate")
	controller:SetAttribute("UpdateCursor", UPDATE_CURSOR)
	SecureHandlerSetFrameRef(controller, "cursor", CreateCursor())
	for groupIndex = 1, MAX_GROUPS do
		for slot = 1, UNITS_PER_GROUP do
			MarkCell(GetLiveCell(groupIndex, slot), groupIndex, slot)
		end
	end
	PointCellRefsAt(GetLiveCell)

	local targeter = CreateTargeter()
	for direction, key in pairs(config.keys) do
		SetOverrideBindingClick(controller, false, key, targeter:GetName(), direction)
	end

	ns.RegisterEvent("GROUP_ROSTER_UPDATE", RequestReset)
	ns.RegisterEvent("PLAYER_TARGET_CHANGED", UpdateCursorState)
	RequestReset()
end
