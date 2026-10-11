local _, ns = ...

local config = ns.config.accessibility
local style = ns.config.style

-- Quick-jump labels: every selectable button of the open window gets a
-- two-letter label; typing it clicks the button. An uppercase first letter
-- (Shift held) turns the click into a right click.
--
-- Keys are temporary override bindings to secure "click" proxies. A binding
-- click counts as a hardware click, so even protected actions behind Blizzard
-- buttons (release spirit, accept invite) work, which a Lua :Click() wouldn't.
-- Bindings can only change out of combat, so labels exist only out of combat.

local QuickJump = {}
ns.QuickJump = QuickJump

local owner = CreateFrame("Frame")
local overlay = CreateFrame("Frame", nil, UIParent)
overlay:SetFrameStrata("TOOLTIP")
overlay:SetAllPoints()

local sources = {}
local badges = {}
local proxies = {}
local prefixButtons = {}

local current -- { targets, labels, typed, mouseButton, scrollBar }

-- The first letter varies fastest, so the first labels all differ already in
-- the first keystroke. Windows with more targets than the base keys can label
-- borrow extra first letters; those are only ever leader-activated, so taking
-- movement keys is fine there.
local function GenerateLabels(count)
	local leftKeys = config.leftKeys
	if count > #leftKeys * #config.rightKeys then
		leftKeys = CopyTable(leftKeys)
		tAppendAll(leftKeys, config.extraLeftKeys)
	end
	local labels = {}
	for _, right in ipairs(config.rightKeys) do
		for _, left in ipairs(leftKeys) do
			if #labels == count then
				return labels
			end
			labels[#labels + 1] = left .. right
		end
	end
	return labels
end

local function GetBadge(index)
	local badge = badges[index]
	if badge then
		return badge
	end
	badge = CreateFrame("Frame", nil, overlay)
	ns.CreateBackground(badge):SetColorTexture(0, 0, 0, 0.9)
	ns.CreateBorder(badge)
	badge.text = ns.CreateFontString(badge, config.badge.fontSize, "CENTER")
	badge.text:SetPoint("CENTER")
	badges[index] = badge
	return badge
end

local function GetProxy(index)
	local proxy = proxies[index]
	if not proxy then
		proxy = CreateFrame("Button", "StevioUI_QuickJumpProxy" .. index, UIParent, "SecureActionButtonTemplate")
		proxy:SetAttribute("type", "click")
		proxy:RegisterForClicks("AnyDown")
		proxy:SetScript("PostClick", function()
			QuickJump:Finish()
		end)
		proxies[index] = proxy
	end
	return proxy
end

-- Some controls act on mouse handlers instead of OnClick: plain frames like the
-- character window's side tabs, and map pins, whose OnClick Blizzard removes on
-- purpose. A secure proxy only triggers OnClick, so these are driven by calling
-- their mouse handlers directly. They never hide protected actions.
local activators = {}

local function GetFrameActivator(index)
	local activator = activators[index]
	if not activator then
		activator = CreateFrame("Button", "StevioUI_QuickJumpActivator" .. index, UIParent)
		activator:RegisterForClicks("AnyDown")
		activator:SetScript("OnClick", function(self, mouseButton)
			local target = self.target
			local onMouseDown, onMouseUp = target:GetScript("OnMouseDown"), target:GetScript("OnMouseUp")
			if onMouseDown then
				onMouseDown(target, mouseButton)
			end
			if onMouseUp then
				onMouseUp(target, mouseButton, true)
			end
			QuickJump:Finish()
		end)
		activators[index] = activator
	end
	return activator
end

local function GetPrefixButton(index)
	local button = prefixButtons[index]
	if not button then
		button = CreateFrame("Button", "StevioUI_QuickJumpPrefix" .. index, UIParent)
		button:RegisterForClicks("AnyDown")
		prefixButtons[index] = button
	end
	return button
end

-- Text rows like gossip and quest titles start with an icon that carries
-- information (quest complete or not), which a badge inside would cover.
-- Item buttons have no button text, so their icon doesn't count.
local function GetLeadingIcon(target)
	local icon = target.Icon
	if not (icon and icon.IsShown and icon:IsShown() and target.GetFontString and target:GetFontString()) then
		return nil
	end
	local iconLeft, targetLeft = icon:GetLeft(), target:GetLeft()
	if iconLeft and targetLeft and iconLeft - targetLeft < icon:GetWidth() then
		return icon
	end
end

local function ShowBadge(index, target, label, typed)
	local badge = GetBadge(index)
	local remaining = label:sub(#typed + 1)
	local typedColor = CreateColor(unpack(config.badge.typedColor)):GenerateHexColor()
	-- The typed part shows its case, so a pending right click is visible as e.g. "F".
	local shownTyped = current.mouseButton == "RightButton" and typed:upper() or typed:lower()
	local text = (#typed > 0 and ("|c%s%s|r"):format(typedColor, shownTyped) or "") .. remaining:lower()
	badge.text:SetText(text)
	badge.text:SetTextColor(unpack(config.badge.textColor))
	local padding = config.badge.padding
	badge:SetSize(badge.text:GetStringWidth() + padding * 2, badge.text:GetStringHeight() + padding * 2)
	badge:ClearAllPoints()
	-- Inside the button, where the eye already is; outside it got overlooked.
	local icon = GetLeadingIcon(target)
	if icon then
		badge:SetPoint("RIGHT", icon, "LEFT", -config.badge.inset, 0)
	else
		badge:SetPoint("LEFT", target, "LEFT", config.badge.inset, 0)
	end
	badge:Show()
end

local function Scroll(direction)
	if current and current.scrollBar then
		current.scrollBar:ScrollStepInDirection(direction)
		-- Scrolling moves list entries in and out of view, so labels follow.
		QuickJump:RequestRefresh()
	end
end

local scrollDown = CreateFrame("Button", "StevioUI_QuickJumpScrollDown", UIParent)
scrollDown:RegisterForClicks("AnyDown")
scrollDown:SetScript("OnClick", function()
	Scroll(ScrollControllerMixin.Directions.Increase)
end)

local scrollUp = CreateFrame("Button", "StevioUI_QuickJumpScrollUp", UIParent)
scrollUp:RegisterForClicks("AnyDown")
scrollUp:SetScript("OnClick", function()
	Scroll(ScrollControllerMixin.Directions.Decrease)
end)

local function ClearLabels()
	ClearOverrideBindings(owner)
	for _, badge in ipairs(badges) do
		badge:Hide()
	end
	current = nil
end

-- One jump per activation: labels go away after a hit. Leader-activated
-- sources are switched off too; dialogs relabel themselves when their content
-- changes, and the leader key brings labels back otherwise.
function QuickJump:Finish()
	if InCombatLockdown() then
		return
	end
	local source = current and current.source
	if source and source.OnFinished then
		source.OnFinished()
	end
	ClearLabels()
end

function QuickJump:IsActive()
	return current ~= nil
end

local Narrow

-- Binds the next letter of every label still matching what was typed: a final
-- letter clicks its target, an earlier one narrows the selection further.
local function Bind()
	ClearOverrideBindings(owner)
	for _, badge in ipairs(badges) do
		badge:Hide()
	end

	if current.scrollBar then
		SetOverrideBindingClick(owner, true, config.scrollDownKey, scrollDown:GetName(), "LeftButton")
		SetOverrideBindingClick(owner, true, config.scrollUpKey, scrollUp:GetName(), "LeftButton")
	end

	local typed = current.typed
	local nextLetters = {}
	for index, label in ipairs(current.labels) do
		if label:sub(1, #typed) == typed then
			local target = current.targets[index]
			ShowBadge(index, target, label, typed)
			local letter = label:sub(#typed + 1, #typed + 1)
			if #label == #typed + 1 then
				local clicker
				if target:IsObjectType("Button") and target:GetScript("OnClick") then
					clicker = GetProxy(index)
					clicker:SetAttribute("clickbutton", target)
				else
					clicker = GetFrameActivator(index)
					clicker.target = target
				end
				SetOverrideBindingClick(owner, true, letter, clicker:GetName(), current.mouseButton)
				-- Shift may still be held from the first letter of a right click.
				if current.mouseButton == "RightButton" then
					SetOverrideBindingClick(owner, true, "SHIFT-" .. letter, clicker:GetName(), current.mouseButton)
				end
			elseif not nextLetters[letter] then
				nextLetters[letter] = true
				local button = GetPrefixButton(index)
				button:SetScript("OnClick", function(_, mouseButton)
					Narrow(letter, mouseButton)
				end)
				SetOverrideBindingClick(owner, true, letter, button:GetName(), "LeftButton")
				-- Only the first letter has a Shift variant; it selects the right click.
				if typed == "" then
					SetOverrideBindingClick(owner, true, "SHIFT-" .. letter, button:GetName(), "RightButton")
				end
			end
		end
	end
end

function Narrow(letter, mouseButton)
	if not current or InCombatLockdown() then
		return
	end
	if current.typed == "" then
		current.mouseButton = mouseButton
	end
	current.typed = current.typed .. letter
	Bind()
end

local function Collect()
	for _, source in ipairs(sources) do
		if source.IsOpen() then
			local targets = {}
			-- A failing source must not take the whole feature down with it.
			local ok, collected = pcall(source.Collect)
			if not ok then
				geterrorhandler()(collected)
				collected = {}
			end
			for _, target in ipairs(collected) do
				if target:IsVisible() and (not target.IsEnabled or target:IsEnabled()) then
					targets[#targets + 1] = target
				end
			end
			if #targets > 0 then
				return targets, source
			end
		end
	end
end

local function Refresh()
	if InCombatLockdown() then
		return
	end
	local targets, source = Collect()
	if not targets then
		ClearLabels()
		return
	end
	current = {
		targets = targets,
		labels = GenerateLabels(#targets),
		typed = "",
		mouseButton = "LeftButton",
		source = source,
		scrollBar = source.GetScrollBar and source.GetScrollBar(),
	}
	Bind()
end

local refreshPending = false

-- Deferred by a frame because Blizzard fills dialogs after the events and
-- hooks that announce them.
function QuickJump:RequestRefresh()
	if refreshPending then
		return
	end
	refreshPending = true
	C_Timer.After(0, function()
		refreshPending = false
		Refresh()
	end)
end

-- Sources are asked by descending priority; the first open one with targets wins.
function QuickJump:RegisterSource(source)
	sources[#sources + 1] = source
	table.sort(sources, function(a, b)
		return a.priority > b.priority
	end)
end

-- Sorted top to bottom, left to right, so labels follow reading order.
function QuickJump.SortByPosition(targets)
	table.sort(targets, function(a, b)
		local aTop, bTop = a:GetTop() or 0, b:GetTop() or 0
		if math.abs(aTop - bTop) > 1 then
			return aTop > bTop
		end
		return (a:GetLeft() or 0) < (b:GetLeft() or 0)
	end)
	return targets
end

-- PLAYER_REGEN_DISABLED still runs before lockdown starts, the last moment
-- bindings can be removed; leftover labels would keep letters bound in combat.
ns:RegisterEvent("PLAYER_REGEN_DISABLED", ClearLabels)
ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
	QuickJump:RequestRefresh()
end)

-- Dumps what would be labelled right now, for diagnosing missing or dead
-- labels. Saved for reading outside the game and shown in a copyable window.
ns:RegisterSlashCommand("qj", function()
	local lines = {}
	for _, source in ipairs(sources) do
		local open = source.IsOpen()
		lines[#lines + 1] = ("%s: %s"):format(source.name, open and "open" or "closed")
		if open then
			local ok, collected = pcall(source.Collect)
			if not ok then
				lines[#lines + 1] = "  error: " .. tostring(collected)
			else
				for _, target in ipairs(collected) do
					-- Secure clicks refuse targets that are constrained or forbid scripted input.
					local blocked = target.HasAccessConstraints and (target:HasAccessConstraints()
						or target:HasAnyForbiddenAspects(Enum.ForbiddenAspect.ScriptedInput))
					lines[#lines + 1] = ("  %s type=%s visible=%s enabled=%s blocked=%s onclick=%s onmouseup=%s"):format(
						target:GetDebugName(), target:GetObjectType(), tostring(target:IsVisible()),
						tostring(not target.IsEnabled or target:IsEnabled()), tostring(blocked),
						tostring(target:GetScript("OnClick") ~= nil), tostring(target:GetScript("OnMouseUp") ~= nil))
				end
			end
		end
	end
	local text = table.concat(lines, "\n")
	StevioUIDebug = text
	ns.ShowExportWindow(text)
end)
