local _, ns = ...

-- The restricted snippets of keyboard healing (see KeyboardHealing.lua). They
-- use no Lua API beyond what the restricted environment offers, so
-- tests/keyboard_healing_test.lua can run them in plain Lua.

local Snippets = {}
ns.KeyboardHealingSnippets = Snippets

-- Snippets can't see Lua upvalues, so the group count is written into their
-- text in place of the word MAX_GROUPS.
local function WithMaxGroups(snippet)
	return (snippet:gsub("MAX_GROUPS", tostring(ns.MAX_GROUPS)))
end

-- Rows mode stacks groups upwards with members left to right; columns mode
-- puts groups side by side with members top to bottom (see Group.lua).
Snippets.NAVIGATE = WithMaxGroups([[
	local g, s = cursorGroup, cursorSlot
	local cell = g and owner:GetFrameRef("cell" .. g .. "-" .. s)
	if not (cell and cell:IsShown()) then
		g, s = nil, nil
		for group = 1, MAX_GROUPS do
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
			while group >= 1 and group <= MAX_GROUPS and not owner:GetFrameRef("cell" .. group .. "-1"):IsShown() do
				group = group + groupStep
			end
			if group >= 1 and group <= MAX_GROUPS then
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
]])

-- Parented to the cell, so it follows the cell's visibility and range alpha
-- and still marks the same slot when the roster changes in combat.
Snippets.UPDATE_CURSOR = [[
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
Snippets.SYNC_FROM_CLICK = [[
	if button == "LeftButton" then
		cursorGroup, cursorSlot = self:GetAttribute("stevio-group"), self:GetAttribute("stevio-slot")
		owner:RunAttribute("UpdateCursor")
	end
]]
