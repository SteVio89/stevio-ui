-- Run with: lua tests/settings_client_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")

-- A client with a few bindings, action bars and CVars.
local bindings = {
	{ "HEADER_BLANK", "BINDING_HEADER_MOVEMENT" },
	{ "MOVEFORWARD", "BINDING_HEADER_MOVEMENT", "W", "UP" },
	{ "JUMP", "BINDING_HEADER_MOVEMENT", "SPACE", nil, "NUMPAD0" },
	{ "SIT", "BINDING_HEADER_MOVEMENT" },
}
function _G.GetNumBindings()
	return #bindings
end
function _G.GetBinding(index)
	return unpack(bindings[index], 1, 5)
end
function _G.GetActionBarToggles()
	return true, nil, 1, false
end
_G.BINDING_HEADER_MOVEMENT = "Movement"
_G.Enum = { ConsoleCommandType = { Cvar = 0, Command = 1 } }
local cvars = {
	graphicsQuality = { "5", "3" },
	lastCharacterIndex = { "2", "0" },
	locked = { "1", "0", true },
	secure = { "1", "0", false, true },
	readOnly = { "1", "0", false, false, true },
}
_G.C_CVar = {
	GetCVarInfo = function(name)
		local info = cvars[name]
		if info then
			return info[1], info[2], nil, nil, info[3], info[4], info[5]
		end
	end,
}
function _G.ConsoleGetAllCommands()
	return {
		{ command = "graphicsQuality", commandType = Enum.ConsoleCommandType.Cvar },
		{ command = "locked", commandType = Enum.ConsoleCommandType.Cvar },
		{ command = "secure", commandType = Enum.ConsoleCommandType.Cvar },
		{ command = "readOnly", commandType = Enum.ConsoleCommandType.Cvar },
		{ command = "reloadui", commandType = Enum.ConsoleCommandType.Command },
	}
end

local ns = { config = {} }
loadAddonFile("Modules/Settings/Config.lua", ns)
loadAddonFile("Modules/Settings/Model.lua", ns)
loadAddonFile("Modules/Settings/Client.lua", ns)

-- GetBindingKeys: the keys after command and category, without gaps.
check(#ns.GetBindingKeys(1) == 0, "header without keys")
local keys = ns.GetBindingKeys(2)
check(#keys == 2 and keys[1] == "W" and keys[2] == "UP", "two keys")
keys = ns.GetBindingKeys(3)
check(#keys == 2 and keys[1] == "SPACE" and keys[2] == "NUMPAD0", "a nil key skipped")
print("binding keys ok")

-- BoundKeys: key -> command, and every command the client knows.
local current, commands = ns.BoundKeys()
check(current.W == "MOVEFORWARD" and current.UP == "MOVEFORWARD" and current.NUMPAD0 == "JUMP", "bound keys")
check(current.SIT == nil and commands.SIT and commands.HEADER_BLANK, "commands without keys known")
print("bound keys ok")

check(ns.BindingCategoryName("BINDING_HEADER_MOVEMENT", "?") == "Movement", "category name")
check(ns.BindingCategoryName("UNKNOWN_HEADER", "?") == "UNKNOWN_HEADER", "unknown category as it is")
check(ns.BindingCategoryName(nil, "Other") == "Other", "fallback")
print("category names ok")

local toggles = ns.CurrentActionBarToggles()
check(#toggles == 4, "one per bar")
check(toggles[1] == true and toggles[2] == false and toggles[3] == true and toggles[4] == false, "as booleans")
print("action bars ok")

-- SettableCVar and ForEachCVar: locked, secure and read-only CVars are left out.
local value, default = ns.SettableCVar("graphicsQuality")
check(value == "5" and default == "3", "settable")
check(ns.SettableCVar("locked") == nil and ns.SettableCVar("secure") == nil, "locked or secure")
check(ns.SettableCVar("readOnly") == nil and ns.SettableCVar("missing") == nil, "read-only or missing")
local seen = {}
ns.ForEachCVar(function(name, cvarValue, defaultValue)
	seen[#seen + 1] = name .. "=" .. cvarValue .. "/" .. defaultValue
end)
check(#seen == 1 and seen[1] == "graphicsQuality=5/3", "only settable CVars: " .. table.concat(seen, ", "))
print("cvars ok")

check(ns.IsIgnoredCVar("lastCharacterIndex") and not ns.IsIgnoredCVar("graphicsQuality"), "ignored CVars")
print("ignored cvars ok")

print("settings client tests passed")
