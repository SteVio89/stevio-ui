local addonName, ns = ...

local config = ns.config.settings

local Settings = ns:RegisterModule("settings", {})

-- Set while stevio-ui itself changes CVars or bindings, so those changes
-- aren't taken for the player's own (see the capture below).
local applying = false

-- The profile with the options panel's overrides (StevioUIConfig) on top.
function ns.EffectiveBindings()
	return ns.Overrides.Merge(config.profile.bindings or {}, StevioUIConfig.bindings)
end

function ns.EffectiveCVars()
	return ns.Overrides.Merge(config.profile.cvars or {}, StevioUIConfig.cvars)
end

local function ApplyActionBars(toggles)
	for index, enabled in ipairs(toggles) do
		if (not not select(index, GetActionBarToggles())) ~= enabled then
			SetActionBarToggles(unpack(toggles))
			return true
		end
	end
	return false
end

local function ApplyCVars(cvars)
	local changed = false
	applying = true
	for name, value in pairs(cvars) do
		if GetCVar(name) ~= value then
			SetCVar(name, value)
			changed = true
		end
	end
	applying = false
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
	applying = true
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
	applying = false
	return changed
end

-- Taken once when the player agrees to the takeover, so /sui restore can hand
-- back what the profile overwrote. It holds every CVar, so CVars added to the
-- profile later can be handed back too.
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
	ns.ForEachCVar(function(name, value)
		backup.cvars[name] = value
	end)
	return backup
end

-- Only the CVars stevio-ui manages (profile and overrides) go back, so
-- settings stevio-ui never touched stay. Backups from before the full snapshot
-- lack CVars the profile gained since; those go back to the default.
local function RestoreCVars(backupCVars)
	local values = {}
	for name in pairs(ns.EffectiveCVars()) do
		values[name] = backupCVars[name] or C_CVar.GetCVarDefault(name)
	end
	ApplyCVars(values)
end

local function Restore()
	local backup = StevioUIState and StevioUIState.backup
	if not backup then
		ns.Print("Keine Sicherung vorhanden.")
		return
	end
	ApplyActionBars(backup.actionBars)
	RestoreCVars(backup.cvars)
	ApplyBindings(backup.bindings, backup.bindingSet)
	ns.RestoreEditModeLayout(backup.editModeLayout)
	-- Forgetting the consent makes a later re-enable ask again and take a fresh backup.
	StevioUIState = nil
	C_AddOns.DisableAddOn(addonName)
	ReloadUI()
end

-- Changes are only taken for the player's own once the profile is in place.
local profileApplied = false

local function ApplyProfile()
	local profile = config.profile
	local changed = {}
	if profile.actionBars and ApplyActionBars(profile.actionBars) then
		changed[#changed + 1] = "action bars"
	end
	if profile.cvars and ApplyCVars(ns.EffectiveCVars()) then
		changed[#changed + 1] = "cvars"
	end
	if profile.bindings and ApplyBindings(ns.EffectiveBindings()) then
		changed[#changed + 1] = "bindings"
	end
	profileApplied = true
	if #changed > 0 then
		ns.Print(("Profil angewendet (%s)."):format(table.concat(changed, ", ")))
	end
end

-- Capture: a binding or CVar the player changes anywhere (Blizzard's
-- Keybindings and Options menus, other addons) becomes an override instead of
-- being reverted at the next login. Client-state CVars (config.ignoredCVars)
-- and CVars the player can't set are left out.
local function CurrentBindings()
	local current = {}
	for index = 1, GetNumBindings() do
		local command = GetBinding(index)
		for _, key in ipairs(ns.GetBindingKeys(index)) do
			current[key] = command
		end
	end
	return current
end

local function OnBindingsChanged()
	if applying or not profileApplied or not config.profile.bindings then
		return
	end
	StevioUIConfig.bindings = ns.Overrides.Diff(config.profile.bindings, CurrentBindings())
end

-- CVar names are case-insensitive; the profile's or override's spelling wins.
local function KnownName(name)
	local lower = name:lower()
	for _, map in ipairs({ config.profile.cvars or {}, StevioUIConfig.cvars }) do
		for known in pairs(map) do
			if known:lower() == lower then
				return known
			end
		end
	end
	return name
end

local function OnCVarChanged(_, name)
	if applying or not profileApplied or not config.profile.cvars or not name or ns.IsIgnoredCVar(name) then
		return
	end
	local value, defaultValue, _, _, isLocked, isSecure, isReadOnly = C_CVar.GetCVarInfo(name)
	if value == nil or isLocked or isSecure or isReadOnly then
		return
	end
	name = KnownName(name)
	local profileValue = config.profile.cvars[name]
	-- Back at the profile's value (or, for a CVar outside the profile, at the
	-- game default) the override goes away again.
	if value == (profileValue or defaultValue) then
		StevioUIConfig.cvars[name] = nil
	else
		StevioUIConfig.cvars[name] = value
	end
end

ns:RegisterEvent("UPDATE_BINDINGS", OnBindingsChanged)
ns:RegisterEvent("CVAR_UPDATE", OnCVarChanged)

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
