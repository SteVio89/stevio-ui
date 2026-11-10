-- Run with: lua tests/keyboard_healing_test.lua  (from the repo root)
-- Runs the restricted snippets in plain Lua against stand-ins for the frame
-- handles the restricted environment hands them.
local check, loadAddonFile = dofile("tests/helpers.lua")
local ns = loadAddonFile("Modules/KeyboardHealing/Snippets.lua", { MAX_GROUPS = 8 })
local Snippets = ns.KeyboardHealingSnippets

local MAX_GROUPS, UNITS_PER_GROUP = 8, 5

local function Run(snippet, env)
	return setfenv(assert(loadstring(snippet)), env)()
end

local function Cell(shown, unit, attributes)
	attributes = attributes or {}
	attributes.unit = unit
	return {
		IsShown = function()
			return shown
		end,
		GetAttribute = function(_, name)
			return attributes[name]
		end,
	}
end

-- `sizes[g]` members shown in group g. Like the header children, every cell
-- exists; those beyond the group's size are hidden.
local function Grid(sizes)
	local refs = {}
	for g = 1, MAX_GROUPS do
		for s = 1, UNITS_PER_GROUP do
			refs["cell" .. g .. "-" .. s] = Cell(s <= (sizes[g] or 0), "unit" .. g .. "-" .. s)
		end
	end
	return refs
end

-- One arrow press: the snippet's result, the new cursor position, the unit
-- the targeter will target and whether the cursor was redrawn.
local function Press(options)
	local runs = {}
	local refs = Grid(options.sizes)
	local targeter = { attributes = {} }
	function targeter:SetAttribute(name, value)
		self.attributes[name] = value
	end
	local env = {
		cursorGroup = options.group,
		cursorSlot = options.slot,
		gridMode = options.mode or "rows",
		button = options.button,
		self = targeter,
		owner = {
			GetFrameRef = function(_, name)
				return refs[name]
			end,
			RunAttribute = function(_, name)
				runs[#runs + 1] = name
			end,
		},
		PlayerCanAssist = function(unit)
			assert(unit == "target")
			return options.canAssist ~= false
		end,
	}
	local result = Run(Snippets.NAVIGATE, env)
	return result, env.cursorGroup, env.cursorSlot, targeter.attributes.unit, runs[1] == "UpdateCursor"
end

local function Moves(options, wantGroup, wantSlot)
	local result, g, s, unit, redrawn = Press(options)
	return result == "LeftButton"
		and g == wantGroup
		and s == wantSlot
		and unit == "unit" .. wantGroup .. "-" .. wantSlot
		and redrawn
end

local FULL = { 5, 5, 5, 5, 5, 5, 5, 5 }

-- Rows: groups stack upwards, members run left to right.
check(Moves({ sizes = FULL, group = 2, slot = 3, button = "up" }, 3, 3), "rows: up is the next group")
check(Moves({ sizes = FULL, group = 2, slot = 3, button = "down" }, 1, 3), "rows: down is the previous group")
check(Moves({ sizes = FULL, group = 2, slot = 3, button = "right" }, 2, 4), "rows: right is the next member")
check(Moves({ sizes = FULL, group = 2, slot = 3, button = "left" }, 2, 2), "rows: left is the previous member")

-- Columns: groups side by side, members top to bottom.
local function Columns(button)
	return { sizes = FULL, group = 6, slot = 3, mode = "columns", button = button }
end
check(Moves(Columns("right"), 7, 3), "columns: right is the next group")
check(Moves(Columns("left"), 5, 3), "columns: left is the previous group")
check(Moves(Columns("down"), 6, 4), "columns: down is the next member")
check(Moves(Columns("up"), 6, 2), "columns: up is the previous member")

-- Empty groups are skipped, and a shorter group clamps to its last member.
local gappy = { 5, 0, 0, 2, 5 }
check(Moves({ sizes = gappy, group = 1, slot = 4, button = "up" }, 4, 2), "skips empty groups and clamps")
check(Moves({ sizes = gappy, group = 4, slot = 2, button = "up" }, 5, 2), "keeps the slot when it exists")
check(Moves({ sizes = gappy, group = 5, slot = 5, button = "down" }, 4, 2), "clamps going back")

-- At an edge the cursor stays where it is.
check(Moves({ sizes = FULL, group = 1, slot = 1, button = "down" }, 1, 1), "bottom edge")
check(Moves({ sizes = FULL, group = 8, slot = 1, button = "up" }, 8, 1), "top edge")
check(Moves({ sizes = gappy, group = 5, slot = 1, button = "up" }, 5, 1), "only empty groups above")
check(Moves({ sizes = FULL, group = 3, slot = 1, button = "left" }, 3, 1), "left edge")
check(Moves({ sizes = FULL, group = 3, slot = 5, button = "right" }, 3, 5), "right edge")
check(Moves({ sizes = { 3 }, group = 1, slot = 3, button = "right" }, 1, 3), "last member of a short group")

-- While the target isn't assistable, the first press only returns to the cursor's unit.
check(
	Moves({ sizes = FULL, group = 2, slot = 3, button = "up", canAssist = false }, 2, 3),
	"first press returns to the cursor"
)

-- A cursor on a hidden cell (or none yet) starts over at the first shown group.
check(Moves({ sizes = { 0, 3, 5 }, group = 1, slot = 2, button = "up" }, 2, 1), "hidden cell recovers")
check(Moves({ sizes = { 5, 1 }, group = 2, slot = 4, button = "right" }, 1, 1), "recovers without moving")
check(Moves({ sizes = FULL, button = "left" }, 1, 1), "no cursor yet")
local result, g, s, unit, redrawn = Press({ sizes = {}, group = 1, slot = 1, button = "up" })
check(result == false and g == 1 and s == 1 and unit == nil and not redrawn, "nobody shown")

-- A left click on a cell moves the cursor there; a right click (menu) doesn't.
local function Click(mouseButton)
	local runs = {}
	local env = {
		cursorGroup = 1,
		cursorSlot = 1,
		button = mouseButton,
		self = Cell(true, "party2", { ["stevio-group"] = 1, ["stevio-slot"] = 3 }),
		owner = {
			RunAttribute = function(_, name)
				runs[#runs + 1] = name
			end,
		},
	}
	Run(Snippets.SYNC_FROM_CLICK, env)
	return env.cursorGroup, env.cursorSlot, runs[1]
end
local ran
g, s, ran = Click("LeftButton")
check(g == 1 and s == 3 and ran == "UpdateCursor", "left click moves the cursor")
g, s, ran = Click("RightButton")
check(g == 1 and s == 1 and ran == nil, "right click leaves it")

-- The cursor frame follows the cell at the cursor, or hides without one.
local function Redraw(group, slot)
	local calls = {}
	local cursor = setmetatable({}, {
		__index = function(_, method)
			return function(_, ...)
				calls[method] = { ... }
			end
		end,
	})
	local refs = Grid(FULL)
	refs["cell2-4"].GetFrameLevel = function()
		return 5
	end
	refs.cursor = cursor
	Run(Snippets.UPDATE_CURSOR, {
		cursorGroup = group,
		cursorSlot = slot,
		self = {
			GetFrameRef = function(_, name)
				return refs[name]
			end,
		},
	})
	return calls, refs
end
local calls, refs = Redraw(2, 4)
check(calls.SetParent[1] == refs["cell2-4"] and calls.SetFrameLevel[1] == 25, "cursor on its cell")
check(calls.SetAttribute[2] == "unit2-4" and calls.Show and not calls.Hide, "cursor shows the cell's unit")
calls = Redraw(nil, nil)
check(
	calls.Hide and not calls.Show and calls.SetAttribute[1] == "unit" and calls.SetAttribute[2] == nil,
	"no cell hides it"
)

print("keyboard healing tests passed")
