local _, ns = ...

ns.config.accessibility = {
	enabled = true,

	-- Every label is two letters: first from the left hand, second from the
	-- right, so typing alternates hands (German layout: Y is left, Z is right).
	-- Movement keys (W A S D Q E), scroll keys and leader/toggle keys (, . -)
	-- are left out so walking away always works.
	leftKeys = { "F", "G", "R", "T", "V", "B", "C", "X", "Y" },
	rightKeys = { "H", "U", "I", "O", "P", "N", "M", "L", "Z" },
	-- Added as first letters only when a window has more targets than the keys above can label.
	extraLeftKeys = { "D", "S", "A", "E", "W", "Q" },

	scrollDownKey = "J",
	scrollUpKey = "K",

	badge = {
		fontSize = 11,
		padding = 3,
		inset = 2,
		textColor = { 1, 0.82, 0 },
		typedColor = { 0.5, 0.5, 0.5 },
	},

	taxi = {
		width = 220,
		rowHeight = 18,
		padding = 6,
	},
}
