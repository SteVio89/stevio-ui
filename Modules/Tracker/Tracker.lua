local _, ns = ...

local config = ns.config.tracker
local badgeStyle = ns.config.style.badge

local Tracker = ns.RegisterModule("tracker", {})

local shown = false
local applying = false
local badge

-- The tracker holds secure quest item buttons, which makes Show/Hide protected
-- in combat. Alpha is never restricted, so it takes effect immediately and the
-- real Show/Hide follows once combat allows it.
local function ApplyShown()
	applying = true
	ObjectiveTrackerFrame:SetShown(shown)
	applying = false
end

local function Apply()
	applying = true
	ObjectiveTrackerFrame:SetAlpha(shown and 1 or 0)
	applying = false
	badge.texture:SetColorTexture(unpack(shown and badgeStyle.shownColor or badgeStyle.hiddenColor))
	ns.RunAfterCombat(ApplyShown)
end

function ns.ToggleTracker()
	shown = not shown
	Apply()
end

local function CreateBadge()
	local button = ns.CreateEdgeBadge("StevioUI_TrackerBadge", ns.layout.trackerBadge, ns.ToggleTracker)
	button.texture = button:CreateTexture(nil, "ARTWORK")
	button.texture:SetAllPoints()
	ns.CreateBorder(button)
	return button
end

function Tracker:OnEnable()
	ns.SetEditModeSystem(Enum.EditModeSystem.ObjectiveTracker, nil, ns.layout.tracker, {
		[Enum.EditModeObjectiveTrackerSetting.Height] = ns.EditModeStep(config.height, 400, 10),
	})

	-- Blizzard re-shows the tracker on its own (quest updates, layout passes).
	local function Reassert()
		if not shown and not applying then
			Apply()
		end
	end
	hooksecurefunc(ObjectiveTrackerFrame, "Show", Reassert)
	hooksecurefunc(ObjectiveTrackerFrame, "SetShown", Reassert)

	badge = CreateBadge()
	shown = config.shownOnLogin
	Apply()
end
