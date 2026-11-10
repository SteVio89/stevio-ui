-- Run with: lua tests/cast_bar_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")
local ns = loadAddonFile("Modules/Units/CastBar.lua", { config = { units = { castBar = {} } } })
local CastAction = ns.CastBar.CastAction

local function is(event, action, isChannel)
	local gotAction, gotChannel = CastAction(event)
	return gotAction == action and gotChannel == isChannel
end

check(is("UNIT_SPELLCAST_START", "start", false), "cast start")
check(is("UNIT_SPELLCAST_DELAYED", "start", false), "pushback restarts the cast")
check(is("UNIT_SPELLCAST_CHANNEL_START", "start", true), "channel start")
check(is("UNIT_SPELLCAST_CHANNEL_UPDATE", "start", true), "channel update")

check(is("UNIT_SPELLCAST_STOP", "stop"), "cast stop")
check(is("UNIT_SPELLCAST_FAILED", "stop"), "failed")
check(is("UNIT_SPELLCAST_INTERRUPTED", "stop"), "interrupted")
check(is("UNIT_SPELLCAST_CHANNEL_STOP", "stop"), "channel stop")

check(is("PLAYER_TARGET_CHANGED", "refresh"), "new target")
check(is("PLAYER_FOCUS_CHANGED", "refresh"), "new focus")
-- Also fired during a channel, so they refresh whichever is running.
check(is("UNIT_SPELLCAST_INTERRUPTIBLE", "refresh"), "interruptible again")
check(is("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "refresh"), "no longer interruptible")

print("cast bar tests passed")
