local _, ns = ...

local badgeStyle = ns.config.style.badge

local Tracker = ns:RegisterModule("tracker", {})

local isGerman = GetLocale() == "deDE"
BINDING_HEADER_STEVIOUI = "stevio-ui"
BINDING_NAME_STEVIOUI_TOGGLE_TRACKER = isGerman and "Questverfolgung ein-/ausblenden" or "Toggle objective tracker"

local shown = false
local applying = false
local badge

-- The tracker holds secure quest item buttons, which makes Show/Hide protected
-- in combat. Alpha is never restricted, so it takes effect immediately and the
-- real Show/Hide follows once combat allows it.
local function Apply()
	applying = true
	ObjectiveTrackerFrame:SetAlpha(shown and 1 or 0)
	applying = false
	badge.texture:SetColorTexture(unpack(shown and badgeStyle.shownColor or badgeStyle.hiddenColor))
	ns:RunAfterCombat(function()
		applying = true
		ObjectiveTrackerFrame:SetShown(shown)
		applying = false
	end)
end

function ns.ToggleTracker()
	shown = not shown
	Apply()
end

local function CreateBadge()
	local button = CreateFrame("Button", "StevioUI_TrackerBadge", UIParent)
	button:SetSize(badgeStyle.width, badgeStyle.height)
	ns.SetPoint(button, ns.layout.trackerBadge)
	button.texture = button:CreateTexture(nil, "ARTWORK")
	button.texture:SetAllPoints()
	ns.CreateBorder(button)
	button:SetScript("OnClick", ns.ToggleTracker)
	return button
end

-- Edit Mode stores the height as steps of 10 above 400.
local function HeightSetting(height)
	return (height - 400) / 10
end

function Tracker:OnEnable(config)
	ns:SetEditModeSystem(Enum.EditModeSystem.ObjectiveTracker, nil, ns.layout.tracker, {
		[Enum.EditModeObjectiveTrackerSetting.Height] = HeightSetting(config.height),
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
