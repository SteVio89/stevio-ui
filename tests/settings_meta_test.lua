-- Run with: lua tests/settings_meta_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")

_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
local ns = { config = {} }
function ns.T(english, german)
	return ns.isGerman and german or english
end
loadAddonFile("Core/Overrides.lua", ns)
loadAddonFile("Core/Config.lua", ns)
loadAddonFile("Core/Layout.lua", ns)
local files = io.popen("ls Modules/*/Config.lua")
for path in files:lines() do
	loadAddonFile(path, ns)
end
files:close()
loadAddonFile("Modules/Settings/Profile.lua", ns)
loadAddonFile("Modules/Settings/Labels.lua", ns)
loadAddonFile("Modules/Settings/EditorModel.lua", ns)
loadAddonFile("Modules/Settings/Pages.lua", ns)
loadAddonFile("Modules/Settings/Meta.lua", ns)
local Meta, Pages, Overrides = ns.SettingsMeta, ns.ConfigPages, ns.Overrides
local roots = { config = ns.config, layout = ns.layout }

-- Keys: dots below config, a "layout." prefix, "*" for list entries.
check(Meta.Key({ "config", "group", "nameFontSize" }) == "group.nameFontSize", "config key")
check(Meta.Key({ "layout", "group", "x" }) == "layout.group.x", "layout key")
check(Meta.Key({ "config", "units", "frames", 2, "width" }) == "units.frames.2.width", "index key")
check(Meta.Key({ "config", "units", "frames", 2, "width" }, true) == "units.frames.*.width", "wildcard key")
check(Meta.Lookup({ "config", "units", "frames", 3, "width" }).control == "slider", "wildcard lookup")
check(next(Meta.Lookup({ "config", "nothing" })) == nil, "no metadata")
print("keys ok")

-- Derived controls for values without metadata.
check(Meta.Derive("x", true) == "switch", "boolean")
check(Meta.Derive("color", { 1, 0, 0 }) == "color", "color")
check(Meta.Derive("x", 3) == "stepper", "number")
check(Meta.Derive("x", "a") == "text", "text")
check(Meta.Derive("x", { "a", "b" }) == "list", "list")
check(Meta.Derive("x", {}) == "list", "empty list")
check(Meta.Derive("x", { { a = 1 } }) == "entries", "list of tables")
check(Meta.Derive("x", { a = 1 }) == "group", "table")
check(Meta.Derive("x", { point = "TOP", x = 0, y = 1 }) == "position", "position")
print("derive ok")

-- Items: sections, advanced, groups and positions.
ns.isGerman = false
local items = Meta.Items(roots, Pages.Module("group"))
local byKey = {}
for _, item in ipairs(items) do
	byKey[item.metaKey] = item
end
check(byKey["group.enabled"] == nil, "enabled is the header switch")
check(byKey["group.nameFontSize"].control == "slider" and byKey["group.nameFontSize"].section == "layout", "meta")
check(byKey["group.dispellableFilter"].advanced, "advanced")
check(byKey["layout.group"].control == "position" and byKey["layout.group"].section == "position", "position")
items = Meta.Items(roots, Pages.Module("units"))
byKey = {}
for _, item in ipairs(items) do
	byKey[item.metaKey] = item
end
local width = byKey["units.frames.2.width"]
check(width and width.group == "Frames 2 · target", "list entry group: " .. tostring(width and width.group))
check(
	byKey["units.castBar.height"].section == "castBar" and byKey["units.castBar.height"].group == nil,
	"section table"
)
check(byKey["units.frames.3.unit"].advanced, "advanced by wildcard")
items = Meta.Items(roots, Pages.Module("actionBars"))
byKey = {}
for _, item in ipairs(items) do
	byKey[item.metaKey] = item
end
check(byKey["layout.actionBars.1"].control == "position", "list of positions")
check(byKey["layout.actionBars.1.bar"].advanced, "a position's extras are advanced")
items = Meta.Items(roots, Pages.STYLE)
byKey = {}
for _, item in ipairs(items) do
	byKey[item.metaKey] = item
end
local theme = ns.config.style.theme
check(byKey["style.themes." .. theme .. ".accent"].section == "colors", "active theme colors")
for key in pairs(byKey) do
	check(not key:find("^style%.themes%.") or key:find("^style%.themes%." .. theme), "only the active theme: " .. key)
end
check(byKey["style.theme"] == nil and byKey["style.palette"] == nil, "hidden")
print("items ok")

-- Changed values.
local defaults = Overrides.DeepCopy(roots)
items = Meta.Items(roots, Pages.Module("group"))
check(Meta.ChangedCount(items, roots, defaults) == 0, "nothing changed")
ns.config.group.nameFontSize = 12
ns.layout.group.y = ns.layout.group.y + 10
check(Meta.ChangedCount(items, roots, defaults) == 2, "two changed")
ns.config.group.nameFontSize = defaults.config.group.nameFontSize
ns.layout.group.y = defaults.layout.group.y
print("changed ok")

-- Formatting and clamping.
check(Meta.FormatValue(0.38, { percent = true }) == "38 %", "percent")
check(Meta.FormatValue(12, { unit = "px" }) == "12 px", "unit")
check(Meta.FormatValue(1.5, {}) == "1.5", "decimal")
check(Meta.FormatValue(true, {}) == "on", "boolean")
check(Meta.FormatValue({ 1, 1, 1, 0.35 }, {}, "color") == "#FFFFFF · 35 %", "color with alpha")
check(Meta.FormatValue({ 0.24, 0.55, 1, 1 }, {}, "color") == "#3D8CFF", "color")
check(Meta.FormatValue({ point = "BOTTOM", x = 0, y = 176 }, {}) == "Bottom centre 0, 176", "position")
check(Meta.FormatValue({ "a", "b" }, {}) == "a, b", "list")
check(Meta.FormatValue(2, { options = { { 2, { "Two", "Zwei" } } } }) == "Two", "option")
check(Meta.Clamp(17, { min = 8, max = 16, step = 1 }) == 16, "clamp max")
check(Meta.Clamp(0.333, { min = 0, max = 1, step = 0.05 }) == 0.35, "snap to step")
check(Meta.Clamp(11.4, { min = 8, max = 16, step = 1 }) == 11, "round")
print("values ok")

-- No metadata for values that don't exist.
local unknown = Meta.UnknownKeys(roots)
check(#unknown == 0, "metadata for missing values: " .. table.concat(unknown, ", "))
print("metadata keys exist")

-- Completeness: every visible setting has a label, a help text and a section
-- its page declares; ranges hold the default.
local problems = {}
local function Report(text)
	problems[#problems + 1] = text
end
local modules = { Pages.STYLE }
for _, module in ipairs(Pages.MODULES) do
	modules[#modules + 1] = module
end
for _, language in ipairs({ false, true }) do
	ns.isGerman = language
	for _, module in ipairs(modules) do
		for _, item in ipairs(Meta.Items(roots, module)) do
			if not item.advanced then
				if not item.help or item.help == "" then
					Report("help: " .. item.metaKey)
				end
				if not Pages.Section(module, item.section) then
					Report("section: " .. item.metaKey .. " (" .. tostring(item.section) .. ")")
				end
				local hasLabel = ns.HasConfigPathLabel(item.metaKey)
					or ns.HasConfigPathLabel(Meta.Key(item.path, true))
					or ns.HasConfigLabel(item.key)
					or type(item.key) == "number"
				if not hasLabel then
					Report("label: " .. item.metaKey)
				end
			end
			local meta, value = item.meta, Overrides.Get(roots, item.path)
			if type(value) == "number" and meta.min and (value < meta.min or value > meta.max) then
				Report("default outside range: " .. item.metaKey)
			end
		end
	end
end
table.sort(problems)
local seen, unique = {}, {}
for _, problem in ipairs(problems) do
	if not seen[problem] then
		seen[problem] = true
		unique[#unique + 1] = problem
	end
end
check(#unique == 0, #unique .. " incomplete settings:\n" .. table.concat(unique, "\n"))
print("every visible setting complete")

print("settings meta tests passed")
