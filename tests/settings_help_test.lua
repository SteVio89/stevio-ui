-- Run with: lua tests/settings_help_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")

local ns = {}
function ns.T(english, german)
	return ns.isGerman and german or english
end
loadAddonFile("Modules/Settings/Help.lua", ns)
local Help = ns.SettingsHelp

-- Every command registered in the code is explained, and nothing else.
local registered = {}
local pipe = io.popen("git ls-files '*.lua'")
for path in pipe:lines() do
	if not path:match("^tests/") then
		local file = assert(io.open(path))
		local text = file:read("*a")
		file:close()
		for name in text:gmatch('Register%a*Command%(%s*"([^"]*)"') do
			if name ~= "" then
				registered[name] = path
			end
		end
	end
end
pipe:close()
local described = {}
for _, command in ipairs(Help.COMMANDS) do
	check(registered[command[1]], "described command is not registered: " .. command[1])
	check(not described[command[1]], "described twice: " .. command[1])
	described[command[1]] = true
	check(command[3] ~= "" and command[4] ~= "", "texts of " .. command[1])
end
for name, path in pairs(registered) do
	check(described[name], "command without help: " .. name .. " (" .. path .. ")")
end
print("commands described")

ns.isGerman = true
local lines = Help.Lines()
check(lines[2].command == "/sui test 5|10|25|40", "command with arguments: " .. lines[2].command)
check(lines[1].command == "/sui config" and lines[1].text:find("^Öffnet"), "German text")
print("help lines ok")

print("settings help tests passed")
