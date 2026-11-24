-- Run with: lua tests/settings_cvars_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")

local ns = { config = {}, isGerman = true }
function ns.T(english, german)
	return ns.isGerman and german or english
end
loadAddonFile("Modules/Settings/Config.lua", ns)
loadAddonFile("Modules/Settings/Profile.lua", ns)
loadAddonFile("Modules/Settings/Model.lua", ns)
loadAddonFile("Modules/Settings/Search.lua", ns)
loadAddonFile("Modules/Settings/CVarInfo.lua", ns)
local Info, Model = ns.CVarInfo, ns.SettingsModel
local patterns = ns.config.settings.ignoredCVars
local function IsIgnored(name)
	return Model.IsIgnoredCVar(name, patterns)
end

-- Every described CVar has texts in both languages, a known group and a
-- control that fits; none of them is ignored.
local groups = {}
for _, group in ipairs(Info.GROUPS) do
	groups[group.key] = true
end
for name, info in pairs(Info.CVARS) do
	check(groups[info.group] and info.group ~= "other" and info.group ~= "raid", "group of " .. name)
	check(info.name[1] and info.name[2] and info.help[1] and info.help[2], "texts of " .. name)
	check(not name:find("^RAID"), "raid variants follow their base: " .. name)
	check(not IsIgnored(name), "described but ignored: " .. name)
	if info.control == "slider" then
		check(info.min < info.max and info.step, "range of " .. name)
	elseif info.control == "select" then
		check(#info.options > 1, "options of " .. name)
	end
end
-- The profile's values fit their controls.
for name, value in pairs(ns.config.settings.profile.cvars) do
	local info = Info.CVARS[name]
	if info and info.control == "switch" then
		check(value == "0" or value == "1", "switch value of " .. name)
	elseif info and info.control == "slider" then
		local number = tonumber(value)
		check(number and number >= info.min and number <= info.max, "slider range of " .. name .. ": " .. value)
	elseif info and info.control == "select" then
		local found = false
		for _, option in ipairs(info.options) do
			found = found or option[1] == value
		end
		check(found, "option for " .. name .. " = " .. value)
	end
end
print("descriptions ok")

-- Raid variants: their base, mirroring.
local names = { farclip = true, RAIDfarclip = true, RAIDonly = true }
check(Info.RaidBase("RAIDfarclip", names) == "farclip", "raid base")
check(Info.RaidBase("RAIDonly", names) == nil, "raid without a base")
check(Info.RaidBase("farclip", names) == nil, "not a raid variant")
check(Info.RaidBase("RAIDWaterDetail", { waterDetail = true }) == "waterDetail", "any case")
local mirrored = Info.Mirror({ farclip = "4000", RAIDfarclip = "6000", RAIDonly = "1", SSAO = "2" })
check(mirrored.RAIDfarclip == "4000" and mirrored.farclip == "4000", "raid follows its base")
check(mirrored.RAIDonly == "1" and mirrored.SSAO == "2", "others stay")
check(Info.RaidCount(ns.config.settings.profile.cvars, {}) == 28, "the profile's raid variants")
print("raid ok")

-- Values between controls and CVars.
check(Info.ToCVar(true) == "1" and Info.ToCVar(false) == "0", "switch to CVar")
check(Info.ToCVar(4000) == "4000" and Info.ToCVar(1.5) == "1.5" and Info.ToCVar(0.85) == "0.85", "numbers")
check(
	Info.FromCVar({ control = "switch" }, "1") == true and Info.FromCVar({ control = "switch" }, "0") == false,
	"switch"
)
check(Info.FromCVar({ control = "slider", min = 0 }, "1.000000") == 1, "slider")
print("values ok")

-- Rows: groups, own values, filters, search, mirroring and ignored CVars.
local profile = { farclip = "6000", RAIDfarclip = "6000", lockActionBars = "0", mysteryCVar = "3", lastSeen = "1" }
local overrides = { farclip = "4000", lockActionBars = "1" }
local opts = { isIgnored = IsIgnored, mirror = true, filter = "all", query = "" }
local rows, counts = Info.Rows(profile, overrides, opts)
check(#rows == 3 and rows[1].key == "graphics" and rows[2].key == "game" and rows[3].key == "other", "groups")
check(counts.all == 3 and counts.own == 2, "counts")
local farclip = rows[1].rows[1]
check(
	farclip.name == "farclip" and farclip.own and farclip.value == "4000" and farclip.profileValue == "6000",
	"own value"
)
check(rows[3].rows[1].name == "mysteryCVar" and rows[3].rows[1].info == nil, "other")
opts.mirror = false
rows = Info.Rows(profile, overrides, opts)
check(rows[#rows].key == "raid" and rows[#rows].rows[1].raidOf == "farclip", "raid rows when not mirrored")
opts.filter = "own"
rows = Info.Rows(profile, overrides, opts)
check(#rows == 2 and #rows[1].rows == 1 and #rows[2].rows == 1, "own filter")
opts.filter, opts.query = "all", "SICHT"
rows = Info.Rows(profile, overrides, opts)
check(#rows == 2 and rows[1].rows[1].name == "farclip", "found by name, raid too")
opts.query = "lockaction"
rows = Info.Rows(profile, overrides, opts)
check(#rows == 1 and rows[1].rows[1].name == "lockActionBars", "found by technical name")
print("rows ok")

print("settings cvars tests passed")
