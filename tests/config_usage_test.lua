-- Run with: lua tests/config_usage_test.lua  (from the repo root)
-- Guards against config that outlived its code: every key of the Config.lua
-- and Layout.lua tables is read somewhere, and the CVars modules set
-- themselves stay out of the profile (or it fights them on every login).
local check, loadAddonFile = dofile("tests/helpers.lua")

local function Lines(command)
	local list = {}
	local pipe = io.popen(command)
	for line in pipe:lines() do
		list[#list + 1] = line
	end
	pipe:close()
	return list
end

local function Read(path)
	local file = assert(io.open(path))
	local text = file:read("*a")
	file:close()
	return text
end

-- The config, with each section's module directory.
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
local ns = { config = {} }
local sectionDir = {}
local function LoadConfig(path)
	local before = {}
	for section in pairs(ns.config) do
		before[section] = true
	end
	loadAddonFile(path, ns)
	for section in pairs(ns.config) do
		if not before[section] then
			sectionDir[section] = path:match("^(.*)/")
		end
	end
end
LoadConfig("Core/Config.lua")
loadAddonFile("Core/Layout.lua", ns)
for _, path in ipairs(Lines("git ls-files 'Modules/*/Config.lua'")) do
	LoadConfig(path)
end
loadAddonFile("Modules/Settings/Profile.lua", ns)

-- The code that reads the config: everything but the config itself, the
-- options panel's labels and the tests.
local code = {}
for _, path in ipairs(Lines("git ls-files '*.lua'")) do
	local isConfig = path:match("Config%.lua$") or path == "Core/Layout.lua" or path:match("Profile%.lua$")
	if not isConfig and not path:match("Labels%.lua$") and not path:match("^tests/") then
		code[path] = Read(path)
	end
end
check(next(code) ~= nil, "found the addon code (run from the repo root)")

-- Tables whose keys are data the code iterates over, not names it reads.
local DATA = {
	["config/chat/events"] = true,
	["config/chat/kindOrder"] = true,
	["config/chat/main/channels"] = true,
	["config/settings/profile"] = true,
}

-- The code that can read a section: its module's files, the files naming it
-- (config.chat, ns.config.chat) and Init.lua, which reads every `enabled`.
local function SectionCode(section)
	local parts = { code["Core/Init.lua"] }
	local dir = sectionDir[section]
	for path, text in pairs(code) do
		local inDir = dir ~= "Core" and path:sub(1, #dir + 1) == dir .. "/"
		if inDir or text:find("config%." .. section .. "%f[^%w_]") then
			parts[#parts + 1] = text
		end
	end
	return table.concat(parts, "\n")
end

local function Mentions(text, key)
	return text:find("[%.:]" .. key .. "%f[^%w_]") or text:find('"' .. key .. '"', 1, true)
end

local unused = {}
local function Walk(text, path, value)
	if type(value) ~= "table" or DATA[table.concat(path, "/")] then
		return
	end
	for key, child in pairs(value) do
		-- Upper-case keys (events, tokens) and list entries are data.
		local isName = type(key) == "string" and not key:match("^[%u%d_]+$")
		local childPath = { unpack(path) }
		childPath[#childPath + 1] = key
		if isName and not Mentions(text, key) then
			unused[#unused + 1] = table.concat(childPath, "/")
		end
		Walk(text, childPath, child)
	end
end
for section, value in pairs(ns.config) do
	Walk(SectionCode(section), { "config", section }, value)
end
local allCode = {}
for _, text in pairs(code) do
	allCode[#allCode + 1] = text
end
Walk(table.concat(allCode, "\n"), { "layout" }, ns.layout)
table.sort(unused)
check(#unused == 0, "config keys no code reads: " .. table.concat(unused, ", "))
print("config keys read")

-- CVars a module sets itself are ignored by the profile (Settings/Config.lua),
-- and the profile sets none of the ignored ones.
loadAddonFile("Modules/Settings/Model.lua", ns)
local Model = ns.SettingsModel
local patterns = ns.config.settings.ignoredCVars
local unignored = {}
for path, text in pairs(code) do
	if not path:match("^Modules/Settings/") then
		for name in text:gmatch('SetCVar%(%s*"([^"]+)"') do
			if not Model.IsIgnoredCVar(name, patterns) then
				unignored[#unignored + 1] = path .. ": " .. name
			end
		end
	end
end
table.sort(unignored)
check(#unignored == 0, "CVars set by modules but not in ignoredCVars: " .. table.concat(unignored, ", "))
check(Model.IsIgnoredCVar("rotateMinimap", patterns), "the minimap's CVar is found")
local inProfile = {}
for name in pairs(ns.config.settings.profile.cvars) do
	if Model.IsIgnoredCVar(name, patterns) then
		inProfile[#inProfile + 1] = name
	end
end
table.sort(inProfile)
check(#inProfile == 0, "ignored CVars in Profile.lua: " .. table.concat(inProfile, ", "))
print("module CVars ignored")

print("config usage tests passed")
