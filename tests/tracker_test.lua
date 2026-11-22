-- Run with: lua tests/tracker_test.lua  (from the repo root)
-- The objective tracker toggle: alpha at once, the real Show/Hide only out of
-- combat and only once our Edit Mode layout is in place.
local check, loadAddonFile = dofile("tests/helpers.lua")

local function Noop() end

-- ObjectiveTrackerFrame with hooks that run after the method, like hooksecurefunc.
local tracker = { shown = true, alpha = 1, hooks = {} }
function tracker:SetShown(shown)
	self.shown = shown
	for _, hook in ipairs(self.hooks.SetShown or {}) do
		hook(self, shown)
	end
end
function tracker:Show()
	self:SetShown(true)
end
function tracker:SetAlpha(alpha)
	self.alpha = alpha
end
_G.ObjectiveTrackerFrame = tracker
function _G.hooksecurefunc(object, method, hook)
	object.hooks[method] = object.hooks[method] or {}
	table.insert(object.hooks[method], hook)
end
_G.Enum = {
	EditModeSystem = { ObjectiveTracker = 12 },
	EditModeObjectiveTrackerSetting = { Height = 0 },
}

local inCombat, queued = false, {}
local layoutCallbacks = {}
local editModeSettings, module
local ns = {
	config = {
		tracker = { shownOnLogin = false, height = 460 },
		style = { badge = { shownColor = { 1, 1, 1, 1 }, hiddenColor = { 0, 0, 0, 1 } } },
	},
	layout = { tracker = {}, trackerBadge = {} },
	RegisterModule = function(_, table)
		module = table
		return table
	end,
	EditModeStep = function(value, minimum, step)
		return (value - minimum) / step
	end,
	SetEditModeSystem = function(_, _, _, settings)
		editModeSettings = settings
	end,
	CreateEdgeBadge = function()
		return {
			CreateTexture = function()
				return { SetAllPoints = Noop, SetColorTexture = Noop }
			end,
		}
	end,
	CreateBorder = Noop,
	RunAfterCombat = function(fn)
		if inCombat then
			queued[#queued + 1] = fn
		else
			fn()
		end
	end,
	OnEditModeLayoutApplied = function(fn)
		layoutCallbacks[#layoutCallbacks + 1] = fn
	end,
}
local function EndCombat()
	inCombat = false
	local due = queued
	queued = {}
	for _, fn in ipairs(due) do
		fn()
	end
end
loadAddonFile("Modules/Tracker/Tracker.lua", ns)

-- The key does nothing while the module isn't enabled.
ns.ToggleTracker()
check(tracker.shown and tracker.alpha == 1, "toggle before enabling does nothing")

-- Enabled hidden: invisible at once, really hidden only once the layout is in place.
module:OnEnable()
check(editModeSettings[0] == 6, "height 460 is Edit Mode step 6")
check(tracker.alpha == 0, "invisible at once")
check(tracker.shown, "not hidden before our layout is in place")
ns.ToggleTracker()
check(tracker.alpha == 1 and tracker.shown, "toggled on before the layout")
ns.ToggleTracker()
check(tracker.alpha == 0 and tracker.shown, "toggled off before the layout: still only invisible")
check(#layoutCallbacks == 1, "waits for the layout")
layoutCallbacks[1]()
check(not tracker.shown, "hidden once the layout is in place")
print("login ok")

-- Toggling afterwards.
ns.ToggleTracker()
check(tracker.shown and tracker.alpha == 1, "shown")
ns.ToggleTracker()
check(not tracker.shown and tracker.alpha == 0, "hidden")

-- Blizzard showing it again is undone.
tracker:Show()
check(not tracker.shown and tracker.alpha == 0, "re-shown by Blizzard is hidden again")

-- In combat: alpha now, Show/Hide after combat.
ns.ToggleTracker()
inCombat = true
ns.ToggleTracker()
check(tracker.alpha == 0 and tracker.shown, "in combat only invisible")
EndCombat()
check(not tracker.shown, "hidden after combat")
print("toggle ok")

print("tracker tests passed")
