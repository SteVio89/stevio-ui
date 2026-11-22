-- Run with: lua tests/bindings_test.lua  (from the repo root)
-- Bindings.xml, its names (Core/Bindings.lua, .luacheckrc), the functions it
-- calls and the profile's key bindings fit together: a renamed function or
-- binding would otherwise only fail when the key is pressed in game.
local check = dofile("tests/helpers.lua")

local function Read(path)
	local file = assert(io.open(path))
	local text = file:read("*a")
	file:close()
	return text
end

local xml = Read("Bindings.xml")
local names = Read("Core/Bindings.lua")
local luacheckrc = Read(".luacheckrc")
local profile = Read("Modules/Settings/Profile.lua")

-- Every function defined on ns anywhere in the addon.
local defined = {}
local pipe = io.popen("git ls-files 'Core/*.lua' 'Modules/*.lua'")
for path in pipe:lines() do
	for name in Read(path):gmatch("function ns%.([%w_]+)%(") do
		defined[name] = true
	end
end
pipe:close()

local bindings, headers = {}, 0
for attributes, body in xml:gmatch("<Binding ([^>]*)>(.-)</Binding>") do
	local name = attributes:match('name="([%w_]+)"')
	check(name, "binding without a name: " .. attributes)
	bindings[name] = true
	if attributes:find("header=", 1, true) then
		headers = headers + 1
	end
	check(attributes:find('category="ADDONS"', 1, true), name .. " is listed under AddOns")
	check(names:find("BINDING_NAME_" .. name .. " = ", 1, true), name .. " is named in Core/Bindings.lua")
	check(luacheckrc:find('"BINDING_NAME_' .. name .. '"', 1, true), name .. " is allowed in .luacheckrc")
	local fn = body:match("StevioUI%.([%w_]+)%(%)")
	check(fn, name .. " calls a StevioUI function")
	check(defined[fn], name .. " calls ns." .. fn .. ", which no file defines")
end
check(next(bindings), "Bindings.xml has bindings")
check(headers == 1, "only the first binding opens the header")
check(names:find("BINDING_HEADER_STEVIOUI = ", 1, true), "header named")

-- Names in Core/Bindings.lua without a binding would show up empty.
for name in names:gmatch("BINDING_NAME_([%w_]+) = ") do
	check(bindings[name], "BINDING_NAME_" .. name .. " has a binding in Bindings.xml")
end

-- The profile binds keys to existing commands of this addon.
for command in profile:gmatch('"(STEVIOUI_[%w_]+)"') do
	check(bindings[command], "profile binds unknown command " .. command)
end
print("bindings tests passed")
