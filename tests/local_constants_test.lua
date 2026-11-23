-- Run with: lua tests/local_constants_test.lua  (from the repo root)
-- Guards against code copied from one file to another that still reads a
-- constant the first file declares as a local (`local SCROLL_BAR_SPACE = 14`):
-- in the new file it is an unknown global, nil in the game, and luacheck lets
-- it pass since reading unknown (game API) globals is allowed. Every global a
-- file reads must not be a name some addon file only declares as a local
-- constant, unless the game itself has a global of that name (`GAME_GLOBALS`).
local check = dofile("tests/helpers.lua")

-- Names stevio-ui declares as local constants that are also game globals.
local GAME_GLOBALS = {}

local function Lines(command)
	local list = {}
	local pipe = io.popen(command)
	for line in pipe:lines() do
		list[#list + 1] = line
	end
	pipe:close()
	return list
end

local luac = Lines("command -v luac5.1 || command -v luac")[1]
check(luac, "luac is installed")

local files = Lines("git ls-files '*.lua'")
check(#files > 0, "lua files are listed")

-- Local constants (upper case names) and the files declaring them.
local declared = {}
for _, path in ipairs(files) do
	local file = assert(io.open(path))
	for line in file:lines() do
		local names = line:match("^%s*local%s+([%w_,%s]-)%s*=")
		for name in (names or ""):gmatch("[%w_]+") do
			if name:match("^[A-Z][A-Z0-9_]+$") then
				declared[name] = declared[name] or path
			end
		end
	end
	file:close()
end

local failures = {}
for _, path in ipairs(files) do
	if path:match("^Core/") or path:match("^Modules/") then
		for _, line in ipairs(Lines(("%s -l -p '%s'"):format(luac, path))) do
			local name = line:match("GETGLOBAL.-; (.+)$")
			if name and declared[name] and not GAME_GLOBALS[name] then
				failures[#failures + 1] = ("%s reads %s, a local of %s"):format(path, name, declared[name])
			end
		end
	end
end
check(#failures == 0, "globals that are local constants elsewhere:\n" .. table.concat(failures, "\n"))
