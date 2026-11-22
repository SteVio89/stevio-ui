-- Run with: lua tests/aura_filter_test.lua  (from the repo root)
-- Aura filters (editable in the options panel) are checked the way Blizzard's
-- aura containers check them, and the shipped ones pass.
local check, loadAddonFile = dofile("tests/helpers.lua")

-- AuraUtil.AuraFilters and IsValidFilterString as in
-- Blizzard_FrameXMLUtil/AuraUtil.lua.
local tokens = {}
for _, token in ipairs({
	"HELPFUL",
	"HARMFUL",
	"PLAYER",
	"RAID",
	"CANCELABLE",
	"INCLUDE_NAME_PLATE_ONLY",
	"MAW",
	"EXTERNAL_DEFENSIVE",
	"CROWD_CONTROL",
	"RAID_IN_COMBAT",
	"RAID_PLAYER_DISPELLABLE",
	"BIG_DEFENSIVE",
	"IMPORTANT",
	"DISPELLABLE",
}) do
	tokens[token] = true
end
_G.AuraUtil = {
	IsValidFilterString = function(filter)
		for component in filter:gmatch("[^| ]*") do
			local negated = component:sub(1, 1) == "!"
			if negated then
				component = component:sub(2)
			end
			if negated and component == "" then
				return false, "bare !"
			end
			if component ~= "" and not tokens[component] then
				return false, "unknown " .. component
			end
		end
		return true
	end,
}
_G.CreateFrame = function()
	return { Hide = function() end }
end

local ns = loadAddonFile("Core/Util.lua", { config = { style = {} } })

check(ns.IsValidAuraFilter("HARMFUL|PLAYER"), "plain filter")
check(ns.IsValidAuraFilter("HARMFUL|!RAID"), "negated component")
check(not ns.IsValidAuraFilter("HARMFUL|RAD"), "typo")
check(not ns.IsValidAuraFilter("HARMFUL|!"), "bare negation")
check(not ns.IsValidAuraFilter(nil), "no filter")
print("filter check ok")

-- The shipped filters.
local config = {}
loadAddonFile("Modules/Group/Config.lua", { config = config })
loadAddonFile("Modules/Units/Config.lua", { config = config })
local shipped = {
	config.group.ownAuraFilter,
	config.group.dispellableFilter,
	config.group.otherFilter,
	config.units.targetAuras.filter,
}
for i, filter in ipairs(shipped) do
	check(ns.IsValidAuraFilter(filter), ("shipped filter %d: %s"):format(i, tostring(filter)))
end
print("shipped filters ok")

print("aura filter tests passed")
