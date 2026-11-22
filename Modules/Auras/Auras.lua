local _, ns = ...

local Auras = ns.RegisterModule("auras", {})
local config = ns.config.auras

-- Blizzard's buff and debuff frames are kept; only their Edit Mode position,
-- icon size and icons per row are owned here, so they stay compact in the top
-- right corner and the tracker fits below them.

local function AuraSettings(options, limitSetting)
	local Setting = Enum.EditModeAuraFrameSetting
	return {
		[Setting.IconSize] = ns.EditModeStep(options.iconSize, 50, 10),
		[Setting[limitSetting]] = options.iconsPerRow,
	}
end

function Auras:OnEnable()
	local indices = Enum.EditModeAuraFrameSystemIndices
	ns.SetEditModeSystem(
		Enum.EditModeSystem.AuraFrame,
		indices.BuffFrame,
		ns.layout.buffs,
		AuraSettings(config.buffs, "IconLimitBuffFrame")
	)
	ns.SetEditModeSystem(
		Enum.EditModeSystem.AuraFrame,
		indices.DebuffFrame,
		ns.layout.debuffs,
		AuraSettings(config.debuffs, "IconLimitDebuffFrame")
	)
end
