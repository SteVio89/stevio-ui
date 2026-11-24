-- Run with: lua tests/settings_search_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")

_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
local ns = { config = {}, isGerman = true }
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
for _, file in ipairs({ "Profile", "Labels", "EditorModel", "Pages", "Meta", "Search" }) do
	loadAddonFile("Modules/Settings/" .. file .. ".lua", ns)
end
local Search, Meta, Overrides = ns.SettingsSearch, ns.SettingsMeta, ns.Overrides
local roots = { config = ns.config, layout = ns.layout }

local function Entries()
	return Search.Entries(function(module)
		return Meta.Items(roots, module)
	end)
end
local function ValueOf(entry)
	return Search.ValueText(entry, Overrides.Get(roots, entry.item.path))
end

-- Lowering keeps umlauts and lengths.
check(Search.Lower("ÄNDERUNG Über") == "änderung über", "umlauts lowered")
check(#Search.Lower("Größe") == #"Größe", "same length")
print("lower ok")

-- "abstand" finds gaps in several modules, case-insensitive, by name and help.
local entries = Entries()
local result = Search.Run(entries, "  Abstand ")
check(result.total >= 9, "gaps found: " .. result.total)
check(#result.groups >= 5, "in several areas: " .. #result.groups)
local modules = {}
for index, group in ipairs(result.groups) do
	modules[group.module] = index
	check(#group.entries > 0 and group.title ~= "", "group " .. group.module)
end
check(modules.units and modules.group and modules.chat and modules.notch, "the expected modules")
check(modules.units < modules.group and modules.group < modules.chat, "page order")
local spacing
for _, entry in ipairs(result.groups[modules.group].entries) do
	if entry.item.metaKey == "group.spacing" then
		spacing = entry
	end
end
check(spacing and spacing.path == "Aufbau", "path is the section: " .. tostring(spacing and spacing.path))
print("abstand ok")

-- Advanced settings are found and marked; groups are part of the path.
result = Search.Run(entries, "filter")
local advanced
for _, group in ipairs(result.groups) do
	for _, entry in ipairs(group.entries) do
		if entry.item.metaKey == "group.dispellableFilter" then
			advanced = entry
		end
	end
end
check(advanced and advanced.item.advanced and advanced.path == "Erweitert", "advanced found")
result = Search.Run(entries, "Fenster 2 · target")
check(result.total > 0, "found by the group of a list entry")
print("advanced ok")

-- Values, module names and English.
result = Search.Run(entries, "#3D8CFF", ValueOf)
check(result.total == 1 and result.groups[1].entries[1].item.metaKey == "group.dispelColor", "found by value")
check(Search.Run(entries, "#3D8CFF").total == 0, "values only with valueOf")
result = Search.Run(entries, "beuteticker")
check(result.groups[1] and result.groups[1].module == "lootTicker", "found by module name")
check(Search.Run(entries, "").total == 0 and Search.Run(entries, "   ").total == 0, "empty query")
check(Search.Run(entries, "xyzzy").total == 0, "nothing found")
ns.isGerman = false
result = Search.Run(Entries(), "gap")
check(result.total >= 9, "English: " .. result.total)
ns.isGerman = true
print("values ok")

-- Highlighting keeps the original spelling.
check(Search.Highlight("Zeilenabstand", "ABSTAND", "<", ">") == "Zeilen<abstand>", "highlight inside a word")
check(Search.Highlight("Abstand zum Abstand", "abstand", "<", ">") == "<Abstand> zum <Abstand>", "every match")
check(Search.Highlight("Größe", "GRÖ", "<", ">") == "<Grö>ße", "umlauts")
check(Search.Highlight("Text", "", "<", ">") == "Text", "empty query")
print("highlight ok")

print("settings search tests passed")
