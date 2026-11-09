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
	local container = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
	container:SetSize(options.max * (options.size + options.spacing), options.size)
	ns.SetPoint(container, ns.layout.targetAuras)
	container:SetEditModePreviewEnabled(false)
	container:SetFlowLayoutAnchorPoint("TOPLEFT")
	container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
	container:AddAuraGroup("own", options.filter, {
		maxFrameCount = options.max,
		layout = { elementSpacing = options.spacing },
		initializeFrame = InitTargetAura,
	})
	container:SetUnit("target")
	container:SetEnabled(true)
	-- A new target brings a new set of auras; the container exposes
	-- UpdateAllAuras for such outside triggers and is left untouched otherwise.
	local watcher = CreateFrame("Frame")
	watcher:RegisterEvent("PLAYER_TARGET_CHANGED")
	watcher:SetScript("OnEvent", function()
		container:UpdateAllAuras()
	end)
end
