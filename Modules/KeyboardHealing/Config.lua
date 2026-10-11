local _, ns = ...

ns.config.keyboardHealing = {
	enabled = true,

	-- Moves the grid cursor and targets its unit; these keys lose any normal binding.
	keys = { up = "UP", down = "DOWN", left = "LEFT", right = "RIGHT" },

	cursorColor = { 0.7, 0.3, 1, 1 },
	-- In screen pixels, drawn outside the cell.
	cursorSize = 4,
}
