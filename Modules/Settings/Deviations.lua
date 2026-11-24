local _, ns = ...

-- "Your deviations" on the profile page: every override of the options
-- (StevioUIConfig.values), the keybindings and the CVars as one list of
-- area, name, old and new value. Kept free of WoW API calls so it can be
-- tested outside the game (tests/settings_deviations_test.lua).

local Overrides = ns.Overrides
local Meta = ns.SettingsMeta
local Pages = ns.ConfigPages

local Deviations = {}
ns.SettingsDeviations = Deviations

-- The name of a saved value: its label, with the table it sits in when that
-- is a list entry ("Frames 2 · Width").
local function ValueName(path)
	local label = Meta.Text(path)
	for index = #path - 1, 2, -1 do
		if type(path[index]) == "number" then
			return ("%s %d · %s"):format((Meta.Text(Overrides.Prefix(path, index - 1))), path[index], label)
		end
	end
	return label
end

-- `sources`:
--   values, defaults: the saved overrides (encoded path -> value) and the
--     code's roots { config, layout }
--   bindings, profileBindings, actionName(command), keyName(key)
--   cvars, profileCVars, cvarName(name), cvarValue(name, value)
-- Returns { kind = "value" | "binding" | "cvar", area, name, old, new, key },
-- values first (by page order), then keys, then CVars, each by name.
function Deviations.List(sources)
	local list = {}
	-- Values in page order: appearance first, then the modules.
	local rank = { style = 0 }
	for index, module in ipairs(Pages.MODULES) do
		rank[module[1]] = index
	end
	local values = {}
	for encoded, value in pairs(sources.values or {}) do
		local path = Overrides.Decode(encoded)
		local default = Overrides.Get(sources.defaults, path)
		local moduleKey = Pages.ModuleForPath(encoded)
		local module = moduleKey and Pages.Module(moduleKey)
		local meta = Meta.Lookup(path)
		local control = meta.control or Meta.Derive(path[#path], default)
		values[#values + 1] = {
			kind = "value",
			key = encoded,
			area = module and Pages.Title(module) or tostring(path[2]),
			rank = rank[moduleKey or ""] or #Pages.MODULES + 1,
			name = ValueName(path),
			old = Meta.FormatValue(default, meta, control),
			new = Meta.FormatValue(value, meta, control),
		}
	end
	table.sort(values, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		return a.name < b.name
	end)
	for _, entry in ipairs(values) do
		list[#list + 1] = entry
	end

	local keys = {}
	local profileBindings = sources.profileBindings or {}
	for key, command in pairs(sources.bindings or {}) do
		local profileCommand = profileBindings[key]
		local shown = command or profileCommand
		keys[#keys + 1] = {
			kind = "binding",
			key = key,
			area = ns.T("Keybindings", "Tastenbelegung"),
			-- The action that got the key, or the one that lost it.
			name = sources.actionName(shown),
			old = profileCommand == shown and sources.keyName(key) or "–",
			new = command and sources.keyName(key) or "–",
		}
	end
	table.sort(keys, function(a, b)
		return a.name < b.name
	end)
	for _, entry in ipairs(keys) do
		list[#list + 1] = entry
	end

	local cvars = {}
	local profileCVars = sources.profileCVars or {}
	for name, value in pairs(sources.cvars or {}) do
		cvars[#cvars + 1] = {
			kind = "cvar",
			key = name,
			area = ns.T("Graphics & game", "Grafik & Spiel"),
			name = sources.cvarName(name),
			old = profileCVars[name] and sources.cvarValue(name, profileCVars[name]) or "–",
			new = sources.cvarValue(name, value),
		}
	end
	table.sort(cvars, function(a, b)
		return a.name < b.name
	end)
	for _, entry in ipairs(cvars) do
		list[#list + 1] = entry
	end
	return list
end
