local _, ns = ...

local config = ns.config.notch
local colors = config.colors

local Notch = ns:RegisterModule("notch", {})

-- Nothing is visible until the cursor reaches the notch; then a black island
-- grows out of it with information that is only needed now and then.

local L = GetLocale() == "deDE" and {
	level = "Stufe %d",
	rested = "Erholt",
	gold = "Gold",
	bags = "Taschen",
	bagsValue = "%d / %d frei",
	durability = "Haltbarkeit",
	time = "Uhrzeit",
	system = "System",
	online = "Online",
	friends = "Freunde %d",
	guild = "Gilde %d",
} or {
	level = "Level %d",
	rested = "Rested",
	gold = "Gold",
	bags = "Bags",
	bagsValue = "%d / %d free",
	durability = "Durability",
	time = "Time",
	system = "System",
	online = "Online",
	friends = "Friends %d",
	guild = "Guild %d",
}

local hover, island
local notchHeight = 0
local rows = {}

local function SetBar(row, min, max, value, overlayValue, r, g, b)
	row.bar:SetMinMaxValues(min, max)
	row.bar:SetValue(value)
	row.bar:SetStatusBarColor(r, g, b)
	row.overlay:SetMinMaxValues(min, max)
	row.overlay:SetValue(overlayValue)
	row.overlay:SetStatusBarColor(r, g, b, colors.restedAlpha)
end

local function HasXP()
	return not GameRulesUtil.IsPlayerAtEffectiveMaxLevel() and not IsXPUserDisabled() and UnitXPMax("player") > 0
end

local function UpdateXP(row)
	if not HasXP() then
		return false
	end
	local current, max = UnitXP("player"), UnitXPMax("player")
	local rested = GetXPExhaustion() or 0
	local color = GetRestState() == 1 and colors.xpRested or colors.xp
	row.label:SetFormattedText(L.level, UnitLevel("player"))
	row.value:SetFormattedText("%d %% · %s / %s", floor(current / max * 100), BreakUpLargeNumbers(current), BreakUpLargeNumbers(max))
	SetBar(row, 0, max, current, math.min(current + rested, max), unpack(color))
	return true
end

local function UpdateRested(row)
	local rested = GetXPExhaustion()
	if not HasXP() or not rested or rested <= 0 then
		return false
	end
	row.label:SetText(L.rested)
	row.value:SetFormattedText("+%d %%", floor(rested / UnitXPMax("player") * 100))
	return true
end

local function UpdateReputation(row)
	local data = C_Reputation.GetWatchedFactionData()
	if not data or data.factionID == 0 then
		return false
	end
	local standing = GetText("FACTION_STANDING_LABEL" .. data.reaction, UnitSex("player")) or ""
	local min, max, value = data.currentReactionThreshold, data.nextReactionThreshold, data.currentStanding
	row.label:SetText(data.name)
	-- The top standing has no next threshold; show it as a full bar.
	if max > min then
		row.value:SetFormattedText("%s · %s / %s", standing, BreakUpLargeNumbers(value - min), BreakUpLargeNumbers(max - min))
	else
		row.value:SetText(standing)
		min, max, value = 0, 1, 1
	end
	local color = FACTION_BAR_COLORS[data.reaction] or FACTION_BAR_COLORS[#FACTION_BAR_COLORS]
	SetBar(row, min, max, value, 0, color:GetRGB())
	return true
end

local function UpdateGold(row)
	row.label:SetText(L.gold)
	row.value:SetText(GetMoneyString(GetMoney(), true))
	return true
end

local function UpdateBags(row)
	local free, total = 0, 0
	for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		local numFree, family = C_Container.GetContainerNumFreeSlots(bag)
		-- Quivers and other special bags only take their own item types.
		if family == 0 then
			free = free + numFree
			total = total + C_Container.GetContainerNumSlots(bag)
		end
	end
	row.label:SetText(L.bags)
	row.value:SetFormattedText(L.bagsValue, free, total)
	return true
end

local function UpdateDurability(row)
	local lowest
	for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
		local current, max = GetInventoryItemDurability(slot)
		if current and max > 0 then
			lowest = math.min(lowest or 1, current / max)
		end
	end
	if not lowest then
		return false
	end
	local color = colors.value
	if lowest <= config.durabilityCritical then
		color = colors.critical
	elseif lowest <= config.durabilityWarn then
		color = colors.warn
	end
	row.label:SetText(L.durability)
	row.value:SetFormattedText("%d %%", floor(lowest * 100))
	row.value:SetTextColor(unpack(color))
	return true
end

local function UpdateZone(row)
	local zone, subZone = GetZoneText(), GetSubZoneText()
	row.label:SetText((subZone ~= "" and subZone ~= zone) and (zone .. " – " .. subZone) or zone)
	-- Instances have no player position.
	local mapID = C_Map.GetBestMapForUnit("player")
	local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
	if position then
		local x, y = position:GetXY()
		row.value:SetFormattedText("%.1f, %.1f", x * 100, y * 100)
	else
		row.value:SetText("")
	end
	return true
end

local function UpdateTime(row)
	row.label:SetText(L.time)
	row.value:SetText(date("%H:%M"))
	return true
end

local function UpdateSystem(row)
	local _, _, home, world = GetNetStats()
	row.label:SetText(L.system)
	row.value:SetFormattedText("%d fps · %d / %d ms", floor(GetFramerate() + 0.5), home, world)
	return true
end

local function UpdateOnline(row)
	local _, bnetOnline = BNGetNumFriends()
	local text = L.friends:format((C_FriendList.GetNumOnlineFriends() or 0) + (bnetOnline or 0))
	if IsInGuild() then
		local _, guildOnline = GetNumGuildMembers()
		text = text .. " · " .. L.guild:format(guildOnline or 0)
	end
	row.label:SetText(L.online)
	row.value:SetText(text)
	return true
end

local rowSpecs = {
	{ update = UpdateXP, bar = true },
	{ update = UpdateRested },
	{ update = UpdateReputation, bar = true },
	{ update = UpdateGold },
	{ update = UpdateBags },
	{ update = UpdateDurability },
	{ update = UpdateZone, groupStart = true },
	{ update = UpdateTime },
	{ update = UpdateSystem },
	{ update = UpdateOnline },
}

local function CreateRow(spec)
	local row = CreateFrame("Frame", nil, island)
	row.spec = spec

	-- The value sizes to its text; the label takes the rest and truncates.
	row.value = ns.CreateFontString(row, nil, "RIGHT")
	row.value:SetPoint("TOPRIGHT")
	row.value:SetTextColor(unpack(colors.value))
	row.label = ns.CreateFontString(row)
	row.label:SetPoint("TOPLEFT")
	row.label:SetPoint("RIGHT", row.value, "LEFT", -8, 0)
	row.label:SetTextColor(unpack(colors.label))

	local height = config.rowHeight
	if spec.bar then
		-- The overlay sits behind the bar and shows rested XP beyond the fill.
		row.overlay = ns.CreateStatusBar(row)
		row.overlay:SetPoint("BOTTOMLEFT")
		row.overlay:SetPoint("BOTTOMRIGHT")
		row.overlay:SetHeight(config.barHeight)
		local background = row.overlay:CreateTexture(nil, "BACKGROUND")
		background:SetAllPoints()
		background:SetColorTexture(unpack(colors.barBackground))

		row.bar = ns.CreateStatusBar(row)
		row.bar:SetAllPoints(row.overlay)
		row.bar:SetFrameLevel(row.overlay:GetFrameLevel() + 1)

		height = height + config.barGap + config.barHeight
	end
	row:SetHeight(height)
	return row
end

local function Refresh()
	-- Content starts below the notch, whose area is covered by the hardware.
	local y = notchHeight + config.padding
	local first = true
	for _, row in ipairs(rows) do
		local shown = row.spec.update(row)
		row:SetShown(shown)
		if shown then
			if not first then
				y = y + (row.spec.groupStart and config.groupGap or config.rowGap)
			end
			row:SetPoint("TOPLEFT", island, "TOPLEFT", config.padding, -y)
			row:SetPoint("TOPRIGHT", island, "TOPRIGHT", -config.padding, -y)
			y = y + row:GetHeight()
			first = false
		end
	end
	island:SetHeight(y + config.padding)
end

-- Returns the notch in UIParent units: left and right edge, height, and how far
-- the real screen top lies above UIParent's top. UIParent may be shifted below
-- the notch depending on the notch display mode; anchoring against the screen
-- top works in every mode.
local function GetNotchRect()
	local physicalWidth, physicalHeight = GetPhysicalScreenSize()
	local scale = UIParent:GetWidth() / physicalWidth
	local topOffset = physicalHeight * scale - UIParent:GetTop()

	local _, leftEarRight, _, leftEarBottom = C_UI.GetTopLeftNotchSafeRegion()
	local rightEarLeft = C_UI.GetTopRightNotchSafeRegion()
	if leftEarBottom > 0 and rightEarLeft > leftEarRight then
		return leftEarRight * scale, rightEarLeft * scale, leftEarBottom * scale, topOffset
	end

	local left = (UIParent:GetWidth() - config.fallback.width) / 2
	return left, left + config.fallback.width, config.fallback.height, topOffset
end

local function UpdateGeometry()
	local left, right, height, topOffset = GetNotchRect()
	notchHeight = height

	hover:ClearAllPoints()
	hover:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left, topOffset)
	hover:SetSize(right - left, height + config.hoverBelow)

	island:ClearAllPoints()
	island:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left - config.extraWidth, topOffset)
	island:SetWidth(right - left + 2 * config.extraWidth)

	if island:IsShown() then
		Refresh()
	end
end

local function CreateIsland()
	-- No mouse on the island itself, so clicks and camera drags pass through.
	island = CreateFrame("Frame", "StevioUI_NotchIsland", UIParent)
	island:SetFrameStrata("FULLSCREEN_DIALOG")
	island:Hide()
	local background = island:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(unpack(colors.background))

	for _, spec in ipairs(rowSpecs) do
		rows[#rows + 1] = CreateRow(spec)
	end

	-- While hidden the island does no work at all; while shown it polls, which
	-- also covers values without change events (FPS, latency, time, position).
	island:SetScript("OnShow", function(self)
		self.elapsed = 0
		if IsInGuild() then
			C_GuildInfo.GuildRoster()
		end
		Refresh()
	end)
	island:SetScript("OnUpdate", function(self, elapsed)
		if not (self:IsMouseOver() or hover:IsMouseOver()) then
			self:Hide()
			return
		end
		self.elapsed = self.elapsed + elapsed
		if self.elapsed >= config.updateInterval then
			self.elapsed = 0
			Refresh()
		end
	end)

	-- Motion only: clicks and camera drags starting at the notch still reach the world.
	hover = CreateFrame("Frame", "StevioUI_NotchHover", UIParent)
	hover:SetFrameStrata("FULLSCREEN_DIALOG")
	hover:SetMouseMotionEnabled(true)
	hover:SetMouseClickEnabled(false)
	hover:SetScript("OnEnter", function()
		island:Show()
	end)
end

-- Dumps the notch geometry for checking the placement outside the game.
local function DumpGeometry()
	local physicalWidth, physicalHeight = GetPhysicalScreenSize()
	local lines = {
		("physical: %d x %d"):format(physicalWidth, physicalHeight),
		"left ear: " .. strjoin(", ", tostringall(C_UI.GetTopLeftNotchSafeRegion())),
		"right ear: " .. strjoin(", ", tostringall(C_UI.GetTopRightNotchSafeRegion())),
		("avoid notch: %s, NotchedDisplayMode: %s"):format(tostring(C_UI.ShouldUIParentAvoidNotch()), tostring(C_CVar.GetCVar("NotchedDisplayMode"))),
		("UIParent: %.1f x %.1f, top %.1f, effective scale %.3f"):format(UIParent:GetWidth(), UIParent:GetHeight(), UIParent:GetTop(), UIParent:GetEffectiveScale()),
		("notch: left %.1f, right %.1f, height %.1f, top offset %.1f"):format(GetNotchRect()),
		("hover: left %.1f, right %.1f, top %.1f, bottom %.1f"):format(hover:GetLeft(), hover:GetRight(), hover:GetTop(), hover:GetBottom()),
	}
	local text = table.concat(lines, "\n")
	StevioUIDebug = text
	ns.ShowExportWindow(text)
end

function Notch:OnEnable()
	CreateIsland()
	UpdateGeometry()

	-- Blizzard shifts UIParent below the notch only later (entering the world,
	-- notch mode or display changes); the offset to the screen top must follow.
	hooksecurefunc("UpdateUIParentPosition", UpdateGeometry)
	ns:RegisterEvent("UI_SCALE_CHANGED", function()
		C_Timer.After(0, UpdateGeometry)
	end)

	ns:RegisterSlashCommand("notch", DumpGeometry)
end
