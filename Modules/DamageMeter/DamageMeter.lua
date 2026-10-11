local _, ns = ...

local DamageMeter = ns:RegisterModule("damagemeter", {})

-- Edit Mode stores the meter size as the distance from the slider minimum.
local MIN_WIDTH, MIN_HEIGHT = 200, 120

function DamageMeter:OnEnable(config)
	local Setting = Enum.EditModeDamageMeterSetting
	ns:SetEditModeSystem(Enum.EditModeSystem.DamageMeter, nil, ns.layout.damageMeter, {
		[Setting.FrameWidth] = config.width - MIN_WIDTH,
		[Setting.FrameHeight] = config.height - MIN_HEIGHT,
	})
end
