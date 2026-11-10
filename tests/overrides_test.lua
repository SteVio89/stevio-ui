-- Run with: lua tests/overrides_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")
local ns = loadAddonFile("Core/Overrides.lua")
local Overrides = ns.Overrides

-- Paths
local path = { "config", "units", "frames", 2, "width" }
check(Overrides.Encode(path) == "config/units/frames/#2/width", "encode")
local decoded = Overrides.Decode("config/units/frames/#2/width")
check(decoded[4] == 2 and decoded[5] == "width" and #decoded == 5, "decode")

-- Prefix and Child copy, so the original path stays as it was.
local prefix = Overrides.Prefix(path, 3)
check(#prefix == 3 and prefix[3] == "frames" and prefix ~= path, "prefix")
check(#Overrides.Prefix(path, 0) == 0, "empty prefix")
local child = Overrides.Child(prefix, 1)
check(#child == 4 and child[4] == 1 and #prefix == 3, "child")
check(#path == 5, "path untouched")

check(Overrides.IsList({ 1, 2 }) and Overrides.IsList({}) and not Overrides.IsList({ a = 1 }), "lists")
check(Overrides.Equal({ a = { 1, 2 } }, { a = { 1, 2 } }) and not Overrides.Equal({ a = 1 }, { a = 1, b = 2 }), "equal")

local function Fresh()
	local roots = {
		config = {
			units = { frames = { { unit = "player", width = 200 }, { unit = "target", width = 200 } } },
			chat = { channels = { "General", "Trade" }, quiet = true },
		},
		layout = { chat = { x = 12 } },
	}
	return roots, Overrides.DeepCopy(roots)
end

-- Put keeps tables in place, so references stay valid.
local roots = Fresh()
local frames = roots.config.units.frames
Overrides.Put(roots, { "config", "units", "frames" }, { { unit = "focus", width = 120 } })
check(roots.config.units.frames == frames and #frames == 1 and frames[1].unit == "focus", "put in place")
Overrides.Put(roots, { "layout", "new", "y" }, 5)
check(roots.layout.new.y == 5, "put creates missing tables")

-- Record: overrides hold only what differs from the defaults.
local defaults
roots, defaults = Fresh()
local values = {}
roots.config.units.frames[2].width = 180
Overrides.Record(values, defaults, roots, { "config", "units", "frames", 2, "width" })
check(values["config/units/frames/#2/width"] == 180, "leaf recorded")
roots.config.units.frames[2].width = 200
Overrides.Record(values, defaults, roots, { "config", "units", "frames", 2, "width" })
check(next(values) == nil, "back to default drops the override")

-- A grown list is saved whole; edits inside it update that whole value.
roots.config.chat.quiet = false
Overrides.Record(values, defaults, roots, { "config", "chat", "quiet" })
table.insert(roots.config.chat.channels, "LFG")
Overrides.Record(values, defaults, roots, { "config", "chat", "channels" })
check(#values["config/chat/channels"] == 3, "grown list saved whole")
roots.config.chat.channels[1] = "Allgemein"
Overrides.Record(values, defaults, roots, { "config", "chat", "channels", 1 })
check(values["config/chat/channels/#1"] == nil, "no leaf inside a whole list")
check(values["config/chat/channels"][1] == "Allgemein", "whole list updated")

-- Saving a list whole drops leaf overrides below it.
roots, defaults = Fresh()
values = {}
roots.config.units.frames[1].width = 150
Overrides.Record(values, defaults, roots, { "config", "units", "frames", 1, "width" })
table.remove(roots.config.units.frames, 2)
Overrides.Record(values, defaults, roots, { "config", "units", "frames" })
check(values["config/units/frames/#1/width"] == nil, "leaf below the list dropped")
check(#values["config/units/frames"] == 1 and values["config/units/frames"][1].width == 150, "list saved with the edit")
check(
	Overrides.OverriddenAt(values, { "config", "units", "frames", 1, "width" }) == "config/units/frames",
	"overridden ancestor"
)
check(Overrides.OverriddenAt(values, { "config", "chat", "quiet" }) == nil, "not overridden")

-- ApplyAll: the saved overrides on fresh defaults give the same live state.
local saved = Overrides.DeepCopy(values)
local fresh = Fresh()
Overrides.ApplyAll(fresh, saved)
check(Overrides.Equal(fresh, roots), "apply reproduces the edits")

-- Whole lists go in before edits below them.
fresh = Fresh()
Overrides.ApplyAll(fresh, {
	["config/chat/channels/#2"] = "Handel",
	["config/chat/channels"] = { "A", "B", "C" },
})
check(fresh.config.chat.channels[1] == "A" and fresh.config.chat.channels[2] == "Handel", "shorter paths first")

-- Flat maps (keybindings, CVars)
local profile = { W = "MOVEFORWARD", S = "MOVEBACKWARD", B = "TOGGLEBACKPACK" }
local current = { W = "MOVEFORWARD", S = "SITORSTAND", Q = "STRAFELEFT" }
local diff = Overrides.Diff(profile, current)
check(diff.S == "SITORSTAND" and diff.Q == "STRAFELEFT" and diff.B == false and diff.W == nil, "diff")
local merged = Overrides.Merge(profile, diff)
check(Overrides.Equal(merged, current), "merge undoes diff")
check(next(Overrides.Diff(profile, profile)) == nil, "no diff, no overrides")

-- Saved values that no longer fit the config are dropped.
fresh = Fresh()
local stale = {
	["config/units/frames/#5/width"] = 100, -- the list has 2 entries
	["config/chat/quiet"] = { 1 }, -- a boolean in code
	["config/gone/x"] = 1, -- a removed table
	["config/chat/oldFlag"] = true, -- a key removed from an existing table
}
Overrides.ApplyAll(fresh, stale)
check(fresh.config.units.frames[5] == nil and stale["config/units/frames/#5/width"] == nil, "missing list entry")
check(fresh.config.chat.quiet == true and stale["config/chat/quiet"] == nil, "changed kind of value")
check(fresh.config.gone == nil and stale["config/gone/x"] == nil, "removed table")
check(fresh.config.chat.oldFlag == nil and stale["config/chat/oldFlag"] == nil, "removed key")
print("stale overrides ok")
-- Rename: saved values move from a renamed path, a value at the new path wins.
do
	local migrating = {
		["config/actionbars/enabled"] = false,
		["config/actionbars/bars"] = { "a" },
		["config/actionbarsExtra/x"] = 1, -- only a common prefix
		["config/notch/colors/restedAlpha"] = 0.7,
		["config/old"] = 1,
		["config/new"] = 2,
	}
	Overrides.Rename(migrating, "config/actionbars", "config/actionBars")
	Overrides.Rename(migrating, "config/notch/colors/restedAlpha", "config/notch/restedAlpha")
	Overrides.Rename(migrating, "config/old", "config/new")
	check(
		migrating["config/actionBars/enabled"] == false and migrating["config/actionbars/enabled"] == nil,
		"moved below"
	)
	check(migrating["config/actionBars/bars"][1] == "a", "tables move as they are")
	check(migrating["config/actionbarsExtra/x"] == 1, "a key with the same start stays")
	check(
		migrating["config/notch/restedAlpha"] == 0.7 and migrating["config/notch/colors/restedAlpha"] == nil,
		"moved itself"
	)
	check(migrating["config/new"] == 2 and migrating["config/old"] == nil, "the new path wins")
end

-- Migrate: each migration runs once per set of saved values.
do
	local runs = 0
	local migrations = {
		{ id = "rename", rename = { "config/a", "config/b" } },
		{
			id = "double",
			run = function(target)
				runs = runs + 1
				target["config/n"] = target["config/n"] * 2
			end,
		},
	}
	local migrating, done = { ["config/a"] = 1, ["config/n"] = 2 }, {}
	Overrides.Migrate(migrating, migrations, done)
	Overrides.Migrate(migrating, migrations, done)
	check(migrating["config/b"] == 1 and migrating["config/n"] == 4 and runs == 1, "ran once")
	check(done.rename and done.double, "marked done")
end

-- The shipped migrations: absolute x positions beside the group grid become offsets from its edge.
do
	local migrating = {
		["config/actionbars/iconSize"] = 70,
		["layout/targetAuras/x"] = 340,
		["layout/focus/x"] = -340,
	}
	Overrides.Migrate(migrating, Overrides.MIGRATIONS, {})
	check(migrating["config/actionBars/iconSize"] == 70, "action bar key renamed")
	check(migrating["layout/targetAuras/x"] == 9 and migrating["layout/focus/x"] == -9, "offsets from the grid edge")
end

-- A saved action bar list gets the bar names; entries past the third stay unnamed (and unused).
do
	local migrating = {
		["layout/actionBars"] = { { point = "BOTTOM" }, { point = "TOP" }, { point = "LEFT" }, { point = "RIGHT" } },
	}
	Overrides.Migrate(migrating, Overrides.MIGRATIONS, {})
	local list = migrating["layout/actionBars"]
	check(list[1].bar == "MainBar" and list[2].bar == "Bar2" and list[3].bar == "Bar3", "bars named in order")
	check(list[4].bar == nil and list[2].point == "TOP", "the rest as it was")
end
print("migrate ok")
print("overrides tests passed")
