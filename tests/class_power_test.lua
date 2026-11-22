-- Run with: lua tests/class_power_test.lua  (from the repo root)
-- Combo point segments: which events update them and where the points come
-- from (WoW Forever keeps them on the target).
local check, loadAddonFile = dofile("tests/helpers.lua")

local function Noop() end

-- A frame that records its events and script; segments record their value.
local function Frame()
	local frame = { events = {}, shown = true }
	function frame:RegisterEvent(event)
		self.events[event] = true
	end
	function frame:RegisterUnitEvent(event)
		self.events[event] = true
	end
	function frame:SetScript(_, handler)
		self.onEvent = handler
	end
	function frame:SetShown(shown)
		self.shown = shown
	end
	function frame:SetValue(value)
		self.value = value
	end
	frame.SetPoint, frame.SetHeight, frame.SetSize = Noop, Noop, Noop
	frame.SetMinMaxValues, frame.SetStatusBarColor = Noop, Noop
	function frame:GetWidth()
		return 100
	end
	return frame
end

local state
local function Setup()
	state = { class = "ROGUE", powerType = 3, onTarget = 0 }
	_G.Enum = { PowerType = { ComboPoints = 4, Energy = 3, Rage = 1 } }
	_G.PowerBarColor = { COMBO_POINTS = { r = 1, g = 0.9, b = 0 } }
	_G.UIParent = Frame()
	_G.UnitClass = function()
		return "Rogue", state.class
	end
	_G.UnitPowerType = function()
		return state.powerType
	end
	_G.GetComboPoints = function(unit, target)
		assert(unit == "player" and target == "target")
		return state.onTarget
	end

	local container
	local ns = {
		config = { units = { classPower = { gap = 2, height = 5, spacing = 2, max = 5 } } },
		CreateStatusBar = Frame,
		CreateBackground = Noop,
		CreateBorder = Noop,
	}
	local createFrame = Frame
	_G.CreateFrame = function()
		container = createFrame()
		return container
	end
	loadAddonFile("Modules/Units/ClassPower.lua", ns)
	ns.CreateClassPower(Frame())
	return container
end

local function Points(container)
	local value = container.segments[1].value
	for _, segment in ipairs(container.segments) do
		check(segment.value == value, "every segment gets the same value")
	end
	return value
end

-- Points follow the target.
local bar = Setup()
check(bar.events.PLAYER_TARGET_CHANGED and bar.events.COMBO_TARGET_CHANGED, "target events registered")
check(bar.events.UNIT_POWER_FREQUENT, "frequent power event registered")
state.onTarget = 4
bar:onEvent("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
check(Points(bar) == 4, "points on the target")
state.onTarget = 0
bar:onEvent("PLAYER_TARGET_CHANGED")
check(Points(bar) == 0, "a new target has its own points")
state.onTarget = 3
bar:onEvent("COMBO_TARGET_CHANGED")
check(Points(bar) == 3, "points moved to a new target")
state.onTarget = 5
bar:onEvent("UNIT_POWER_FREQUENT", "player", "ENERGY")
check(Points(bar) == 3, "other power leaves the segments alone")
print("target-bound combo points ok")

-- Visibility: rogues, and druids in cat form (energy).
bar = Setup()
check(bar.shown, "rogue")
state.class, state.powerType = "DRUID", 1
bar:onEvent("UNIT_DISPLAYPOWER", "player")
check(not bar.shown, "druid with rage")
state.powerType = 3
bar:onEvent("UNIT_DISPLAYPOWER", "player")
check(bar.shown, "druid with energy")
state.class = "WARRIOR"
bar:onEvent("PLAYER_ENTERING_WORLD")
check(not bar.shown, "warrior")
print("visibility ok")

print("class power tests passed")
