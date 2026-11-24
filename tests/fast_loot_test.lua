-- Run with: lua tests/fast_loot_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")
local FastLoot
loadAddonFile("Modules/FastLoot/FastLoot.lua", {
	config = { fastLoot = {} },
	RegisterModule = function(_, module)
		FastLoot = module
		return module
	end,
})

-- Slots: last first, locked ones left in the window.
local slots = FastLoot.SlotsToLoot({ {}, { locked = true }, { locked = false }, {} })
check(#slots == 3, "locked slot skipped")
check(slots[1] == 4 and slots[2] == 3 and slots[3] == 1, "last slot first")
check(#FastLoot.SlotsToLoot({}) == 0, "empty loot")

-- A second LOOT_READY right after the first is ignored.
check(FastLoot.IsRepeat(10.1, 10, 0.3), "repeat within the gap")
check(not FastLoot.IsRepeat(10.5, 10, 0.3), "new loot after the gap")
check(not FastLoot.IsRepeat(10, 0, 0.3), "first loot")

print("fast loot tests passed")
