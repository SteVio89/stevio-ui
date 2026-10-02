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
local function ApplyBindings(bindings)
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
	if changed or GetCurrentBindingSet() ~= Enum.BindingSet.Account then
		SaveBindings(Enum.BindingSet.Account)
	end
	return changed
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
-- first PLAYER_ENTERING_WORLD both are in place.
local applied = false
ns:RegisterEvent("PLAYER_ENTERING_WORLD", function()
	if applied or not config.enabled then
		return
	end
	applied = true
	ns:RunAfterCombat(ApplyProfile)
end)

function Settings:OnEnable()
	ns:RegisterSlashCommand("export", function()
		local text = ns.BuildProfileExport()
		StevioUIExport = text
		ns.ShowExportWindow(text)
	end)
	ns:RegisterSlashCommand("apply", function()
		ns:RunAfterCombat(ApplyProfile)
	end)
end
