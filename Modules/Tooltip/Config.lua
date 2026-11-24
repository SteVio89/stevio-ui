local _, ns = ...

ns.config.tooltip = {
	enabled = true,

	-- Space between the top of the minimap and the bottom of the tooltip.
	gapAboveMinimap = 8,

	-- The theme's panel color and a black border on the game tooltip instead
	-- of Blizzard's blue-grey (colors only, the layout stays Blizzard's).
	themedBackdrop = true,

	-- The unit's tooltip while hovering a unit frame (player, target, focus,
	-- pet, target of target) or a group cell, at the default position.
	unitFrames = true,
}
