-- Run with: lua tests/notch_zone_test.lua  (from the repo root)
local ns = {}
assert(loadfile("Modules/Notch/Zone.lua"))("stevio-ui", ns)
local Zone = ns.NotchZone

local function check(cond, msg)
	if not cond then
		error("FAIL: " .. msg, 2)
	end
end

local notch = { left = 100, right = 300, bottom = 960 }
local island = { left = 40, right = 360, bottom = 800 }
local options = { hideDelay = 0.3, margin = 6 }

local function step(state, x, y, elapsed, extra)
	local input = { x = x, y = y, notch = notch, island = state.shown and island or nil }
	for k, v in pairs(extra or {}) do
		input[k] = v
	end
	return Zone.Step(state, input, elapsed or 0.05, options)
end

-- Open top: the cursor at or even past the top edge still counts.
check(Zone.Contains(notch, 200, 1000), "inside notch")
check(Zone.Contains(notch, 200, 1000.4), "above the top edge counts")
check(not Zone.Contains(notch, 200, 950), "below the notch")
check(not Zone.Contains(nil, 0, 0), "no rect yet")

local state = Zone.New()
check(not step(state, 200, 500), "hidden away from the notch")
check(step(state, 200, 999), "cursor resting in the notch shows without an enter event")
check(step(state, 50, 850), "stays open over the island")
check(step(state, 37, 850), "stays open within the margin")

-- Leaving the island only hides after the delay.
check(step(state, 200, 700, 0.1), "brief slip outside keeps it open")
check(step(state, 200, 850, 0.1), "back inside")
check(step(state, 200, 700, 0.2), "outside timer was reset")
check(not step(state, 200, 700, 0.15), "hides after the delay")
check(not step(state, 200, 850), "island area alone does not reopen it")

-- Turning the camera hides it; it returns when the cursor shows again in the notch.
check(step(state, 200, 999), "open again")
check(not step(state, 200, 999, 0.05, { cursorHidden = true }), "hidden while mouselooking")
check(step(state, 200, 999), "back after mouselook with the cursor still in the notch")

print("notch zone tests passed")
