local addonName, ns = ...

-- The backup of the player's own settings and /sui restore handing it back.

-- Taken once when the player agrees to the takeover, so /sui restore can hand
-- back what the profile overwrote. It holds every CVar, so CVars added to the
-- profile later can be handed back too.
function ns.CaptureBackup()
	local backup = {
		actionBars = ns.CurrentActionBarToggles(),
		bindings = (ns.BoundKeys()),
		bindingSet = GetCurrentBindingSet(),
		cvars = {},
		editModeLayout = ns.GetActiveEditModeLayout(),
	}
	ns.ForEachCVar(function(name, value)
		backup.cvars[name] = value
	end)
	return backup
end

-- Only the CVars stevio-ui manages (profile and overrides) go back, so
-- settings stevio-ui never touched stay. Backups from before the full snapshot
-- lack CVars the profile gained since; those go back to the default.
local function RestoreCVars(apply, backupCVars)
	local values = {}
	for name in pairs(apply.EffectiveCVars()) do
		values[name] = backupCVars[name] or C_CVar.GetCVarDefault(name)
	end
	apply.CVars(values)
end

-- `apply` holds Settings.lua's ActionBars, CVars, Bindings and EffectiveCVars,
-- so the backup goes back the same way the profile goes in.
function ns.RestoreBackup(apply)
	local backup = StevioUIState and StevioUIState.backup
	if not backup then
		ns.Print(ns.T("No backup found.", "Keine Sicherung vorhanden."))
		return
	end
	apply.ActionBars(backup.actionBars)
	RestoreCVars(apply, backup.cvars)
	apply.Bindings(backup.bindings, backup.bindingSet)
	ns.RestoreEditModeLayout(backup.editModeLayout)
	-- Forgetting the consent makes a later re-enable ask again and take a fresh backup.
	StevioUIState = nil
	C_AddOns.DisableAddOn(addonName)
	ReloadUI()
end
