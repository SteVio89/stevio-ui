local _, ns = ...

local Auras = ns:RegisterModule("auras", {})

-- Blizzard's buff and debuff frames stay as they are; only their Edit Mode
-- position is owned here, so icon size and wrapping keep Blizzard's defaults.
function Auras:OnEnable()
	local indices = Enum.EditModeAuraFrameSystemIndices
	ns:SetEditModeSystem(Enum.EditModeSystem.AuraFrame, indices.BuffFrame, ns.layout.buffs)
	ns:SetEditModeSystem(Enum.EditModeSystem.AuraFrame, indices.DebuffFrame, ns.layout.debuffs)
end
