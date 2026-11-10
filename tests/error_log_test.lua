-- Run with: lua tests/error_log_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")

-- Core/ErrorLog.lua registers an event and a slash command when it loads.
local ns = {
	RegisterEvent = function() end,
	RegisterSlashCommand = function() end,
}
loadAddonFile("Core/ErrorLog.lua", ns)
local ErrorLog = ns.ErrorLog

local function Entries(from, to)
	local list = {}
	for i = from, to do
		list[#list + 1] = { message = "error " .. i }
	end
	return list
end

-- Merge: this session's errors after the earlier ones.
local earlier = Entries(1, 3)
local merged = ErrorLog.Merge(earlier, Entries(4, 5))
check(merged == earlier and #merged == 5, "appended in place")
check(merged[1].message == "error 1" and merged[5].message == "error 5", "earlier entries first")
check(#ErrorLog.Merge({}, {}) == 0, "nothing to merge")

-- Capped at 50, the oldest dropped first.
merged = ErrorLog.Merge(Entries(1, 45), Entries(46, 60))
check(#merged == 50, "capped at 50")
check(merged[1].message == "error 11" and merged[50].message == "error 60", "oldest dropped first")
merged = ErrorLog.Merge({}, Entries(1, 70))
check(#merged == 50 and merged[1].message == "error 21", "a long session alone")
print("merge ok")

-- Format: numbered entries with their stack and locals, a blank line between.
local text = ErrorLog.Format({
	{ time = "2026/11/09 12:00:00", count = 2, message = "boom", stack = "at a", locals = "x = 1" },
	{ time = "2026/11/09 12:01:00", count = 1, message = "bang", stack = "at b", locals = "" },
})
check(
	text
		== "#1  2026/11/09 12:00:00  x2\nboom\nat a\nLocals:\nx = 1\n\n#2  2026/11/09 12:01:00  x1\nbang\nat b\nLocals:\n",
	"formatted: " .. text
)
check(ErrorLog.Format({}) == "", "no entries")
check(
	ErrorLog.Format({ { time = "t", message = "m" } }) == "#1  t  x1\nm\n\nLocals:\n",
	"entry without count, stack or locals"
)
print("format ok")

-- Clearing: an entry shows again with the repeats after the clear; new entries in full.
local clearedCounts = {}
local repeating = { message = "again", count = 3 }
local once = { message = "once", count = 1 }
ErrorLog.MarkCleared({ repeating, once }, clearedCounts)
check(ErrorLog.CountSinceClear(once, clearedCounts) == 0, "cleared entry hidden")
check(ErrorLog.CountSinceClear(repeating, clearedCounts) == 0, "cleared repeating entry hidden")
repeating.count = 5
check(ErrorLog.CountSinceClear(repeating, clearedCounts) == 2, "repeats after the clear shown")
check(ErrorLog.CountSinceClear({ message = "new", count = 4 }, clearedCounts) == 4, "new entry in full")
check(ErrorLog.CountSinceClear({ message = "new" }, clearedCounts) == 1, "entry without count")
print("clear ok")

print("error log tests passed")
