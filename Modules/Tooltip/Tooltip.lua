local _, ns = ...

local Tooltip = ns:RegisterModule("tooltip", {})

-- Only the default anchor moves, via Edit Mode; tooltips anchored to their
-- owner (action buttons, bags) stay where Blizzard puts them. The position is
-- derived from the minimap, whose size is itself computed at login, so this
-- module must be enabled after the minimap one.
function Tooltip:OnEnable(config)
	local mapLayout = ns.layout.minimap
	ns:SetEditModeSystem(Enum.EditModeSystem.HudTooltip, nil, {
		point = "BOTTOMRIGHT",
		x = mapLayout.x,
		y = mapLayout.y + Minimap:GetHeight() + config.gapAboveMinimap,
	})
end
