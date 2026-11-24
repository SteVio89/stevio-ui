-- Run with: lua tests/settings_deviations_test.lua  (from the repo root)
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
for _, file in ipairs({ "Profile", "Labels", "EditorModel", "Pages", "Meta", "Deviations" }) do
	loadAddonFile("Modules/Settings/" .. file .. ".lua", ns)
end
local Deviations = ns.SettingsDeviations
local defaults = ns.Overrides.DeepCopy({ config = ns.config, layout = ns.layout })

local list = Deviations.List({
	values = {
		["config/chat/activeAlpha"] = 0.95,
		["config/group/nameFontSize"] = 12,
		["config/style/theme"] = "dusk",
		["config/units/frames/#2/width"] = 220,
		["layout/group/y"] = 200,
	},
	defaults = defaults,
	bindings = { ["SHIFT-A"] = "MOUNT", NUMPAD0 = false },
	profileBindings = { ["SHIFT-A"] = "STRAFELEFT", NUMPAD0 = "JUMP" },
	actionName = function(command)
		return ({ MOUNT = "Reittier rufen", JUMP = "Springen" })[command] or command
	end,
	keyName = function(key)
		return ({ ["SHIFT-A"] = "Shift A", NUMPAD0 = "Num 0" })[key]
	end,
	cvars = { farclip = "4000", newCVar = "1" },
	profileCVars = { farclip = "6000" },
	cvarName = function(name)
		return name == "farclip" and "Sichtweite" or name
	end,
	cvarValue = function(_, value)
		return value
	end,
})

check(#list == 9, "every override listed: " .. #list)
-- Appearance first, then the modules in page order, then keys and CVars.
check(list[1].key == "config/style/theme" and list[1].area == "Darstellung", "appearance first: " .. list[1].key)
check(list[2].area == "Einheitenfenster" and list[2].name == "Fenster 2 · Breite", "list entry name: " .. list[2].name)
check(list[2].old == "200 px" and list[2].new == "220 px", "formatted values")
local byKey = {}
for _, entry in ipairs(list) do
	byKey[entry.key] = entry
end
check(byKey["config/chat/activeAlpha"].old == "85 %" and byKey["config/chat/activeAlpha"].new == "95 %", "percent")
check(byKey["layout/group/y"].area == "Gruppenraster", "position in its module")
check(
	byKey["config/group/nameFontSize"].old == "11 px" and byKey["config/group/nameFontSize"].new == "12 px",
	"numbers"
)
local mount = byKey["SHIFT-A"]
check(
	mount.kind == "binding" and mount.name == "Reittier rufen" and mount.old == "–" and mount.new == "Shift A",
	"own key"
)
local jump = byKey.NUMPAD0
check(jump.name == "Springen" and jump.old == "Num 0" and jump.new == "–", "removed key")
check(byKey.farclip.name == "Sichtweite" and byKey.farclip.old == "6000" and byKey.farclip.new == "4000", "cvar")
check(byKey.newCVar.old == "–", "cvar outside the profile")
check(list[#list].kind == "cvar" and list[7].kind == "binding", "order of the kinds")
check(#Deviations.List({ defaults = defaults }) == 0, "nothing changed")
print("deviations ok")

print("settings deviations tests passed")
