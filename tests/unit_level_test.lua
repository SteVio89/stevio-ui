-- Run with: lua tests/unit_level_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")

local modules = {}
local ns = loadAddonFile("Modules/Units/Units.lua", {
	config = { units = {}, style = {} },
	RegisterModule = function(name, module)
		modules[name] = module
		return module
	end,
})
local LevelDisplay = modules.units.LevelDisplay

local asked
local function difficultyColor(level)
	asked = level
	return { r = 0.1, g = 0.2, b = 0.3 }
end

local text, r, g, b = LevelDisplay(42, false, difficultyColor)
check(text == 42 and asked == 42, "known level as is")
check(r == 0.1 and g == 0.2 and b == 0.3, "difficulty color")

asked = nil
text, r, g, b = LevelDisplay(-1, false, difficultyColor)
check(text == "??" and r == 1 and g == 0.2 and b == 0.2, "boss level")
check(asked == nil, "no difficulty for unknown levels")

text, r = LevelDisplay(0, false, difficultyColor)
check(text == "??" and r == 1, "level 0")
text, r = LevelDisplay(nil, false, difficultyColor)
check(text == "??" and r == 1, "no level")

local secret = {}
asked = nil
text, r = LevelDisplay(secret, true, difficultyColor)
check(text == secret and r == nil, "secret level unchanged and uncolored")
check(asked == nil, "secret level never compared")

check(ns.UNIT_CHANGE_EVENTS.target == "PLAYER_TARGET_CHANGED", "target change event")

print("unit level tests passed")
