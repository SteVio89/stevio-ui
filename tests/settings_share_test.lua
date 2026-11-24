-- Run with: lua tests/settings_share_test.lua  (from the repo root)
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
for _, file in ipairs({ "Profile", "Model", "EditorModel", "Share" }) do
	loadAddonFile("Modules/Settings/" .. file .. ".lua", ns)
end
local Share, Overrides = ns.SettingsShare, ns.Overrides
local defaults = Overrides.DeepCopy({ config = ns.config, layout = ns.layout })
local ctx = {
	defaults = defaults,
	isIgnored = function(name)
		return ns.SettingsModel.IsIgnoredCVar(name, ns.config.settings.ignoredCVars)
	end,
}

-- Serializer round trip, including awkward strings and numbers.
local value = {
	"a",
	2,
	{ x = 0.1, y = -3, z = 1e-7 },
	s = "line\nwith: colons; t e and |cff codes",
	yes = true,
	no = false,
	[10] = "sparse",
}
local text = Share.Serialize(value)
check(Overrides.Equal(Share.Deserialize(text), value), "round trip")
check(Share.Serialize({ b = 1, a = 2 }) == Share.Serialize({ a = 2, b = 1 }), "deterministic")
check(Share.Deserialize("t") == nil, "unfinished table")
check(Share.Deserialize("s99:abc") == nil, "string too short")
check(Share.Deserialize("nabc;") == nil, "not a number")
check(Share.Deserialize("x") == nil, "unknown mark")
check(Share.Deserialize("TT") == nil, "text after the value")
check(Share.Deserialize(("t"):rep(50) .. ("e"):rep(50)) == nil, "too deep")
print("serializer ok")

-- Base64 round trip for every length and all byte values.
local bytes = {}
for i = 0, 255 do
	bytes[#bytes + 1] = string.char(i)
end
local all = table.concat(bytes)
for length = 0, 7 do
	local data = all:sub(100, 99 + length)
	check(Share.DecodeBase64(Share.EncodeBase64(data)) == data, "base64 length " .. length)
end
check(Share.DecodeBase64(Share.EncodeBase64(all)) == all, "base64 all bytes")
check(Share.EncodeBase64("Man") == "TWFu" and Share.EncodeBase64("Ma") == "TWE=", "standard alphabet")
check(Share.DecodeBase64("TW*u") == nil and Share.DecodeBase64("TWF") == nil, "bad base64")
print("base64 ok")

-- Export and import: values, keys, game settings.
local values = {
	["config/group/nameFontSize"] = 12,
	["config/chat/activeAlpha"] = 0.95,
	["config/style/theme"] = "dusk",
	["config/group/dispelColor"] = { 0.2, 0.4, 0.6, 1 },
	["config/actionBars/sets"] = { "Solo", "Gruppe", "Heilen" },
	["layout/group/y"] = 200,
}
local exported = Share.Export(values, { ["SHIFT-A"] = "MOUNT", NUMPAD0 = false }, { farclip = "4000" })
check(exported:sub(1, 6) == "!SUI1!" and not exported:find("%s"), "one line with the prefix")
check(
	Share.Summary(Share.Counts({ values = values, bindings = { a = 1 }, cvars = { b = 1, c = 2 } }))
		== "Enthält 6 Einstellungen, 1 Taste, 2 Spieleinstellungen",
	"summary"
)
local result = Share.Import("  " .. exported .. "\n", ctx)
check(result and #result.values == 6, "values imported")
local imported = {}
for _, entry in ipairs(result.values) do
	imported[entry.encoded] = entry.value
	check(Overrides.Get(defaults, entry.path) ~= nil, "path decoded")
end
check(Overrides.Equal(imported, values), "values round trip")
check(result.bindings["SHIFT-A"] == "MOUNT" and result.bindings.NUMPAD0 == false, "bindings")
check(result.cvars.farclip == "4000" and #result.skipped == 0, "cvars")
result = Share.Import(Share.Export(values), ctx)
check(next(result.bindings) == nil and next(result.cvars) == nil, "keys and game settings are optional")
print("round trip ok")

-- Checks: prefix, version, damage, unknown paths, kinds of values, colours.
local function Error(input)
	local ok, message = Share.Import(input, ctx)
	check(ok == nil and type(message) == "string", "refused: " .. tostring(input))
	return message
end
check(Error("hello"):find("kein stevio%-ui"), "no prefix")
check(Error("!SUI2!abc"):find("neueren"), "newer version")
check(Error("!SUI1!@@@@"):find("beschädigt"), "bad base64")
check(Error("!SUI1!" .. Share.EncodeBase64("t")):find("beschädigt"), "bad payload")
check(Error("!SUI1!" .. Share.EncodeBase64(Share.Serialize({ v = 7 }))):find("anderen"), "other version")
local bad = Share.Export({
	["config/nothing/here"] = 1,
	["config/group/nameFontSize"] = "big",
	["config/group/dispelColor"] = { 2, 0, 0, 1 },
	["config/group/aggroColor"] = { 0.5, 0.5, 0.5 },
	["config/actionBars/sets"] = { 1, 2 },
	["config/settings/profile/cvars/farclip"] = "1",
	["config/group/spacing"] = 4,
	["os/execute"] = "rm",
}, { [1] = "x", F = 7 }, { lastSeenThing = "1", ["bad name"] = "1", farclip = 4000, SSAO = "1" })
result = Share.Import(bad, ctx)
check(#result.values == 1 and result.values[1].encoded == "config/group/spacing", "only the fitting value")
check(next(result.bindings) == nil, "bad keys skipped")
check(result.cvars.SSAO == "1" and result.cvars.farclip == nil and result.cvars.lastSeenThing == nil, "cvars checked")
check(#result.skipped == 12, "skipped and reported: " .. #result.skipped .. "\n" .. table.concat(result.skipped, "\n"))
result = Share.Import(Share.Export({}, nil, { SSAO = "1" }), {
	defaults = defaults,
	isIgnored = ctx.isIgnored,
	cvarExists = function()
		return false
	end,
})
check(next(result.cvars) == nil and #result.skipped == 1, "unknown CVars skipped")
print("checks ok")

print("settings share tests passed")
