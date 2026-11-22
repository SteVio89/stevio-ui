local addonName, ns = ...

-- Edit Mode re-stacks the frames it manages whenever something at the bottom of
-- the screen changes (XP gained, pet bar shown, vehicle entered), including in
-- combat where addons can't move protected frames back. Writing our positions
-- into a dedicated Edit Mode layout lets Blizzard place them itself, securely.

local LAYOUT_NAME = addonName

local Systems = ns.EditModeSystems

local desiredSystems = {}

function ns.SetEditModeSystem(system, systemIndex, layout, settings)
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

local layoutsReady, systemsReady, applied = false, false, false
local appliedCallbacks, layoutDone = {}, false

-- Account layouts Edit Mode allows (Blizzard's constant, 5 when written).
local function MaxLayouts()
	local consts = Constants and Constants.EditModeConsts
	return consts and consts.EditModeMaxLayoutsPerType or 5
end

-- Returns false when our layout can't be added (no room left).
local function ApplyLayout()
	local saved = C_EditMode.GetLayouts()
	local presets = EditModePresetLayoutManager:GetCopyOfPresetLayouts()
	local customLayouts = saved.layouts

	local changed = false
	local customIndex, layoutInfo = Systems.FindOwnLayout(customLayouts, LAYOUT_NAME)
	if not layoutInfo then
		-- Saving one more than Edit Mode allows would be refused or drop a layout.
		if not Systems.HasRoomForOwnLayout(customLayouts, MaxLayouts()) then
			ns.Notify(
				ns.T(
					"Edit Mode already has %d account layouts; delete one so the stevio-ui layout can be added.",
					"Der Bearbeitungsmodus hat schon %d Account-Layouts; lösche eins, damit das stevio-ui-Layout angelegt werden kann."
				):format(MaxLayouts())
			)
			return false
		end
		layoutInfo = CopyTable(presets[1])
		layoutInfo.layoutName = LAYOUT_NAME
		layoutInfo.layoutType = Enum.EditModeLayoutType.Account
		-- Account layouts must precede character layouts, so ours goes first.
		table.insert(customLayouts, 1, layoutInfo)
		customIndex = 1
		changed = true
	end

	for _, desired in ipairs(desiredSystems) do
		local systemInfo = Systems.Find(layoutInfo, desired.system, desired.systemIndex)
		if systemInfo then
			changed = Systems.ApplyAnchor(systemInfo, desired.anchorInfo) or changed
			changed = Systems.ApplySettings(systemInfo, desired.settings) or changed
		end
	end

	-- Blizzard saves presets and custom layouts as one list, presets first.
	local activeIndex = #presets + customIndex
	local wasActive = saved.activeLayout == activeIndex
	if not changed and wasActive then
		return true
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
	return true
end

-- Runs `fn` once our layout is in place (right away if it already is), e.g. to
-- hide a frame only once it no longer sits in Blizzard's default position.
function ns.OnEditModeLayoutApplied(fn)
	if layoutDone then
		fn()
	else
		appliedCallbacks[#appliedCallbacks + 1] = fn
	end
end

-- The callbacks also run when the layout couldn't be applied or failed, so
-- nothing waits for good.
local function ApplyAndNotify()
	ns.SafeCall(ApplyLayout)
	layoutDone = true
	local callbacks = appliedCallbacks
	appliedCallbacks = {}
	for _, fn in ipairs(callbacks) do
		ns.SafeCall(fn)
	end
end

-- Needs both the layout data from the server and every module's wishes, and
-- runs once: our own save fires EDIT_MODE_LAYOUTS_UPDATED again.
local function TryApply()
	if applied or not layoutsReady or not systemsReady then
		return
	end
	applied = true
	ns.RunAfterCombat(ApplyAndNotify)
end

-- Blizzard reads the layouts only from EDIT_MODE_LAYOUTS_UPDATED. Entering the
-- world counts as ready only once its Edit Mode manager has them (the event
-- may have fired before this addon loaded); before that, the list could miss
-- the player's own layouts, and saving it would drop them.
local function OnLayoutsReady(event)
	if
		event == "PLAYER_ENTERING_WORLD"
		and EditModeManagerFrame
		and EditModeManagerFrame.IsInitialized
		and not EditModeManagerFrame:IsInitialized()
	then
		return
	end
	ns.UnregisterEvent("EDIT_MODE_LAYOUTS_UPDATED", OnLayoutsReady)
	ns.UnregisterEvent("PLAYER_ENTERING_WORLD", OnLayoutsReady)
	layoutsReady = true
	TryApply()
end

ns.RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED", OnLayoutsReady)
ns.RegisterEvent("PLAYER_ENTERING_WORLD", OnLayoutsReady)

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
