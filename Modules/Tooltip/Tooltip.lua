local _, ns = ...

local Tooltip = ns.RegisterModule("tooltip", {})
local config = ns.config.tooltip

-- Only the default anchor moves, via Edit Mode; tooltips anchored to their
-- owner (action buttons, bags) stay where Blizzard puts them. The position is
-- derived from the minimap, whose size is itself computed at login, so this
-- module must be enabled after the minimap one. The mark toolbar on top of
-- the map stays uncovered.
local function MarkBarHeight()
	local marks = ns.config.marks
	if not marks or marks.enabled == false then
		return 0
	end
	return ns.layout.marks.y + marks.buttonSize
end

function Tooltip:OnEnable()
	local mapLayout = ns.layout.minimap
	-- The corner stand-in keeps the corner map's size while the map is in the strip.
	local map = ns.minimapCorner or Minimap
	ns.SetEditModeSystem(Enum.EditModeSystem.HudTooltip, nil, {
		point = "BOTTOMRIGHT",
		x = mapLayout.x,
		y = mapLayout.y + map:GetHeight() + MarkBarHeight() + config.gapAboveMinimap,
	})
end
