local addonName, ns = ...

-- The single global exists only so Bindings.xml and /dump can reach the addon.
StevioUI = ns

ns.name = addonName
ns.config = {}

-- Texts come in German and English, picked by the client language.
ns.isGerman = GetLocale() == "deDE"

function ns.T(english, german)
	return ns.isGerman and german or english
end

-- A raid has up to 8 groups of 5; the group grid and keyboard healing share these.
ns.MAX_GROUPS = 8
ns.UNITS_PER_GROUP = 5

local modules = {}

function ns.RegisterModule(name, module)
	module.name = name
	modules[#modules + 1] = module
	return module
end

local dispatcher = CreateFrame("Frame")
local handlers = {}

dispatcher:SetScript("OnEvent", function(_, event, ...)
	for _, handler in ipairs(handlers[event]) do
		handler(event, ...)
	end
end)

function ns.RegisterEvent(event, handler)
	if not handlers[event] then
		handlers[event] = {}
		dispatcher:RegisterEvent(event)
	end
	table.insert(handlers[event], handler)
end

-- Addon output: "stevio-ui: text", or a further line without the prefix.
-- `ns.printing` marks it as ours while it runs through print(), so the chat
-- can open on it (an answer to something just typed) but not on other addons' output.
local function PrintMarked(line)
	ns.printing = true
	local ok, err = pcall(print, line)
	ns.printing = false
	if not ok then
		error(err, 0)
	end
end

function ns.Print(text)
	PrintMarked(("|cff33ff99%s|r: %s"):format(addonName, text))
end

function ns.PrintLine(text)
	PrintMarked(text)
end

local slashCommands = {}

function ns.RegisterSlashCommand(name, handler)
	slashCommands[name] = handler
end

SLASH_STEVIOUI1 = "/sui"
SlashCmdList.STEVIOUI = function(input)
	local name, rest = input:match("^%s*(%S*)%s*(.-)%s*$")
	local handler = slashCommands[name:lower()]
	if handler then
		handler(rest)
	else
		local names = GetKeysArray(slashCommands)
		table.sort(names)
		ns.Print("/sui " .. table.concat(names, " | "))
	end
end

local combatQueue = {}

-- Protected frames can't be moved, reparented or rebound during combat lockdown,
-- so such changes wait for the lockdown to end instead of erroring.
function ns.RunAfterCombat(fn)
	if InCombatLockdown() then
		combatQueue[#combatQueue + 1] = fn
	else
		fn()
	end
end

ns.RegisterEvent("PLAYER_REGEN_ENABLED", function()
	local queued = combatQueue
	combatQueue = {}
	for _, fn in ipairs(queued) do
		fn()
	end
end)

local function EnableModules()
	for _, module in ipairs(modules) do
		local config = ns.config[module.name]
		if not config or config.enabled ~= false then
			module:OnEnable(config)
		end
	end
	ns.ApplyEditModeLayout()
end

-- A /reload during combat starts the addon under lockdown, where secure frames
-- can't be configured; building everything afterwards avoids half-set-up frames.
ns.RegisterEvent("PLAYER_LOGIN", function()
	if not (StevioUIState and StevioUIState.consented) then
		ns.ShowConsent()
		return
	end
	ns.RunAfterCombat(EnableModules)
end)
