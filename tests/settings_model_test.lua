-- Run with: lua tests/settings_model_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")

local ns = { config = {} }
loadAddonFile("Modules/Settings/Config.lua", ns)
loadAddonFile("Modules/Settings/Model.lua", ns)
local Model = ns.SettingsModel

-- KnownCVarName: case-insensitive, the first map's spelling wins.
local profile = { graphicsQuality = "5", SoundVolume = "0.5" }
local overrides = { graphicsquality = "3", farclip = "1000" }
check(Model.KnownCVarName("GRAPHICSQUALITY", { profile, overrides }) == "graphicsQuality", "profile spelling first")
check(Model.KnownCVarName("soundvolume", { profile, overrides }) == "SoundVolume", "mixed case")
check(Model.KnownCVarName("FarClip", { profile, overrides }) == "farclip", "override spelling")
check(Model.KnownCVarName("Unknown", { profile, overrides }) == "Unknown", "unknown name as it is")
check(Model.KnownCVarName("x", {}) == "x", "no maps")
print("known cvar names ok")

-- CVarOverrideFor: the capture of a CVar the player changed.
check(Model.CVarOverrideFor("3", "1", "5") == "3", "differs from the profile")
check(Model.CVarOverrideFor("5", "1", "5") == nil, "back to the profile clears")
check(Model.CVarOverrideFor("1", "1", "5") == "1", "the default is an override for a profile CVar")
check(Model.CVarOverrideFor("2", "1", nil) == "2", "unmanaged CVar changed")
check(Model.CVarOverrideFor("1", "1", nil) == nil, "unmanaged CVar back to the default clears")
print("cvar capture ok")

-- CVarOverride: the options panel setting or removing a CVar.
local override, backToDefault = Model.CVarOverride("3", "5")
check(override == "3" and not backToDefault, "panel sets a profile CVar")
override, backToDefault = Model.CVarOverride("5", "5")
check(override == nil and not backToDefault, "panel sets the profile value")
override, backToDefault = Model.CVarOverride(nil, "5")
check(override == nil and not backToDefault, "removing a profile CVar's override")
override, backToDefault = Model.CVarOverride("2", nil)
check(override == "2" and not backToDefault, "panel sets an unmanaged CVar")
override, backToDefault = Model.CVarOverride(nil, nil)
check(override == nil and backToDefault, "removing an unmanaged CVar sends it back to the default")
print("panel cvars ok")

-- BindingOverride: the options panel binding or unbinding a key.
check(Model.BindingOverride("JUMP", "JUMP") == nil, "the profile's command")
check(Model.BindingOverride("SITORSTAND", "JUMP") == "SITORSTAND", "another command")
check(Model.BindingOverride("JUMP", nil) == "JUMP", "a key outside the profile")
check(Model.BindingOverride(nil, nil) == nil, "unbinding a key outside the profile")
check(Model.BindingOverride(nil, "JUMP") == false, "unbinding a profile key")
print("panel bindings ok")

-- AddUnknownProfileBindings: profile keys whose command is missing this
-- session count as unchanged; keys of known commands stay unbound.
local current = { W = "MOVEFORWARD", Q = "CUSTOM" }
local commands = { MOVEFORWARD = true, JUMP = true, CUSTOM = true }
local result = Model.AddUnknownProfileBindings(current, commands, {
	W = "MOVEFORWARD",
	SPACE = "JUMP",
	F = "OTHERADDON_ACTION",
	Q = "OTHERADDON_ACTION",
})
check(result == current, "fills in place")
check(current.F == "OTHERADDON_ACTION", "unknown command kept")
check(current.SPACE == nil, "known command unbound stays unbound")
check(current.Q == "CUSTOM", "a bound key keeps its binding")
check(current.W == "MOVEFORWARD", "unchanged key")
print("current bindings ok")

-- IsIgnoredCVar with the patterns of Config.lua.
local patterns = ns.config.settings.ignoredCVars
check(Model.IsIgnoredCVar("lastCharacterIndex", patterns), "client state")
check(Model.IsIgnoredCVar("showTutorials", patterns), "tutorial")
check(Model.IsIgnoredCVar("enableMultiActionBars", patterns), "action bars")
check(not Model.IsIgnoredCVar("graphicsQuality", patterns), "a preference")
check(not Model.IsIgnoredCVar("anything", {}), "no patterns")
print("ignored cvars ok")

-- LuaKey: identifiers as they are, everything else quoted.
check(Model.LuaKey("graphicsQuality") == "graphicsQuality", "identifier")
check(Model.LuaKey("_x1") == "_x1", "underscore identifier")
check(Model.LuaKey("1st") == '["1st"]', "leading digit")
check(Model.LuaKey("a.b") == '["a.b"]', "dot")
print("lua keys ok")

-- ProfileText: the export reads back as the same profile.
local text = Model.ProfileText("2026-01-02 03:04", { true, false, true }, {
	{ command = "MOVEFORWARD", category = "BINDING_HEADER_MOVEMENT", categoryName = "Movement", keys = { "W", "UP" } },
	{ command = "MOVEBACKWARD", category = "BINDING_HEADER_MOVEMENT", categoryName = "Movement", keys = { "S" } },
	{ command = "UNBOUND", category = "BINDING_HEADER_OTHER", categoryName = "Other", keys = {} },
	{ command = "JUMP", category = "BINDING_HEADER_MOVEMENT", categoryName = "Movement", keys = { "SPACE" } },
	{ command = "TOGGLEBAG", category = "BINDING_HEADER_INTERFACE", categoryName = "Interface", keys = { 'SHIFT-"' } },
	{ command = "SITORSTAND", category = "BINDING_HEADER_MOVEMENT", categoryName = "Movement", keys = { "X" } },
}, {
	{ name = "zoom", value = "1" },
	{ name = "graphicsQuality", value = "5" },
	{ name = "odd.name", value = 'say "hi"\n' },
})

check(
	text:find("^local _, ns = %.%.%.\n\n%-%- Generated by /sui export on 2026%-01%-02 03:04; edit freely%.\n"),
	"header"
)
check(text:find("\tactionBars = { true, false, true },\n", 1, true), "action bars line")
check(text:sub(-2) == "}\n", "ends with a newline")
-- A header per run of a category, also when it comes back; a binding without
-- keys neither gets one nor ends a run.
local headers = {}
for header in text:gmatch("\t\t%-%- ([^\n]+)") do
	headers[#headers + 1] = header
end
check(table.concat(headers, ",") == "Movement,Interface,Movement", "category headers: " .. table.concat(headers, ","))
-- CVars sorted by their line, so quoted names ("[") come before letters.
local graphics, odd, zoom =
	text:find("graphicsQuality", 1, true), text:find("odd.name", 1, true), text:find("zoom =", 1, true)
check(odd < graphics and graphics < zoom, "cvars sorted")

local target = { config = { settings = {} } }
local chunk = assert(loadstring(text))
chunk("stevio-ui", target)
local loaded = target.config.settings.profile
check(
	#loaded.actionBars == 3 and loaded.actionBars[1] == true and loaded.actionBars[2] == false,
	"action bars read back"
)
check(loaded.bindings.W == "MOVEFORWARD" and loaded.bindings.UP == "MOVEFORWARD", "bindings read back")
check(loaded.bindings.SPACE == "JUMP" and loaded.bindings['SHIFT-"'] == "TOGGLEBAG", "quoted keys read back")
check(loaded.bindings.S == "MOVEBACKWARD", "second binding")
local count = 0
for _ in pairs(loaded.bindings) do
	count = count + 1
end
check(count == 6, "no other bindings")
check(loaded.cvars.zoom == "1" and loaded.cvars.graphicsQuality == "5", "cvars read back")
check(loaded.cvars["odd.name"] == 'say "hi"\n', "quoted cvar read back")
print("profile text ok")

-- An empty client still gives a loadable profile.
target = { config = { settings = {} } }
assert(loadstring(Model.ProfileText("now", {}, {}, {})))("stevio-ui", target)
loaded = target.config.settings.profile
check(#loaded.actionBars == 0 and next(loaded.bindings) == nil and next(loaded.cvars) == nil, "empty profile")
print("empty profile ok")

print("settings model tests passed")
