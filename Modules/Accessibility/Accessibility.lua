local _, ns = ...

local Accessibility = ns:RegisterModule("accessibility", {})

BINDING_NAME_STEVIOUI_QUICKJUMP = GetLocale() == "deDE" and "Kürzel anzeigen / nächstes Fenster" or "Show labels / next window"

-- Popups come first because they usually block whatever else is open. A
-- dialog whose labels were used up gets them back before windows are cycled.
function ns.QuickJumpLeader()
	if ns.RequestPopupLabels() then
		return
	end
	if not ns.QuickJump:IsActive() and ns.IsDialogOpen() then
		ns.QuickJump:RequestRefresh()
		return
	end
	ns.CyclePanelLabels()
end

function Accessibility:OnEnable()
	ns.SetupDialogSources()
	ns.SetupTaxiList()
	ns.SetupPanelSource()
end
