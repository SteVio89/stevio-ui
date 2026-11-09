-- Run with: lua tests/init_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")

-- The game API Core/Init.lua touches when it loads.
function _G.GetLocale()
	return "enUS"
end
function _G.CreateFrame()
	return {
		SetScript = function() end,
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

print("init tests passed")
