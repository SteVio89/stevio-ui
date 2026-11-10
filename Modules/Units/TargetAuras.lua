local _, ns = ...

local config = ns.config.units

-- The size is read on every call, as buttons are created when first needed.
local function InitTargetAura(button)
	ns.InitAuraButton(button, config.targetAuras.size, 10)
end

-- Own debuffs on the target: target auras turn secret in combat, so
-- Blizzard's secure container reads and tracks them (see Group/Cell.lua).
function ns.CreateTargetAuras()
	local options = config.targetAuras
	local container = ns.CreateAuraContainer(UIParent, {
		place = function(container)
			container:SetSize(options.max * (options.size + options.spacing), options.size)
			ns.SetPoint(container, ns.LayoutPosition("targetAuras"))
		end,
		flowAnchor = "TOPLEFT",
		growth = AnchorUtil.FlowDirection.Right,
		key = "own",
		filter = options.filter,
		max = options.max,
		spacing = options.spacing,
		initializeFrame = InitTargetAura,
		unit = "target",
	})
	-- A new target brings a new set of auras; the container exposes
	-- UpdateAllAuras for such outside triggers and is left untouched otherwise.
	-- No other handler of the event reads the container, so their order doesn't matter.
	ns.RegisterEvent("PLAYER_TARGET_CHANGED", function()
		container:UpdateAllAuras()
	end)
end
