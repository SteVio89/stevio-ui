local _, ns = ...

-- Edit Mode stores both sizes as steps of 5% above a per-system minimum.
local MICRO_MIN, BAGS_MIN, STEP = 70, 75, 5

-- The pure part is kept on ns.Menubar for tests/menubar_test.lua.
local Menubar = {}
ns.Menubar = Menubar

function Menubar.SizeSetting(percent, minimum)
	return math.floor(ns.EditModeStep(percent, minimum, STEP) + 0.5)
end

-- Bag buttons are drawn larger than micro buttons at the same percentage, so
-- the bag size is scaled by their height ratio to end up visually equal.
function Menubar.BagPercent(microPercent, ratio)
	return Clamp(microPercent * ratio, BAGS_MIN, 200)
end

local function MatchingBagPercent(microPercent)
	return Menubar.BagPercent(microPercent, CharacterMicroButton:GetHeight() / MainMenuBarBackpackButton:GetHeight())
end

function ns.CreateMenubar(config)
	ns.SetEditModeSystem(Enum.EditModeSystem.MicroMenu, nil, ns.layout.menubar, {
		[Enum.EditModeMicroMenuSetting.Size] = Menubar.SizeSetting(config.menubarSize, MICRO_MIN),
	})
	ns.SetEditModeSystem(Enum.EditModeSystem.Bags, nil, ns.layout.bags, {
		[Enum.EditModeBagsSetting.Size] = Menubar.SizeSetting(MatchingBagPercent(config.menubarSize), BAGS_MIN),
	})
end
