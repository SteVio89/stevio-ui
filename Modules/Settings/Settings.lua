local addonName, ns = ...

local config = ns.config.settings

local Settings = ns:RegisterModule("settings", {})

local function ApplyActionBars(toggles)
	for index, enabled in ipairs(toggles) do
		if not not select(index, GetActionBarToggles()) ~= enabled then
			SetActionBarToggles(unpack(toggles))
			return true
		end
	end
	return false
end

local function ApplyCVars(cvars)
	local changed = false
	for name, value in pairs(cvars) do
		if GetCVar(name) ~= value then
			SetCVar(name, value)
			changed = true
		end
	end
	return changed
end

function ns.GetBindingKeys(index)
	local keys = {}
	local count = select("#", GetBinding(index))
	for i = 3, count do
		local key = select(i, GetBinding(index))
		if key then
			keys[#keys + 1] = key
		end
	end
	return keys
end

-- Strict: every key not bound in the profile gets unbound, so a fresh client
-- ends up with exactly the bindings in code.
local function ApplyBindings(bindings, bindingSet)
	bindingSet = bindingSet or Enum.BindingSet.Account
	local changed = false
	for index = 1, GetNumBindings() do
		for _, key in ipairs(ns.GetBindingKeys(index)) do
			if bindings[key] == nil then
				SetBinding(key)
				changed = true
			end
		end
	end
	for key, command in pairs(bindings) do
		if GetBindingAction(key) ~= command then
			SetBinding(key, command)
			changed = true
		end
	end
	if changed or GetCurrentBindingSet() ~= bindingSet then
		SaveBindings(bindingSet)
	end
	return changed
end

-- Taken once when the player agrees to the takeover, so /sui restore can hand
-- back exactly what the profile overwrote.
function ns.CaptureBackup()
	local backup = {
		actionBars = {},
		bindings = {},
		bindingSet = GetCurrentBindingSet(),
		cvars = {},
		editModeLayout = ns.GetActiveEditModeLayout(),
	}
	for i = 1, select("#", GetActionBarToggles()) do
		backup.actionBars[i] = not not select(i, GetActionBarToggles())
	end
	for index = 1, GetNumBindings() do
		local command = GetBinding(index)
		for _, key in ipairs(ns.GetBindingKeys(index)) do
			backup.bindings[key] = command
		end
	end
	for name in pairs(config.profile.cvars or {}) do
		backup.cvars[name] = GetCVar(name)
	end
	return backup
end

local function Restore()
	local backup = StevioUIState and StevioUIState.backup
	if not backup then
		print(("|cff33ff99%s|r: Keine Sicherung vorhanden."):format(addonName))
		return
	end
	ApplyActionBars(backup.actionBars)
	ApplyCVars(backup.cvars)
	ApplyBindings(backup.bindings, backup.bindingSet)
	ns.RestoreEditModeLayout(backup.editModeLayout)
	-- Forgetting the consent makes a later re-enable ask again and take a fresh backup.
	StevioUIState = nil
	C_AddOns.DisableAddOn(addonName)
	ReloadUI()
end

local function ApplyProfile()
	local profile = config.profile
	local changed = {}
	if profile.actionBars and ApplyActionBars(profile.actionBars) then
		changed[#changed + 1] = "action bars"
	end
	if profile.cvars and ApplyCVars(profile.cvars) then
		changed[#changed + 1] = "cvars"
	end
	if profile.bindings and ApplyBindings(profile.bindings) then
		changed[#changed + 1] = "bindings"
	end
	if #changed > 0 then
		print(("|cff33ff99%s|r: Profil angewendet (%s)."):format(addonName, table.concat(changed, ", ")))
	end
end

-- Bindings and account CVars arrive from the server around login; by the
-- first PLAYER_ENTERING_WORLD both are in place. The module only enables after
-- the player has agreed to the takeover.
local enabled, enteredWorld, applied = false, false, false

local function TryApply()
	if applied or not enabled or not enteredWorld then
		return
	end
	applied = true
	ns:RunAfterCombat(ApplyProfile)
end

ns:RegisterEvent("PLAYER_ENTERING_WORLD", function()
	enteredWorld = true
	TryApply()
end)

function Settings:OnEnable()
	enabled = true
	TryApply()

	if config.consoleKey then
		SetConsoleKey(config.consoleKey)
	end

	ns:RegisterSlashCommand("export", function()
		local text = ns.BuildProfileExport()
		StevioUIExport = text
		ns.ShowExportWindow(text)
	end)
	ns:RegisterSlashCommand("apply", function()
		ns:RunAfterCombat(ApplyProfile)
	end)
	ns:RegisterSlashCommand("restore", function()
		ns:RunAfterCombat(Restore)
	end)
end
