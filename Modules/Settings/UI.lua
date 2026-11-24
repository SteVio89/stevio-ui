local _, ns = ...

-- Shared state of the settings window (Window.lua and the Page*.lua files):
-- reading and writing config values as overrides (Core/Overrides.lua), the
-- changes of this session that wait for a reload, and the cached items of
-- each page (Meta.Items).

local Overrides = ns.Overrides
local Meta = ns.SettingsMeta
local Pages = ns.ConfigPages

local UI = {}
ns.SettingsUI = UI

UI.T = ns.T

-- Values ---------------------------------------------------------------------

function UI.Roots()
	return ns.overrideRoots
end

function UI.Value(path)
	return Overrides.Get(ns.overrideRoots, path)
end

function UI.Default(path)
	return Overrides.Get(ns.overrideDefaults, path)
end

function UI.IsChanged(item)
	return Meta.IsChanged(item, ns.overrideRoots, ns.overrideDefaults)
end

-- Changes of this session that only take effect after a reload: encoded path
-- -> { label, module, start = the value before the first change }.
local pending = {}
local listeners = {}

-- `fn()` runs after every change made in the window (redraws).
function UI.OnChange(fn)
	listeners[#listeners + 1] = fn
end

local function Changed()
	for _, fn in ipairs(listeners) do
		ns.SafeCall(fn)
	end
end

-- Remembers a change for the reload bar; one back at its starting value drops out.
local function Track(path, label, live, before)
	if live then
		return
	end
	local encoded = Overrides.Encode(path)
	local entry = pending[encoded]
	if not entry then
		entry = { label = label, module = Pages.ModuleForPath(encoded), start = Overrides.DeepCopy(before) }
		pending[encoded] = entry
	end
	if Overrides.Equal(UI.Value(path), entry.start) then
		pending[encoded] = nil
	end
	UI.reloadDismissed = false
end

-- Writes `value` at `path` and saves it as an override (or drops the
-- override when it is the default again).
local function Write(path, value, label, live)
	local before = UI.Value(path)
	if Overrides.Equal(before, value) then
		return false
	end
	Overrides.Put(ns.overrideRoots, path, value)
	Overrides.Record(StevioUIConfig.values, ns.overrideDefaults, ns.overrideRoots, path)
	Track(path, label, live, before)
	return true
end
UI.Write = Write

-- Sets the value of a settings item (Meta.Items).
function UI.Set(item, value)
	if Write(item.path, value, item.label, item.meta.live) then
		if item.control == "list" or item.control == "entries" then
			UI.InvalidateItems()
		end
		Changed()
	end
end

-- Sets some fields (point, x, y) of a position item.
function UI.SetFields(item, fields)
	local changed = false
	for key, value in pairs(fields) do
		changed = Write(Overrides.Child(item.path, key), value, item.label, item.meta.live) or changed
	end
	if changed then
		Changed()
	end
end

-- Back to the code's value: removes only this item's override.
function UI.Reset(item)
	if item.control == "position" then
		local default = UI.Default(item.path)
		UI.SetFields(item, { point = default.point, x = default.x, y = default.y })
		return
	end
	UI.Set(item, Overrides.DeepCopy(UI.Default(item.path)))
end

-- Every override of a module page (config and its positions) back to the code.
function UI.ResetModule(module)
	local items = UI.Items(module)
	local changed = false
	for _, item in ipairs(items) do
		if UI.IsChanged(item) then
			if item.control == "position" then
				local default = UI.Default(item.path)
				for _, key in ipairs({ "point", "x", "y" }) do
					changed = Write(Overrides.Child(item.path, key), default[key], item.label) or changed
				end
			else
				changed = Write(item.path, Overrides.DeepCopy(UI.Default(item.path)), item.label) or changed
			end
		end
	end
	UI.InvalidateItems()
	if changed then
		Changed()
	end
end

-- The module's own `enabled`: the page's header switch and the start tiles.
function UI.SetEnabled(key, enabled)
	if Write({ "config", key, "enabled" }, enabled, Pages.Title(Pages.Module(key))) then
		Changed()
	end
end

function UI.IsEnabled(key)
	local config = ns.config[key]
	return not config or config.enabled ~= false
end

-- Writes overrides that come from outside a page (an import) and redraws once.
function UI.WriteMany(entries)
	for _, entry in ipairs(entries) do
		Write(entry.path, entry.value, entry.label)
	end
	UI.InvalidateItems()
	Changed()
end

-- Reload bar ------------------------------------------------------------------

-- The waiting changes as { label } sorted by module, a module with several
-- of them as one entry "Chat (2)".
function UI.PendingChanges()
	local byModule, order = {}, {}
	local count = 0
	for _, entry in pairs(pending) do
		count = count + 1
		local key = entry.module or "?"
		if not byModule[key] then
			byModule[key] = {}
			order[#order + 1] = key
		end
		table.insert(byModule[key], entry.label)
	end
	table.sort(order)
	local names = {}
	for _, key in ipairs(order) do
		local labels = byModule[key]
		if #labels == 1 then
			names[#names + 1] = labels[1]
		else
			local module = Pages.Module(key)
			names[#names + 1] = ("%s (%d)"):format(module and Pages.Title(module) or key, #labels)
		end
	end
	return count, names
end

-- Items ----------------------------------------------------------------------

local itemCache = {}

-- The settings of a module page (Meta.Items), cached until a list grows or
-- shrinks or the theme changes.
function UI.Items(module)
	local key = module[1]
	if key == "style" then
		key = "style:" .. tostring(ns.config.style.theme)
	end
	local items = itemCache[key]
	if not items then
		items = Meta.Items(ns.overrideRoots, module)
		itemCache[key] = items
	end
	return items
end

function UI.InvalidateItems()
	itemCache = {}
end

-- How many settings of a module differ from the code.
function UI.ChangedCount(module)
	return Meta.ChangedCount(UI.Items(module), ns.overrideRoots, ns.overrideDefaults)
end

-- The add-on's version, without the packager's placeholder in a checkout.
function UI.Version()
	local version = C_AddOns.GetAddOnMetadata(ns.name, "Version")
	if not version or version:find("^@") then
		return "dev"
	end
	return version
end

-- Window state (position, size, options), saved account-wide.
function UI.SavedState()
	StevioUIConfig.settingsWindow = StevioUIConfig.settingsWindow or {}
	return StevioUIConfig.settingsWindow
end
