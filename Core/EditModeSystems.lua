local _, ns = ...

-- The parts of an Edit Mode layout stevio-ui changes (EditModeLayout.lua):
-- finding our layout and its systems, and writing positions and settings into
-- them while noting whether anything changed. Only CopyTable and Enum come
-- from the game, so it can be tested outside it.

local Systems = {}
ns.EditModeSystems = Systems

-- Edit Mode stores many sizes as steps above a minimum, e.g. icon sizes as
-- steps of 10 above 50%.
function ns.EditModeStep(value, minimum, step)
	return (value - minimum) / step
end

function Systems.Find(layoutInfo, system, systemIndex)
	for _, systemInfo in ipairs(layoutInfo.systems) do
		if systemInfo.system == system and systemInfo.systemIndex == systemIndex then
			return systemInfo
		end
	end
end

-- Our account layout among `customLayouts`: its index and the layout.
function Systems.FindOwnLayout(customLayouts, layoutName)
	for index, layoutInfo in ipairs(customLayouts) do
		if layoutInfo.layoutName == layoutName and layoutInfo.layoutType == Enum.EditModeLayoutType.Account then
			return index, layoutInfo
		end
	end
end

function Systems.ApplyAnchor(systemInfo, anchorInfo)
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
function Systems.ApplySettings(systemInfo, settings)
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
