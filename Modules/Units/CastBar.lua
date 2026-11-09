local _, ns = ...

local config = ns.config.units.castBar

-- Created with the first cast bar: the options panel's overrides only reach
-- the config once the saved variables are loaded, after this file ran.
local castColor, notInterruptibleColor

-- How often the remaining time text is redrawn.
local TIME_INTERVAL = 0.05

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

-- The pure part is kept on ns.CastBar for tests/cast_bar_test.lua.
local CastBar = {}
ns.CastBar = CastBar

-- What an event means for the bar: "stop", "start" (plus whether it is a
-- channel) or, for unit changes, "refresh".
function CastBar.CastAction(event)
	if stopEvents[event] then
		return "stop"
	elseif startEvents[event] ~= nil then
		return "start", startEvents[event]
	end
	return "refresh"
end

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

-- Spell name and remaining seconds may be secret; the font strings take them as they are.
local function Start(castBar, isChannel)
	local unit = castBar.unit
	local name, isTradeskill, notInterruptible, duration, _
	if isChannel then
		-- name, displayName, texture, startTime, endTime, isTradeskill, notInterruptible, ...
		name, _, _, _, _, isTradeskill, notInterruptible = UnitChannelInfo(unit)
		duration = UnitChannelDuration(unit)
	else
		-- name, displayName, texture, startTime, endTime, isTradeskill, castID, notInterruptible, ...
		name, _, _, _, _, isTradeskill, _, notInterruptible = UnitCastingInfo(unit)
		duration = UnitCastingDuration(unit)
	end

	-- isTradeskill is never secret, which makes it the one safe "is there a cast" check.
	if isTradeskill == nil then
		castBar:Hide()
		return
	end

	ApplyColor(castBar:GetStatusBarTexture(), notInterruptible)
	local direction = isChannel and Enum.StatusBarTimerDirection.RemainingTime
		or Enum.StatusBarTimerDirection.ElapsedTime
	castBar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, direction)
	castBar.duration = duration
	castBar.spellName:SetText(name)
	castBar.elapsed = TIME_INTERVAL
	castBar:Show()
end

local function Refresh(castBar)
	Start(castBar, false)
	if not castBar:IsShown() then
		Start(castBar, true)
	end
end

local function OnEvent(castBar, event)
	local action, isChannel = CastBar.CastAction(event)
	if action == "stop" then
		castBar:Hide()
	elseif action == "start" then
		Start(castBar, isChannel)
	else
		Refresh(castBar)
	end
end

local function OnUpdate(castBar, elapsed)
	castBar.elapsed = castBar.elapsed + elapsed
	if castBar.elapsed < TIME_INTERVAL or not castBar.duration then
		return
	end
	castBar.elapsed = 0
	castBar.time:SetFormattedText("%.1f", castBar.duration:GetRemainingDuration())
end

-- `options`: height and fontSize (default: the castBar config).
function ns.CreateCastBar(unit, sizeFrame, anchor, align, options)
	options = options or {}
	castColor = castColor or CreateColor(unpack(config.color))
	notInterruptibleColor = notInterruptibleColor or CreateColor(unpack(config.notInterruptibleColor))
	local castBar = ns.CreateStatusBar(UIParent)
	castBar.unit = unit
	castBar:SetSize(sizeFrame:GetWidth(), options.height or config.height)
	castBar:SetPoint("TOP" .. align, anchor, "BOTTOM" .. align, 0, -config.gap)
	ns.CreateBackground(castBar)
	ns.CreateBorder(castBar)

	local fontSize = options.fontSize or config.fontSize
	castBar.time = ns.CreateFontString(castBar, fontSize, "RIGHT")
	castBar.time:SetPoint("RIGHT", -3, 0)
	castBar.spellName = ns.CreateFontString(castBar, fontSize, "LEFT")
	castBar.spellName:SetPoint("LEFT", 3, 0)
	castBar.spellName:SetPoint("RIGHT", castBar.time, "LEFT", -4, 0)
	castBar:Hide()

	for event in pairs(startEvents) do
		castBar:RegisterUnitEvent(event, unit)
	end
	for event in pairs(stopEvents) do
		castBar:RegisterUnitEvent(event, unit)
	end
	-- A unit change starts over with whatever the new unit is casting.
	if ns.UNIT_CHANGE_EVENTS[unit] then
		castBar:RegisterEvent(ns.UNIT_CHANGE_EVENTS[unit])
	end
	castBar:SetScript("OnEvent", OnEvent)
	castBar:SetScript("OnUpdate", OnUpdate)
end
