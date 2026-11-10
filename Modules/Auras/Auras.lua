local _, ns = ...

local Auras = ns.RegisterModule("auras", {})
local config = ns.config.auras

-- Blizzard's buff and debuff frames are kept; only their Edit Mode position,
-- icon size and icons per row are owned here, so they stay compact in the top
-- right corner and the tracker fits below them.

-- Older clients have one IconLimit setting, newer ones one per frame.
local function AuraSettings(options, limitSetting)
	local Setting = Enum.EditModeAuraFrameSetting
	local settings = {
		[Setting.IconSize] = ns.EditModeStep(options.iconSize, 50, 10),
	}
	local limit = Setting[limitSetting] or Setting.IconLimit
	if limit then
		settings[limit] = options.iconsPerRow
	end
	return settings
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
