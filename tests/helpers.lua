-- Shared by the tests: `local check, loadAddonFile = dofile("tests/helpers.lua")`.

-- Fails the test at the caller's line.
local function check(cond, msg)
	if not cond then
		error("FAIL: " .. msg, 2)
	end
end

-- Runs an addon file the way the client does, with the addon name and a
-- namespace table, and returns that namespace.
local function loadAddonFile(path, ns)
	ns = ns or {}
	assert(loadfile(path))("stevio-ui", ns)
	return ns
end

return check, loadAddonFile
