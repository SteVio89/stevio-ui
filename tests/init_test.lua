-- Run with: lua tests/init_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")

-- The game API Core/Init.lua touches when it loads.
function _G.GetLocale()
	return "enUS"
end
local onEvent
function _G.CreateFrame()
	return {
		SetScript = function(_, _, handler)
			onEvent = handler
		end,
		RegisterEvent = function() end,
		UnregisterEvent = function() end,
	}
end
_G.SlashCmdList = {}

local ns = loadAddonFile("Core/Init.lua")

-- ParseSlash: the command name lowercased, the rest trimmed.
local function Parsed(input, name, rest)
	local gotName, gotRest = ns.ParseSlash(input)
	check(gotName == name and gotRest == rest, ("%q -> %q, %q"):format(input, gotName, gotRest))
end
Parsed("config", "config", "")
Parsed("Config", "config", "")
Parsed("  errors   clear  ", "errors", "clear")
Parsed("bars Set Two  words", "bars", "Set Two  words")
Parsed("", "", "")
Parsed("   ", "", "")
Parsed("\texport\t", "export", "")
print("slash parsing ok")

-- The slash command runs the matching handler with the rest.
local received
ns.RegisterSlashCommand("errors", function(rest)
	received = rest
end)
SlashCmdList.STEVIOUI(" ERRORS clear ")
check(received == "clear", "handler called with the rest")
print("slash dispatch ok")

-- T picks by client language.
check(ns.T("Yes", "Ja") == "Yes", "English client")
ns.isGerman = true
check(ns.T("Yes", "Ja") == "Ja", "German client")
print("translations ok")

-- RunAfterCombat: immediate outside combat; in combat queued until it ends,
-- a function queued again running once at its latest position.
local inCombat = false
function _G.InCombatLockdown()
	return inCombat
end
local ran = {}
local function A()
	ran[#ran + 1] = "A"
end
local function B()
	ran[#ran + 1] = "B"
end
ns.RunAfterCombat(A)
check(ran[1] == "A", "runs at once outside combat")
ran, inCombat = {}, true
ns.RunAfterCombat(A)
ns.RunAfterCombat(B)
ns.RunAfterCombat(A)
check(#ran == 0, "waits during combat")
inCombat = false
onEvent(nil, "PLAYER_REGEN_ENABLED")
check(table.concat(ran, " ") == "B A", "repeated function runs once, last")
ran = {}
onEvent(nil, "PLAYER_REGEN_ENABLED")
check(#ran == 0, "queue emptied")
print("combat queue ok")

-- UnregisterEvent: a handler can remove itself while the event is dispatched.
local calls = 0
local function Once()
	calls = calls + 1
	ns.UnregisterEvent("TEST_EVENT", Once)
end
local afterCalls = 0
ns.RegisterEvent("TEST_EVENT", Once)
ns.RegisterEvent("TEST_EVENT", function()
	afterCalls = afterCalls + 1
end)
onEvent(nil, "TEST_EVENT")
onEvent(nil, "TEST_EVENT")
check(calls == 1 and afterCalls == 2, "unregister during dispatch")
print("event unregistering ok")

-- A failing handler is reported and doesn't skip the handlers after it.
local reported = {}
function _G.geterrorhandler()
	return function(err)
		reported[#reported + 1] = err
	end
end
local afterFailing = 0
ns.RegisterEvent("FAIL_EVENT", function()
	error("handler broke")
end)
ns.RegisterEvent("FAIL_EVENT", function()
	afterFailing = afterFailing + 1
end)
onEvent(nil, "FAIL_EVENT")
check(afterFailing == 1, "handler after a failing one still runs")
check(#reported == 1 and reported[1]:find("handler broke", 1, true), "handler error reported")
print("handler isolation ok")

-- A failing module is reported and doesn't keep the later ones from enabling.
reported = {}
local enabled = {}
ns.config.off = { enabled = false }
ns.RegisterModule("broken", {
	OnEnable = function()
		error("module broke")
	end,
})
ns.RegisterModule("off", {
	OnEnable = function()
		enabled[#enabled + 1] = "off"
	end,
})
ns.RegisterModule("last", {
	OnEnable = function(self)
		enabled[#enabled + 1] = self.name
	end,
})
local layoutApplied = false
function ns.ApplyEditModeLayout()
	layoutApplied = true
end
_G.StevioUIState = { consented = true }
onEvent(nil, "PLAYER_LOGIN")
check(table.concat(enabled, " ") == "last", "later module enabled, disabled one skipped")
check(layoutApplied, "layout applied after a failing module")
check(#reported == 1 and reported[1]:find("module broke", 1, true), "module error reported")
print("module isolation ok")

-- Module commands: listed always, run only for a module that enabled.
do
	ns.isGerman = false
	local commandRuns, printed = {}, {}
	local realPrint = print
	_G.print = function(line)
		printed[#printed + 1] = line
	end
	for _, name in ipairs({ "last", "off", "broken" }) do
		ns.RegisterModuleCommand(name, name, function(input)
			commandRuns[#commandRuns + 1] = name .. ":" .. input
		end)
	end
	SlashCmdList.STEVIOUI("last now")
	SlashCmdList.STEVIOUI("off")
	SlashCmdList.STEVIOUI("broken")
	_G.print = realPrint
	check(table.concat(commandRuns, " ") == "last:now", "only the enabled module's command runs")
	check(#printed == 2 and printed[1]:find("off is turned off", 1, true), "the others say the module is off")
end
print("module commands ok")

print("init tests passed")
