local _, ns = ...

local Auras = ns:RegisterModule("auras", {})

-- Blizzard's buff and debuff frames are kept; only their Edit Mode position,
-- icon size and icons per row are owned here, so they stay compact in the top
-- right corner and the tracker fits below them.

-- Edit Mode stores icon size as steps of 10 above 50%.
local function IconSizeSetting(percent)
	return (percent - 50) / 10
end

-- Older clients have one IconLimit setting, newer ones one per frame.
local function Settings(options, limitSetting)
	local Setting = Enum.EditModeAuraFrameSetting
	local settings = {
		[Setting.IconSize] = IconSizeSetting(options.iconSize),
	}
	local limit = Setting[limitSetting] or Setting.IconLimit
	if limit then
		settings[limit] = options.iconsPerRow
	end
	return settings
end

function Auras:OnEnable(config)
	local indices = Enum.EditModeAuraFrameSystemIndices
	ns:SetEditModeSystem(Enum.EditModeSystem.AuraFrame, indices.BuffFrame, ns.layout.buffs,
		Settings(config.buffs, "IconLimitBuffFrame"))
	ns:SetEditModeSystem(Enum.EditModeSystem.AuraFrame, indices.DebuffFrame, ns.layout.debuffs,
		Settings(config.debuffs, "IconLimitDebuffFrame"))
end
