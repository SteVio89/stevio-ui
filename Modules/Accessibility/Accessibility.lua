local _, ns = ...

local Accessibility = ns.RegisterModule("accessibility", {})
local Internal = ns.AccessibilityInternal

-- Popups come first because they usually block whatever else is open. An
-- open quest, gossip or flight master dialog comes next, then the windows.
function ns.QuickJumpLeader()
	if Internal.RequestPopupLabels() then
		return
	end
	if Internal.RequestDialogLabels(Internal.IsCyclingPanels()) then
		return
	end
	Internal.CyclePanelLabels()
end

function Accessibility:OnEnable()
	Internal.SetupQuickJump()
	Internal.SetupDialogSources()
	Internal.SetupTaxiList()
	Internal.SetupPanelSource()
end
