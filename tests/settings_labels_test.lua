-- Run with: lua tests/settings_labels_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")

local ns = { config = {} }
loadAddonFile("Core/Overrides.lua", ns)
loadAddonFile("Modules/Settings/Labels.lua", ns)
loadAddonFile("Modules/Settings/EditorModel.lua", ns)
local Model = ns.EditorModel

-- ConfigLabel: the label table, in both languages, with help text.
ns.isGerman = false
local label, help = ns.ConfigLabel("alertGap")
check(label == "Toast gap" and help:find("^Gap between"), "English label and help")
label, help = ns.ConfigLabel("fadeInTime")
check(label == "Fade-in (s)" and help == nil, "label without help")
ns.isGerman = true
label, help = ns.ConfigLabel("alertGap")
check(label == "Abstand Hinweise" and help:find("^Abstand zwischen"), "German label and help")
check(ns.ConfigLabel("fadeInTime") == "Einblenden (s)", "German label")
print("labels ok")

-- Keys without a label: camelCase becomes words, upper-case keys and numbers stay.
ns.isGerman = false
check(ns.ConfigLabel("someNewKey") == "Some new key", "camelCase to words")
check(ns.ConfigLabel("plain") == "Plain", "single word")
check(ns.ConfigLabel("iconSizeXL") == "Icon size xl", "trailing capitals")
check(ns.ConfigLabel("CHAT_MSG_SAY") == "CHAT_MSG_SAY", "all caps")
check(ns.ConfigLabel("BN2") == "BN2", "caps and digits")
check(ns.ConfigLabel(3) == "3", "numeric key")
check(select("#", ns.ConfigLabel("someNewKey")) == 1, "no help for words")
ns.isGerman = true
check(ns.ConfigLabel("someNewKey") == "Some new key", "words in German too")
print("words ok")

-- IsColor: 3 or 4 numbers between 0 and 1 under a named key.
check(Model.IsColor("color", { 0.1, 0.2, 0.3 }), "rgb")
check(Model.IsColor("color", { 0, 0, 0, 1 }), "rgba")
check(not Model.IsColor(2, { 0, 0, 0 }), "list entry is no color")
check(not Model.IsColor("color", { 0, 0 }), "too short")
check(not Model.IsColor("color", { 0, 0, 0, 0, 0 }), "too long")
check(not Model.IsColor("color", { 0, 2, 0 }), "out of range")
check(not Model.IsColor("color", { "a", 0, 0 }), "not a number")
check(not Model.IsColor("color", { r = 1, g = 1, b = 1 }), "not a list")
check(not Model.IsColor("color", 1), "not a table")
print("colors ok")

-- SortedKeys: enabled first, then plain values, then tables, each by label.
ns.isGerman = false
local keys = Model.SortedKeys({
	zeta = { a = 1 },
	enabled = true,
	width = 1,
	color = { 1, 1, 1 },
	alpha = { 1, 2, 3, 4, 5 },
	height = 2,
})
local order = table.concat(keys, " ")
check(order == "enabled color height width alpha zeta", "display order: " .. order)
-- By label, not by key: "x" is "X offset", which comes after "Width".
keys = Model.SortedKeys({ x = 1, width = 1, alertGap = 1 })
check(table.concat(keys, " ") == "alertGap width x", "sorted by label")
keys = Model.SortedKeys({ "c", "a", "b" })
check(#keys == 3 and keys[1] == 1 and keys[3] == 3, "lists keep their order")
print("sorted keys ok")

-- Every config key the editor shows has an entry in Labels.lua.
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
loadAddonFile("Core/Config.lua", ns)
loadAddonFile("Core/Layout.lua", ns)
local files = io.popen("ls Modules/*/Config.lua")
for path in files:lines() do
	loadAddonFile(path, ns)
end
files:close()
loadAddonFile("Modules/Settings/Profile.lua", ns)

local missing = {}
local function Walk(path, value)
	if Model.HIDDEN[ns.Overrides.Encode(path)] then
		return
	end
	local key = path[#path]
	if type(key) == "string" and not key:match("^[%u%d_]+$") and not ns.HasConfigLabel(key) then
		missing[#missing + 1] = ns.Overrides.Encode(path)
	end
	if type(value) == "table" and not Model.IsColor(key, value) then
		for childKey, child in pairs(value) do
			Walk(ns.Overrides.Child(path, childKey), child)
		end
	end
end
for key, value in pairs(ns.config) do
	for childKey, child in pairs(value) do
		Walk({ "config", key, childKey }, child)
	end
end
for key, value in pairs(ns.layout) do
	Walk({ "layout", key }, value)
end
table.sort(missing)
check(#missing == 0, "config keys without a label: " .. table.concat(missing, ", "))
check(ns.config.style.font ~= nil, "the style config loaded")
print("every config key labelled")

print("settings labels tests passed")
