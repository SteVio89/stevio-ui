local _, ns = ...

-- Reads keybindings, CVars and action bar toggles from the client, for the
-- profile (Settings.lua), its export, the backup and the options panel.

local config = ns.config.settings

-- GetBinding returns the command, its category and then the bound keys.
local function KeysOf(_, _, ...)
	local keys = {}
	for i = 1, select("#", ...) do
		local key = select(i, ...)
		if key then
			keys[#keys + 1] = key
		end
	end
	return keys
end

function ns.GetBindingKeys(index)
	return KeysOf(GetBinding(index))
end

-- Every bound key with its command, and the set of commands the client knows
-- this session.
function ns.BoundKeys()
	local current, commands = {}, {}
	for index = 1, GetNumBindings() do
		local command = GetBinding(index)
		if command ~= nil then
			commands[command] = true
		end
		for _, key in ipairs(ns.GetBindingKeys(index)) do
			current[key] = command
		end
	end
	return current, commands
end

-- Blizzard's name of a binding category, `fallback` for one without any.
function ns.BindingCategoryName(category, fallback)
	return category and _G[category] or category or fallback
end

local function Booleans(...)
	local list = {}
	for i = 1, select("#", ...) do
		list[i] = not not select(i, ...)
	end
	return list
end

-- Bars 2 to 8 on or off, in Blizzard's settings order.
function ns.CurrentActionBarToggles()
	return Booleans(GetActionBarToggles())
end

-- The value and default of CVar `name` if the player can change it (it exists
-- and isn't locked, secure or read-only); nil otherwise.
function ns.SettableCVar(name)
	local value, defaultValue, _, _, isLocked, isSecure, isReadOnly = C_CVar.GetCVarInfo(name)
	if value ~= nil and not isLocked and not isSecure and not isReadOnly then
		return value, defaultValue
	end
end

-- Calls `callback(name, value, defaultValue)` for every CVar the player can change.
function ns.ForEachCVar(callback)
	for _, info in ipairs(ConsoleGetAllCommands()) do
		if info.commandType == Enum.ConsoleCommandType.Cvar then
			local name = info.command
			local value, defaultValue = ns.SettableCVar(name)
			if value ~= nil then
				callback(name, value, defaultValue)
			end
		end
	end
end

-- CVars holding client state rather than preferences (config.ignoredCVars).
function ns.IsIgnoredCVar(name)
	for _, pattern in ipairs(config.ignoredCVars) do
		if name:find(pattern) then
			return true
		end
	end
	return false
end
