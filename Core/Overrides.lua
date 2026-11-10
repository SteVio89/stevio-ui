local _, ns = ...

-- The options panel's overrides on top of the code: the Config.lua and
-- Layout.lua tables, the keybindings and the CVars of Profile.lua are the
-- defaults, and the saved overrides (account-wide, StevioUIConfig) replace
-- single values of them. Everything but the WoW glue at the bottom is pure and
-- unit tested (tests/overrides_test.lua).
--
-- A value is addressed by its path from a root table, e.g.
-- { "config", "units", "frames", 2, "width" }. SavedVariables keys must be
-- strings, so paths are stored encoded: "config/units/frames/#2/width".

local Overrides = {}
ns.Overrides = Overrides

function Overrides.Encode(path)
	local parts = {}
	for i, key in ipairs(path) do
		parts[i] = type(key) == "number" and ("#" .. key) or key
	end
	return table.concat(parts, "/")
end

function Overrides.Decode(encoded)
	local path = {}
	for part in encoded:gmatch("[^/]+") do
		local index = part:match("^#(%d+)$")
		path[#path + 1] = index and tonumber(index) or part
	end
	return path
end

function Overrides.DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in pairs(value) do
		copy[key] = Overrides.DeepCopy(inner)
	end
	return copy
end

function Overrides.Equal(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for key, value in pairs(a) do
		if not Overrides.Equal(value, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

-- A table holding only the keys 1..n (also an empty one).
function Overrides.IsList(value)
	if type(value) ~= "table" then
		return false
	end
	local count = 0
	for _ in pairs(value) do
		count = count + 1
	end
	return count == #value
end

-- A new path of the first `n` keys of `path`.
function Overrides.Prefix(path, n)
	local prefix = {}
	for i = 1, n do
		prefix[i] = path[i]
	end
	return prefix
end

-- A new path one step below `path`.
function Overrides.Child(path, key)
	local child = Overrides.Prefix(path, #path)
	child[#child + 1] = key
	return child
end

-- The value at `path` below `roots` (nil when any step is missing).
function Overrides.Get(roots, path)
	local value = roots
	for _, key in ipairs(path) do
		if type(value) ~= "table" then
			return nil
		end
		value = value[key]
	end
	return value
end

-- Writes `value` at `path`. A table goes into the existing table in place, so
-- the references other files keep to config tables stay valid.
function Overrides.Put(roots, path, value)
	local parent = roots
	for i = 1, #path - 1 do
		local key = path[i]
		if type(parent[key]) ~= "table" then
			parent[key] = {}
		end
		parent = parent[key]
	end
	local key = path[#path]
	local current = parent[key]
	if type(value) == "table" and type(current) == "table" then
		for inner in pairs(current) do
			current[inner] = nil
		end
		for inner, innerValue in pairs(value) do
			current[inner] = Overrides.DeepCopy(innerValue)
		end
	else
		parent[key] = Overrides.DeepCopy(value)
	end
end

-- Whether a saved value still fits the config: its key exists and it doesn't
-- change the kind of value (a code change may have removed or reshaped it).
-- The options panel only edits existing keys; list entries it adds are saved
-- with their whole list, which is applied first.
local function Fits(roots, path, value)
	local current = Overrides.Get(roots, path)
	return current ~= nil and type(current) == type(value)
end

-- Applies all saved values; shorter paths first, so a replaced list is in
-- place before edits inside it. Values that no longer fit the config are
-- dropped from `values`.
function Overrides.ApplyAll(roots, values)
	local keys = {}
	for encoded in pairs(values) do
		keys[#keys + 1] = encoded
	end
	table.sort(keys, function(a, b)
		local depthA, depthB = select(2, a:gsub("/", "")), select(2, b:gsub("/", ""))
		if depthA ~= depthB then
			return depthA < depthB
		end
		return a < b
	end)
	for _, encoded in ipairs(keys) do
		local path = Overrides.Decode(encoded)
		if Fits(roots, path, values[encoded]) then
			Overrides.Put(roots, path, values[encoded])
		else
			values[encoded] = nil
		end
	end
end

-- The encoded path of the saved value at or above `path`, if any.
function Overrides.OverriddenAt(values, path)
	for length = #path, 1, -1 do
		local encoded = Overrides.Encode(Overrides.Prefix(path, length))
		if values[encoded] ~= nil then
			return encoded
		end
	end
end

local function RemoveBelow(values, encoded)
	local prefix = encoded .. "/"
	for key in pairs(values) do
		if key:sub(1, #prefix) == prefix then
			values[key] = nil
		end
	end
end

-- Saves the live value at `path` (already changed in `roots`) as an override,
-- or drops the override when it equals the default again. Inside a value that
-- is saved as a whole (a list that was grown or shrunk), that value is saved
-- again instead.
function Overrides.Record(values, defaults, roots, path)
	local whole = Overrides.OverriddenAt(values, path)
	if whole and whole ~= Overrides.Encode(path) and type(values[whole]) == "table" then
		path = Overrides.Decode(whole)
	end
	local encoded = Overrides.Encode(path)
	local live = Overrides.Get(roots, path)
	RemoveBelow(values, encoded)
	if Overrides.Equal(live, Overrides.Get(defaults, path)) then
		values[encoded] = nil
	else
		values[encoded] = Overrides.DeepCopy(live)
	end
end

-- Moves saved values in `values` from the encoded path `old` (and below it)
-- to `new`. A value already saved at the new path wins.
function Overrides.Rename(values, old, new)
	local moves = {}
	for encoded in pairs(values) do
		if encoded == old or encoded:sub(1, #old + 1) == old .. "/" then
			moves[encoded] = new .. encoded:sub(#old + 1)
		end
	end
	for from, to in pairs(moves) do
		if values[to] == nil then
			values[to] = values[from]
		end
		values[from] = nil
	end
end

-- Half the group grid's width when targetAuras and focus still had absolute
-- x positions (8 cells of 80 and 7 gaps of 3, rounded up).
local OLD_GROUP_HALF_WIDTH = 331

-- Changes to the config's shape that saved values have to follow, oldest
-- first. Each runs once on a set of saved values: `rename` moves a path (see
-- Overrides.Rename), `run(values)` changes them in place.
Overrides.MIGRATIONS = {
	{ id = "actionBarsKey", rename = { "config/actionbars", "config/actionBars" } },
	{ id = "restedAlpha", rename = { "config/notch/colors/restedAlpha", "config/notch/restedAlpha" } },
	{
		-- targetAuras and focus count their x from the group grid's edge now.
		id = "besideGroupOffsets",
		run = function(values)
			local auras, focus = values["layout/targetAuras/x"], values["layout/focus/x"]
			if type(auras) == "number" then
				values["layout/targetAuras/x"] = auras - OLD_GROUP_HALF_WIDTH
			end
			if type(focus) == "number" then
				values["layout/focus/x"] = focus + OLD_GROUP_HALF_WIDTH
			end
		end,
	},
}

-- Runs the migrations not yet in `done` (a set of ids, saved with the values)
-- on `values` and adds them to it.
function Overrides.Migrate(values, migrations, done)
	for _, migration in ipairs(migrations) do
		if not done[migration.id] then
			if migration.rename then
				Overrides.Rename(values, migration.rename[1], migration.rename[2])
			else
				migration.run(values)
			end
			done[migration.id] = true
		end
	end
end

-- Keybindings and CVars are flat maps (key -> command, CVar -> value); their
-- overrides hold what differs from the profile, `false` meaning "removed".
function Overrides.Merge(profile, overrides)
	local merged = {}
	for key, value in pairs(profile) do
		merged[key] = value
	end
	for key, value in pairs(overrides) do
		if value == false then
			merged[key] = nil
		else
			merged[key] = value
		end
	end
	return merged
end

-- The overrides turning `profile` into `current`.
function Overrides.Diff(profile, current)
	local overrides = {}
	for key, value in pairs(current) do
		if profile[key] ~= value then
			overrides[key] = value
		end
	end
	for key in pairs(profile) do
		if current[key] == nil then
			overrides[key] = false
		end
	end
	return overrides
end

-- WoW glue: the saved overrides go into the config once the saved variables
-- are loaded, before any module is enabled (PLAYER_LOGIN).
if ns.RegisterEvent then
	local function OnAddonLoaded(_, loadedName)
		if loadedName ~= ns.name then
			return
		end
		ns.UnregisterEvent("ADDON_LOADED", OnAddonLoaded)
		StevioUIConfig = StevioUIConfig or {}
		StevioUIConfig.values = StevioUIConfig.values or {}
		StevioUIConfig.bindings = StevioUIConfig.bindings or {}
		StevioUIConfig.cvars = StevioUIConfig.cvars or {}
		StevioUIConfig.migrations = StevioUIConfig.migrations or {}

		ns.overrideRoots = { config = ns.config, layout = ns.layout }
		ns.overrideDefaults = Overrides.DeepCopy(ns.overrideRoots)
		ns.SafeCall(Overrides.Migrate, StevioUIConfig.values, Overrides.MIGRATIONS, StevioUIConfig.migrations)
		ns.SafeCall(Overrides.ApplyAll, ns.overrideRoots, StevioUIConfig.values)
	end
	ns.RegisterEvent("ADDON_LOADED", OnAddonLoaded)
end
