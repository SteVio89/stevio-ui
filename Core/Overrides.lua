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

-- Whether a saved value still fits the config: its parent table exists and it
-- doesn't change the kind of value (a code change may have removed or reshaped it).
local function Fits(roots, path, value)
	local parentPath = {}
	for i = 1, #path - 1 do
		parentPath[i] = path[i]
	end
	if type(Overrides.Get(roots, parentPath)) ~= "table" then
		return false
	end
	local current = Overrides.Get(roots, path)
	return current == nil and type(path[#path]) == "string" or current ~= nil and type(current) == type(value)
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
		local prefix = {}
		for i = 1, length do
			prefix[i] = path[i]
		end
		local encoded = Overrides.Encode(prefix)
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
	ns.RegisterEvent("ADDON_LOADED", function(_, loadedName)
		if loadedName ~= ns.name or ns.overrideRoots then
			return
		end
		StevioUIConfig = StevioUIConfig or {}
		StevioUIConfig.values = StevioUIConfig.values or {}
		StevioUIConfig.bindings = StevioUIConfig.bindings or {}
		StevioUIConfig.cvars = StevioUIConfig.cvars or {}

		ns.overrideRoots = { config = ns.config, layout = ns.layout }
		ns.overrideDefaults = Overrides.DeepCopy(ns.overrideRoots)
		ns.SafeCall(Overrides.ApplyAll, ns.overrideRoots, StevioUIConfig.values)
	end)
end
