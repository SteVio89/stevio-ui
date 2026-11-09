local _, ns = ...

local Accessibility = ns.RegisterModule("accessibility", {})
local Internal = ns.AccessibilityInternal

-- Popups come first because they usually block whatever else is open. A
-- dialog whose labels were used up gets them back before windows are cycled.
function ns.QuickJumpLeader()
	if Internal.RequestPopupLabels() then
		return
	end
	if not ns.QuickJump:IsActive() and Internal.IsDialogOpen() then
		ns.QuickJump:RequestRefresh()
		return
	end
	Internal.CyclePanelLabels()
end

function Accessibility:OnEnable()
	Internal.SetupDialogSources()
	Internal.SetupTaxiList()
	Internal.SetupPanelSource()
end
