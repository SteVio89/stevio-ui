-- Run with: lua tests/unit_health_color_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")

-- Secret values are stood in for by tables marked here.
local secrets = {}
local function secret(value)
	local s = { value = value }
	secrets[s] = true
	return s
end

local units = {}
_G.CreateFrame = function()
	return { Hide = function() end }
end
_G.UnitIsConnected = function(unit)
	return not units[unit].offline
end
_G.UnitIsDeadOrGhost = function(unit)
	return units[unit].dead
end
_G.UnitIsPlayer = function(unit)
	return units[unit].class ~= nil
end
_G.UnitClass = function(unit)
	return "Localized", units[unit].class
end
_G.UnitIsTapDenied = function()
	return false
end
_G.UnitSelectionColor = function()
	return 1, 0, 0
end
_G.issecretvalue = function(value)
	return secrets[value] == true
end

local lookups = {}
local failSecretLookups = false
_G.C_ClassColor = {
	-- Like the client: a secret class gives a color with secret fields.
	GetClassColor = function(class)
		lookups[#lookups + 1] = class
		if issecretvalue(class) then
			if failSecretLookups then
				error("secret table")
			end
			return { r = secret(0.1), g = secret(0.2), b = secret(0.3) }
		end
		return { r = 0.7, g = 0.8, b = 0.9 }
	end,
}

local ns = loadAddonFile("Core/Util.lua", {
	config = {
		style = {
			offlineColor = { 0.35, 0.35, 0.36 },
			deadColor = { 0.35, 0.35, 0.37 },
			fallbackHealthColor = { 0.2, 0.75, 0.2 },
		},
	},
})

units.target = { class = "MAGE" }
local r, g, b = ns.UnitHealthColor("target")
check(r == 0.7 and g == 0.8 and b == 0.9, "class color for a known class")

-- An enemy NPC's target: the class is secret, the color still comes through.
local class = secret("PRIEST")
units.targettarget = { class = class }
lookups = {}
r, g, b = ns.UnitHealthColor("targettarget")
check(lookups[1] == class, "secret class passed to the class color API")
check(issecretvalue(r) and r.value == 0.1 and g.value == 0.2 and b.value == 0.3, "class color for a secret class")

failSecretLookups = true
r, g, b = ns.UnitHealthColor("targettarget")
check(r == 0.2 and g == 0.75 and b == 0.2, "fallback when a secret class can't be colored")

units.targettarget = { class = secret("PRIEST"), dead = true }
r = ns.UnitHealthColor("targettarget")
check(r == 0.35, "dead before class")

units.targettarget = {}
r, g, b = ns.UnitHealthColor("targettarget")
check(r == 1 and g == 0 and b == 0, "selection color for NPCs")

print("unit health color tests passed")
