local _, ns = ...

ns.config.minimap = {
	enabled = true,

	-- The map fills the space right of the target frame column, minus this gap.
	gapToTarget = 16,
	iconScale = 0.8,
	-- Space between the map's bottom edge and the vehicle leave button below it.
	vehicleLeaveGap = 4,
}
