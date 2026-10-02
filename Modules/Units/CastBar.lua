local _, ns = ...

local config = ns.config.units.castBar

local castColor = CreateColor(unpack(config.color))
local notInterruptibleColor = CreateColor(unpack(config.notInterruptibleColor))

local startEvents = {
	UNIT_SPELLCAST_START = false,
	UNIT_SPELLCAST_DELAYED = false,
	UNIT_SPELLCAST_INTERRUPTIBLE = false,
	UNIT_SPELLCAST_NOT_INTERRUPTIBLE = false,
	UNIT_SPELLCAST_CHANNEL_START = true,
	UNIT_SPELLCAST_CHANNEL_UPDATE = true,
}

local stopEvents = {
	UNIT_SPELLCAST_STOP = true,
	UNIT_SPELLCAST_FAILED = true,
	UNIT_SPELLCAST_INTERRUPTED = true,
	UNIT_SPELLCAST_CHANNEL_STOP = true,
}

-- The notInterruptible flag may be secret, and secret booleans can't be branched on;
-- the FromBoolean setter lets the client resolve the color instead.
local function ApplyColor(texture, notInterruptible)
	if issecretvalue(notInterruptible) then
		texture:SetVertexColorFromBoolean(notInterruptible, notInterruptibleColor, castColor)
	else
		local color = notInterruptible and notInterruptibleColor or castColor
		texture:SetVertexColor(color:GetRGB())
	end
end

local function Start(castBar, isChannel)
	local unit = castBar.unit
	local isTradeskill, notInterruptible, duration
	if isChannel then
		isTradeskill, notInterruptible = select(6, UnitChannelInfo(unit))
		duration = UnitChannelDuration(unit)
	else
		local _
		isTradeskill, _, notInterruptible = select(6, UnitCastingInfo(unit))
		duration = UnitCastingDuration(unit)
	end

	-- isTradeskill is never secret, which makes it the one safe "is there a cast" check.
	if isTradeskill == nil then
		castBar:Hide()
		return
	end

	ApplyColor(castBar:GetStatusBarTexture(), notInterruptible)
	local direction = isChannel and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime
	castBar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, direction)
	castBar:Show()
end

local function Refresh(castBar)
	Start(castBar, false)
	if not castBar:IsShown() then
		Start(castBar, true)
	end
end

local function OnEvent(castBar, event)
	if stopEvents[event] then
		castBar:Hide()
	elseif startEvents[event] ~= nil then
		Start(castBar, startEvents[event])
	else
		Refresh(castBar)
	end
end

function ns.CreateCastBar(unit, sizeFrame, anchor, align)
	local castBar = ns.CreateStatusBar(UIParent)
	castBar.unit = unit
	castBar:SetSize(sizeFrame:GetWidth(), config.height)
	castBar:SetPoint("TOP" .. align, anchor, "BOTTOM" .. align, 0, -config.gap)
	ns.CreateBackground(castBar)
	ns.CreateBorder(castBar)
	castBar:Hide()

	for event in pairs(startEvents) do
		castBar:RegisterUnitEvent(event, unit)
	end
	for event in pairs(stopEvents) do
		castBar:RegisterUnitEvent(event, unit)
	end
	if unit == "target" then
		castBar:RegisterEvent("PLAYER_TARGET_CHANGED")
	end
	castBar:SetScript("OnEvent", OnEvent)

	return castBar
end
