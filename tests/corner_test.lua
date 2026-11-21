-- Run with: lua tests/corner_test.lua  (from the repo root)
-- The lower right corner hides and shows as one by key, is remembered across
-- sessions, stays hidden when Blizzard re-shows the map, and waits for the
-- end of combat only with the protected mark toolbar (#66).
local check, loadAddonFile = dofile("tests/helpers.lua")

-- Hooks run after the hooked method, like the client's.
_G.hooksecurefunc = function(frame, method, hook)
	local original = frame[method]
	frame[method] = function(...)
		original(...)
		hook(...)
	end
end

local function Frame(protected)
	local frame = { shown = true, alpha = 1 }
	function frame:SetShown(shown)
		self.shown = shown
	end
	function frame:Show()
		self.shown = true
	end
	function frame:SetAlpha(alpha)
		self.alpha = alpha
	end
	function frame:IsProtected()
		return protected
	end
	return frame
end

local inCombat = false
_G.InCombatLockdown = function()
	return inCombat
end
local queued = {}
local function EndCombat()
	inCombat = false
	local pending = queued
	queued = {}
	for _, fn in ipairs(pending) do
		fn()
	end
end

-- A fresh session: the module loaded and enabled with the saved state.
local function Session(state)
	_G.Minimap, _G.StevioUI_MarkBar, _G.MicroMenu = Frame(false), Frame(true), Frame(false)
	_G.StevioUIState = state
	local module
	local ns = {
		RegisterModule = function(_, m)
			module = m
			return m
		end,
		RunAfterCombat = function(fn)
			if inCombat then
				queued[#queued + 1] = fn
			else
				fn()
			end
		end,
	}
	loadAddonFile("Modules/Corner/Corner.lua", ns)
	return ns, module
end

local function AllShown(shown)
	for _, frame in ipairs({ Minimap, StevioUI_MarkBar, MicroMenu }) do
		if frame.shown ~= shown or frame.alpha ~= (shown and 1 or 0) then
			return false
		end
	end
	return true
end

-- Before the module is enabled the key does nothing.
local ns, module = Session({ consented = true })
ns.ToggleCorner()
check(AllShown(true) and StevioUIState.cornerHidden == nil, "toggle before enable does nothing")

-- Shown on the first login, hidden and shown again by key.
module:OnEnable()
check(AllShown(true), "shown by default")
ns.ToggleCorner()
check(AllShown(false), "toggle hides map, mark toolbar and micro menu")
check(StevioUIState.cornerHidden == true, "hidden state saved")
Minimap:Show()
MicroMenu:SetShown(true)
check(AllShown(false), "stays hidden when Blizzard shows the frames again")
ns.ToggleCorner()
check(AllShown(true), "toggle shows them again")
check(StevioUIState.cornerHidden == nil, "shown state saved")

-- Hidden in the last session: hidden after login.
ns.ToggleCorner()
ns, module = Session(StevioUIState)
module:OnEnable()
check(AllShown(false), "hidden state restored at login")

-- In combat the protected toolbar only turns invisible until combat ends.
ns.ToggleCorner()
inCombat = true
ns.ToggleCorner()
check(not Minimap.shown and not MicroMenu.shown, "unprotected frames hide in combat")
check(StevioUI_MarkBar.shown and StevioUI_MarkBar.alpha == 0, "toolbar only invisible in combat")
EndCombat()
check(AllShown(false), "toolbar hides after combat")

-- Without the marks module the rest still toggles.
ns, module = Session({ consented = true })
_G.StevioUI_MarkBar = nil
module:OnEnable()
ns.ToggleCorner()
check(not Minimap.shown and not MicroMenu.shown, "toggles without the mark toolbar")

print("corner tests passed")
