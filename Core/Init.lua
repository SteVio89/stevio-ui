local addonName, ns = ...

-- The single global exists only so Bindings.xml and /dump can reach the addon.
StevioUI = ns

ns.name = addonName
ns.config = {}

local modules = {}

function ns:RegisterModule(name, module)
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

function ns:RegisterEvent(event, handler)
	if not handlers[event] then
		handlers[event] = {}
		dispatcher:RegisterEvent(event)
	end
	table.insert(handlers[event], handler)
end

local slashCommands = {}

function ns:RegisterSlashCommand(name, handler)
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
		print(("|cff33ff99%s|r: /sui %s"):format(addonName, table.concat(names, " | ")))
	end
end

local combatQueue = {}

-- Protected frames can't be moved, reparented or rebound during combat lockdown,
-- so such changes wait for the lockdown to end instead of erroring.
function ns:RunAfterCombat(fn)
	if InCombatLockdown() then
		combatQueue[#combatQueue + 1] = fn
	else
		fn()
	end
end

ns:RegisterEvent("PLAYER_REGEN_ENABLED", function()
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
ns:RegisterEvent("PLAYER_LOGIN", function()
	ns:RunAfterCombat(EnableModules)
end)
