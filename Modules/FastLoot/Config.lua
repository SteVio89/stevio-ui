local _, ns = ...

ns.config.fastLoot = {
	enabled = true,

	-- Seconds the hidden loot window waits for the last items; whatever is
	-- still in it then (full bags, a bind confirmation, master loot) shows it.
	revealDelay = 0.3,
}
