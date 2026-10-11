local addonName, ns = ...

-- Edit Mode re-stacks the frames it manages whenever something at the bottom of
-- the screen changes (XP gained, pet bar shown, vehicle entered), including in
-- combat where addons can't move protected frames back. Writing our positions
-- into a dedicated Edit Mode layout lets Blizzard place them itself, securely.

local LAYOUT_NAME = addonName

local desiredSystems = {}

function ns:SetEditModeSystem(system, systemIndex, layout, settings)
	desiredSystems[#desiredSystems + 1] = {
		system = system,
		systemIndex = systemIndex,
		anchorInfo = {
			point = layout.point,
			relativeTo = "UIParent",
			relativePoint = layout.relativePoint or layout.point,
			offsetX = layout.x or 0,
			offsetY = layout.y or 0,
		},
		settings = settings or {},
	}
end

local function FindSystem(layoutInfo, system, systemIndex)
	for _, systemInfo in ipairs(layoutInfo.systems) do
		if systemInfo.system == system and systemInfo.systemIndex == systemIndex then
			return systemInfo
		end
	end
end

local function ApplyAnchor(systemInfo, anchorInfo)
	local current = systemInfo.anchorInfo
	local changed = systemInfo.isInDefaultPosition or systemInfo.anchorInfo2 ~= nil
	for key, value in pairs(anchorInfo) do
		if current[key] ~= value then
			changed = true
		end
	end
	systemInfo.anchorInfo = CopyTable(anchorInfo)
	systemInfo.anchorInfo2 = nil
	systemInfo.isInDefaultPosition = false
	return changed
end

-- Only settings the system already carries are touched; adding unknown ones
-- would make Blizzard reject or misread the layout.
local function ApplySettings(systemInfo, settings)
	local changed = false
	for _, settingInfo in ipairs(systemInfo.settings) do
		local value = settings[settingInfo.setting]
		if value ~= nil and settingInfo.value ~= value then
			settingInfo.value = value
			changed = true
		end
	end
	return changed
end

local function FindOwnLayout(customLayouts)
	for index, layoutInfo in ipairs(customLayouts) do
		if layoutInfo.layoutName == LAYOUT_NAME and layoutInfo.layoutType == Enum.EditModeLayoutType.Account then
			return index, layoutInfo
		end
	end
end

local layoutsReady, systemsReady, applied = false, false, false

local function ApplyLayout()
	local saved = C_EditMode.GetLayouts()
	local presets = EditModePresetLayoutManager:GetCopyOfPresetLayouts()
	local customLayouts = saved.layouts

	local changed = false
	local customIndex, layoutInfo = FindOwnLayout(customLayouts)
	if not layoutInfo then
		layoutInfo = CopyTable(presets[1])
		layoutInfo.layoutName = LAYOUT_NAME
		layoutInfo.layoutType = Enum.EditModeLayoutType.Account
		-- Account layouts must precede character layouts, so ours goes first.
		table.insert(customLayouts, 1, layoutInfo)
		customIndex = 1
		changed = true
	end

	for _, desired in ipairs(desiredSystems) do
		local systemInfo = FindSystem(layoutInfo, desired.system, desired.systemIndex)
		if systemInfo then
			changed = ApplyAnchor(systemInfo, desired.anchorInfo) or changed
			changed = ApplySettings(systemInfo, desired.settings) or changed
		end
	end

	-- Blizzard saves presets and custom layouts as one list, presets first.
	local activeIndex = #presets + customIndex
	local wasActive = saved.activeLayout == activeIndex
	if not changed and wasActive then
		return
	end

	local allLayouts = presets
	tAppendAll(allLayouts, customLayouts)
	C_EditMode.SaveLayouts({ layouts = allLayouts, activeLayout = activeIndex })

	-- Blizzard only re-reads a layout when the active one changes, so an
	-- already active layout is left briefly to make the new values apply now.
	if wasActive then
		C_EditMode.SetActiveLayout(1)
	end
	C_EditMode.SetActiveLayout(activeIndex)
end

-- Needs both the layout data from the server and every module's wishes, and
-- runs once: our own save fires EDIT_MODE_LAYOUTS_UPDATED again.
local function TryApply()
	if applied or not layoutsReady or not systemsReady then
		return
	end
	applied = true
	ns:RunAfterCombat(ApplyLayout)
end

local function OnLayoutsReady()
	layoutsReady = true
	TryApply()
end

ns:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", OnLayoutsReady)
ns:RegisterEvent("PLAYER_ENTERING_WORLD", OnLayoutsReady)

-- Called by Init once all modules have registered their systems.
function ns.ApplyEditModeLayout()
	systemsReady = true
	TryApply()
end

-- Custom layouts are remembered by name because inserting ours shifts their indices.
function ns.GetActiveEditModeLayout()
	local saved = C_EditMode.GetLayouts()
	local numPresets = #EditModePresetLayoutManager:GetCopyOfPresetLayouts()
	if saved.activeLayout <= numPresets then
		return { preset = saved.activeLayout }
	end
	local layoutInfo = saved.layouts[saved.activeLayout - numPresets]
	if layoutInfo and layoutInfo.layoutName ~= LAYOUT_NAME then
		return { name = layoutInfo.layoutName, layoutType = layoutInfo.layoutType }
	end
end

function ns.RestoreEditModeLayout(previous)
	local saved = C_EditMode.GetLayouts()
	local numPresets = #EditModePresetLayoutManager:GetCopyOfPresetLayouts()
	local index = previous and previous.preset
	if previous and previous.name then
		for customIndex, layoutInfo in ipairs(saved.layouts) do
			if layoutInfo.layoutName == previous.name and layoutInfo.layoutType == previous.layoutType then
				index = numPresets + customIndex
			end
		end
	end
	C_EditMode.SetActiveLayout(index or 1)
end
