-- Run with: lua tests/settings_keys_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")

local ns = { isGerman = true }
function ns.T(english, german)
	return ns.isGerman and german or english
end
loadAddonFile("Core/Overrides.lua", ns)
loadAddonFile("Modules/Settings/Search.lua", ns)
loadAddonFile("Modules/Settings/Keys.lua", ns)
local Keys = ns.SettingsKeys

-- Readable key names.
check(Keys.DisplayName("SHIFT-A") == "Shift A", "modifier")
check(Keys.DisplayName("SPACE") == "Leertaste", "space")
check(Keys.DisplayName("NUMPAD0") == "Num 0", "numpad")
check(Keys.DisplayName("BUTTON4") == "Maustaste 4", "mouse button")
check(Keys.DisplayName("CTRL-SHIFT-PAGEDOWN") == "Strg Shift Bild runter", "two modifiers")
check(Keys.DisplayName("-") == "-", "minus")
check(Keys.DisplayName("SHIFT--") == "Shift -", "shift minus")
check(Keys.DisplayName("NUMLOCK") == "Num", "num lock")
ns.isGerman = false
check(Keys.DisplayName("CTRL-SPACE") == "Ctrl Space", "English")
ns.isGerman = true
print("names ok")

-- Keyboard healing's keys are locked while it is on.
local locked = Keys.Locked({ enabled = true, keys = { up = "UP", down = "DOWN" } })
check(locked.UP and locked.DOWN and not locked.LEFT, "locked keys")
check(next(Keys.Locked({ enabled = false, keys = { up = "UP" } })) == nil, "off: nothing locked")
check(next(Keys.Locked(nil)) == nil, "no config")
print("locked ok")

-- Conflicts: an own key the profile gives to another action.
local profile = { ["SHIFT-A"] = "STRAFELEFT", W = "MOVEFORWARD", SPACE = "JUMP", NUMPAD0 = "JUMP" }
local overrides = { ["SHIFT-A"] = "MOUNT", NUMPAD0 = false, F = "INTERACT" }
local conflicts = Keys.Conflicts(profile, overrides)
check(#conflicts == 1, "one conflict")
check(conflicts[1].key == "SHIFT-A" and conflicts[1].profileCommand == "STRAFELEFT", "conflict key")
check(conflicts[1].ownCommand == "MOUNT", "own command")
check(Keys.Taken(profile, "W", "JUMP") == "MOVEFORWARD", "taken key")
check(Keys.Taken(profile, "W", "MOVEFORWARD") == nil, "same action")
check(Keys.Taken(profile, "Q", "JUMP") == nil, "free key")
print("conflicts ok")

-- Resetting an action removes the overrides that touch it.
local reset = Keys.ResetKeys("JUMP", profile, overrides)
check(#reset == 1 and reset[1] == "NUMPAD0", "jump gets its key back")
reset = Keys.ResetKeys("MOUNT", profile, overrides)
check(#reset == 1 and reset[1] == "SHIFT-A", "mount loses its key")
reset = Keys.ResetKeys("STRAFELEFT", profile, overrides)
check(#reset == 1 and reset[1] == "SHIFT-A", "strafe gets its key back")
print("reset ok")

-- Rows by category with filters and counts.
local actions = {
	{ command = "MOVEFORWARD", categoryName = "Bewegung", name = "Vorwärts" },
	{ command = "JUMP", categoryName = "Bewegung", name = "Springen" },
	{ command = "STRAFELEFT", categoryName = "Bewegung", name = "Seitwärts nach links" },
	{ command = "MOUNT", categoryName = "Sonstiges", name = "Reittier rufen" },
	{ command = "INTERACT", categoryName = "Sonstiges", name = "Interagieren" },
	{ command = "SCREENSHOT", categoryName = "Sonstiges", name = "Bildschirmfoto" },
}
local groups, counts = Keys.Rows(actions, profile, overrides, "all", "")
check(#groups == 2 and groups[1].name == "Bewegung", "grouped in client order")
check(counts.all == 5 and counts.own == 4 and counts.conflicts == 1 and counts.unbound == 2, "counts")
local jump = groups[1].rows[2]
check(jump.command == "JUMP" and #jump.keys == 1 and jump.keys[1] == "SPACE", "removed key is gone")
local strafe = groups[1].rows[3]
check(#strafe.keys == 0 and strafe.inProfile and strafe.own, "strafe lost its key")
groups = Keys.Rows(actions, profile, overrides, "conflicts", "")
check(#groups == 1 and groups[1].rows[1].command == "MOUNT", "conflict filter")
check(groups[1].rows[1].conflicts[1].profileCommand == "STRAFELEFT", "conflict on the own action")
groups = Keys.Rows(actions, profile, overrides, "unbound", "")
check(#groups == 2, "unbound filter (strafe and screenshot)")
groups = Keys.Rows(actions, profile, overrides, "own", "")
check(#groups[1].rows == 2 and #groups[2].rows == 2, "own filter")
groups = Keys.Rows(actions, profile, overrides, "all", "leertaste")
check(#groups == 1 and groups[1].rows[1].command == "JUMP", "found by key name")
groups = Keys.Rows(actions, profile, overrides, "all", "REITTIER")
check(#groups == 1 and groups[1].rows[1].command == "MOUNT", "found by action name")
groups = Keys.Rows(actions, profile, overrides, "all", "w")
check(#groups == 1, "found by raw key")
print("rows ok")

print("settings keys tests passed")
