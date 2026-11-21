local _, ns = ...

-- The lower right corner hides and shows as one, by key: the minimap with the
-- icons on it (mail, tracking, looking-for-group eye), the mark toolbar on its
-- top edge and the micro menu below it. The vehicle leave button stays, as
-- it's only there when it's needed. Whether the corner is hidden is kept in
-- StevioUIState, so it stays that way across sessions.
-- Loaded after the modules that build these frames (see stevio-ui.toc).
local Corner = ns.RegisterModule("corner", {})

local frames = {}
local hidden = false
local applying = false

local function SetFrameShown(frame)
	applying = true
	frame:SetShown(not hidden)
	applying = false
end

local function ApplyShown()
	for _, frame in ipairs(frames) do
		SetFrameShown(frame)
	end
end

-- The mark toolbar holds secure buttons, which makes its Show/Hide protected
-- in combat. Alpha is never restricted, so it takes effect immediately and the
-- real Show/Hide follows once combat allows it; the other frames hide at once.
local function Apply()
	for _, frame in ipairs(frames) do
		frame:SetAlpha(hidden and 0 or 1)
		if not (InCombatLockdown() and frame:IsProtected()) then
			SetFrameShown(frame)
		end
	end
	ns.RunAfterCombat(ApplyShown)
end

-- Bound to a key even before the module is enabled; then there is nothing to toggle.
function ns.ToggleCorner()
	if #frames == 0 then
		return
	end
	hidden = not hidden
	StevioUIState.cornerHidden = hidden or nil
	Apply()
end

function Corner:OnEnable()
	-- Blizzard re-shows the map on its own (minimap cluster, tutorials).
	local function Reassert()
		if hidden and not applying then
			Apply()
		end
	end
	-- The mark toolbar is missing while the marks module is off. The micro
	-- menu is the buttons' own frame rather than their Edit Mode container,
	-- so it stays hidden wherever Blizzard reparents it.
	for _, frame in pairs({ Minimap, _G.StevioUI_MarkBar, MicroMenu }) do
		frames[#frames + 1] = frame
		hooksecurefunc(frame, "Show", Reassert)
		hooksecurefunc(frame, "SetShown", Reassert)
	end

	hidden = StevioUIState.cornerHidden == true
	if hidden then
		Apply()
	end
end
