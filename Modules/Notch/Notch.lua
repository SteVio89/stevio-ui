local _, ns = ...

local config = ns.config.notch
local colors = config.colors
local style = ns.config.style

local Notch = ns.RegisterModule("notch", {})

-- Nothing is visible until the cursor reaches the notch; then a black island
-- grows out of it with information that is only needed now and then.

local L = ns.isGerman
		and {
			level = "Stufe",
			rested = "Erholt",
			gold = "Gold",
			bags = "Taschen",
			free = "frei",
			durability = "Haltbarkeit",
			time = "Uhrzeit",
			system = "System",
			friends = "Freunde",
			friendsGuild = "Freunde · Gilde",
		}
	or {
		level = "Level",
		rested = "Rested",
		gold = "Gold",
		bags = "Bags",
		free = "free",
		durability = "Durability",
		time = "Time",
		system = "System",
		friends = "Friends",
		friendsGuild = "Friends · Guild",
	}

local CORNER_TEXTURE = "Interface\\AddOns\\stevio-ui\\Media\\Corner"

local Zone = ns.NotchZone
local Buttons = ns.NotchButtons
local Layout = ns.NotchLayout

local island
local notchHeight = 0
-- Trigger area in UIParent units ({ left, right, bottom }), see Zone.Contains.
local notchRect
local rows = {}

-- Color codes of the theme's text colors, set when the island is created.
local strong, normal, muted, faint

local function SetBar(row, min, max, value, overlayValue)
	row.bar:SetMinMaxValues(min, max)
	row.bar:SetValue(value)
	row.overlay:SetMinMaxValues(min, max)
	row.overlay:SetValue(overlayValue)
end

local function HasXP()
	return not GameRulesUtil.IsPlayerAtEffectiveMaxLevel() and not IsXPUserDisabled() and UnitXPMax("player") > 0
end

-- "Level 36" and "57 % · 40,861 / 71,600" above a bar fading from the
-- theme's xpFrom to xpTo, with rested XP as an overlay beyond the fill.
local function UpdateXP(row)
	if not HasXP() then
		return false
	end
	local current, max = UnitXP("player"), UnitXPMax("player")
	local rested = GetXPExhaustion() or 0
	row.label:SetText(("%s%s|r %s%d|r"):format(muted, L.level, strong, UnitLevel("player")))
	row.value:SetFormattedText(
		"%s%d %%|r %s· %s / %s|r",
		normal,
		floor(current / max * 100),
		muted,
		BreakUpLargeNumbers(current),
		BreakUpLargeNumbers(max)
	)
	SetBar(row, 0, max, current, math.min(current + rested, max))
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
		row.value:SetFormattedText(
			"%s %s· %s / %s|r",
			standing,
			muted,
			BreakUpLargeNumbers(value - min),
			BreakUpLargeNumbers(max - min)
		)
	else
		row.value:SetText(standing)
		min, max, value = 0, 1, 1
	end
	local color = FACTION_BAR_COLORS[data.reaction] or FACTION_BAR_COLORS[#FACTION_BAR_COLORS]
	row.bar:SetStatusBarColor(color:GetRGB())
	SetBar(row, min, max, value, 0)
	return true
end

-- "Zone · Subzone" on the left, the coordinates on the right.
local function UpdateZone(row)
	local zone = GetZoneText()
	local subZone = Layout.SubZone(zone, GetSubZoneText())
	local text = strong .. zone .. "|r"
	if subZone then
		text = ("%s %s·|r %s%s|r"):format(text, faint, muted, subZone)
	end
	row.label:SetText(text)
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

-- The value grid: label above, value below, one function per cell.
local function GoldCell(cell)
	cell.label:SetText(L.gold)
	cell.value:SetText(Layout.MoneyText(GetMoney(), config.coinColors, config.coinSize))
end

local function BagsCell(cell)
	local free, total = 0, 0
	for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		local numFree, family = C_Container.GetContainerNumFreeSlots(bag)
		-- Quivers and other special bags only take their own item types.
		if family == 0 then
			free = free + numFree
			total = total + C_Container.GetContainerNumSlots(bag)
		end
	end
	cell.label:SetText(L.bags)
	cell.value:SetFormattedText("%d %s/ %d %s|r", free, muted, total, L.free)
end

local function DurabilityCell(cell)
	local lowest
	for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
		local current, max = GetInventoryItemDurability(slot)
		if current and max > 0 then
			lowest = math.min(lowest or 1, current / max)
		end
	end
	cell.label:SetText(L.durability)
	if not lowest then
		cell.value:SetText("–")
		cell.value:SetTextColor(unpack(style.palette.textStrong))
		return
	end
	local level = Layout.DurabilityLevel(lowest, config.durabilityWarn, config.durabilityCritical)
	cell.value:SetFormattedText("%d %%", floor(lowest * 100))
	cell.value:SetTextColor(unpack(level == "value" and style.palette.textStrong or colors[level]))
end

local function TimeCell(cell)
	cell.label:SetText(L.time)
	cell.value:SetText(date("%H:%M"))
end

local function SystemCell(cell)
	local _, _, home, world = GetNetStats()
	cell.label:SetText(L.system)
	cell.value:SetFormattedText("%d fps %s· %d / %d ms|r", floor(GetFramerate() + 0.5), muted, home, world)
end

local function OnlineCell(cell)
	local _, bnetOnline = BNGetNumFriends()
	local friends = (C_FriendList.GetNumOnlineFriends() or 0) + (bnetOnline or 0)
	if IsInGuild() then
		local _, guildOnline = GetNumGuildMembers()
		cell.label:SetText(L.friendsGuild)
		cell.value:SetFormattedText("%d %s·|r %d", friends, faint, guildOnline or 0)
	else
		cell.label:SetText(L.friends)
		cell.value:SetText(friends)
	end
end

local GRID_CELLS = { GoldCell, BagsCell, DurabilityCell, TimeCell, SystemCell, OnlineCell }

local function UpdateGrid(row)
	local cells, height = Layout.GridCells(
		#GRID_CELLS,
		island:GetWidth() - 2 * config.padding,
		config.gridColumns,
		config.gridRowHeight,
		config.gridRowGap
	)
	for index, update in ipairs(GRID_CELLS) do
		local cell, place = row.cells[index], cells[index]
		cell:SetPoint("TOPLEFT", row, "TOPLEFT", place.x, -place.y)
		cell:SetWidth(place.width - 6)
		update(cell)
	end
	row:SetHeight(height)
	return true
end

local function UpdateButtons(row)
	local height = Buttons.Layout(island:GetWidth() - 2 * config.padding, config.buttonSize, config.buttonGap)
	if height == 0 then
		return false
	end
	row:SetHeight(height)
	return true
end

local function UpdateSeparator()
	return true
end

-- The line above the buttons only shows with them.
local function UpdateButtonsSeparator()
	return Buttons.HasShown()
end

-- Built when the island is created, so saved overrides are applied already.
local function RowSpecs()
	local rowSpecs = {
		{ update = UpdateXP, bar = true, gradient = true },
		{ update = UpdateRested },
		{ update = UpdateReputation, bar = true },
		{ update = UpdateZone },
		{ update = UpdateSeparator, separator = true, groupStart = true },
		{ update = UpdateGrid, grid = true, groupStart = true },
		{ update = UpdateButtonsSeparator, separator = true, groupStart = true },
	}
	-- Always there for stevio-ui's own buttons (notes); other addons' buttons
	-- only join with minimapButtons. Without any buttons the row stays hidden.
	rowSpecs[#rowSpecs + 1] = { update = UpdateButtons, buttons = true, groupStart = true }
	return rowSpecs
end

local function CreateGridCells(row)
	row.cells = {}
	for index = 1, #GRID_CELLS do
		local cell = CreateFrame("Frame", nil, row)
		cell:SetHeight(config.gridRowHeight)
		cell.label = ns.CreateFontString(cell, style.fontSize - 1.5)
		cell.label:SetPoint("TOPLEFT")
		cell.label:SetPoint("RIGHT")
		cell.label:SetTextColor(unpack(style.palette.textFaint))
		cell.value = ns.CreateFontString(cell)
		cell.value:SetPoint("BOTTOMLEFT")
		cell.value:SetPoint("RIGHT")
		cell.value:SetTextColor(unpack(style.palette.textStrong))
		row.cells[index] = cell
	end
end

local function CreateRow(spec)
	local palette = style.palette
	local row = CreateFrame("Frame", nil, island)
	row.spec = spec
	if spec.buttons then
		Buttons.Setup(row, config.buttonSize)
		return row
	elseif spec.grid then
		CreateGridCells(row)
		return row
	elseif spec.separator then
		local line = row:CreateTexture(nil, "ARTWORK")
		line:SetAllPoints()
		line:SetColorTexture(unpack(config.separatorColor))
		row:SetHeight(ns.PixelSize(row))
		return row
	end

	-- The value sizes to its text; the label takes the rest and truncates.
	row.value = ns.CreateFontString(row, nil, "RIGHT")
	row.value:SetPoint("TOPRIGHT")
	row.value:SetTextColor(unpack(palette.textMuted))
	row.label = ns.CreateFontString(row)
	row.label:SetPoint("TOPLEFT")
	row.label:SetPoint("RIGHT", row.value, "LEFT", -8, 0)
	row.label:SetTextColor(unpack(palette.textMuted))

	local height = config.rowHeight
	if spec.bar then
		-- The overlay sits behind the bar and shows rested XP beyond the fill.
		row.overlay = ns.CreateStatusBar(row)
		row.overlay:SetPoint("BOTTOMLEFT")
		row.overlay:SetPoint("BOTTOMRIGHT")
		row.overlay:SetHeight(config.barHeight)
		row.overlay:SetStatusBarColor(colors.xpRested[1], colors.xpRested[2], colors.xpRested[3], config.restedAlpha)
		local background = row.overlay:CreateTexture(nil, "BACKGROUND")
		background:SetAllPoints()
		background:SetColorTexture(unpack(palette.track))

		row.bar = ns.CreateStatusBar(row)
		row.bar:SetAllPoints(row.overlay)
		row.bar:SetFrameLevel(row.overlay:GetFrameLevel() + 1)
		-- XP values are never secret, and the fill keeps its gradient as it
		-- shrinks and grows (SetStatusBarColor would replace it).
		if spec.gradient then
			row.bar
				:GetStatusBarTexture()
				:SetGradient("HORIZONTAL", CreateColor(unpack(palette.xpFrom)), CreateColor(unpack(palette.xpTo)))
		end

		height = height + config.barGap + config.barHeight
	end
	row:SetHeight(height)
	return row
end

-- Reused on every refresh: { shown, height, groupStart } per row.
local stack = {}

local function Refresh()
	for index, row in ipairs(rows) do
		local shown = row.spec.update(row)
		row:SetShown(shown)
		local entry = stack[index] or {}
		entry.shown, entry.height, entry.groupStart = shown, shown and row:GetHeight() or 0, row.spec.groupStart
		stack[index] = entry
	end
	-- Content starts below the notch, whose area is covered by the hardware.
	local tops, bottom = Layout.StackRows(stack, notchHeight + config.padding, config.rowGap, config.groupGap)
	for index, row in ipairs(rows) do
		local y = tops[index]
		if y then
			row:SetPoint("TOPLEFT", island, "TOPLEFT", config.padding, -y)
			row:SetPoint("TOPRIGHT", island, "TOPRIGHT", -config.padding, -y)
		end
	end
	island:SetHeight(bottom + config.padding)
end

-- Returns the notch in UIParent units: left and right edge, height, and how far
-- the real screen top lies above UIParent's top. UIParent may be shifted below
-- the notch depending on the notch display mode; anchoring against the screen
-- top works in every mode.
local function GetNotchRect()
	local physicalWidth, physicalHeight = GetPhysicalScreenSize()
	local _, leftEarRight, _, leftEarBottom = C_UI.GetTopLeftNotchSafeRegion()
	local rightEarLeft = C_UI.GetTopRightNotchSafeRegion()
	return Layout.NotchRect(
		UIParent:GetWidth(),
		UIParent:GetTop(),
		physicalWidth,
		physicalHeight,
		leftEarRight,
		leftEarBottom,
		rightEarLeft,
		config.fallback
	)
end

local function UpdateGeometry()
	local left, right, height, topOffset = GetNotchRect()
	notchHeight = height

	local originX, top = UIParent:GetLeft(), UIParent:GetTop() + topOffset
	notchRect = {
		left = originX + left,
		right = originX + right,
		bottom = top - height - config.hoverBelow,
	}

	island:ClearAllPoints()
	island:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left - config.extraWidth, topOffset)
	island:SetWidth(right - left + 2 * config.extraWidth)

	if island:IsShown() then
		Refresh()
	end
end

-- Black like the notch it grows out of, with round bottom corners: the
-- middle and a strip between the corners are plain, the corners a quarter
-- disc (Media/Corner.tga, round edge at its bottom left).
local function CreateBackground()
	local radius = config.cornerRadius
	local color = colors.background
	local function Plain()
		local texture = island:CreateTexture(nil, "BACKGROUND")
		texture:SetColorTexture(unpack(color))
		return texture
	end
	local body = Plain()
	body:SetPoint("TOPLEFT")
	body:SetPoint("BOTTOMRIGHT", 0, radius)
	local strip = Plain()
	strip:SetPoint("TOPLEFT", body, "BOTTOMLEFT", radius, 0)
	strip:SetPoint("BOTTOMRIGHT", -radius, 0)
	for _, side in ipairs({ "LEFT", "RIGHT" }) do
		local corner = island:CreateTexture(nil, "BACKGROUND")
		corner:SetTexture(CORNER_TEXTURE)
		corner:SetVertexColor(unpack(color))
		corner:SetSize(radius, radius)
		corner:SetPoint("BOTTOM" .. side)
		if side == "RIGHT" then
			corner:SetTexCoord(1, 0, 0, 1)
		end
	end
end

local function CreateIsland()
	-- No mouse on the island itself, so clicks and camera drags pass through.
	island = CreateFrame("Frame", "StevioUI_NotchIsland", UIParent)
	island:SetFrameStrata("FULLSCREEN_DIALOG")
	island:Hide()
	-- No shadow: its straight strips leave a light rim and gaps at the round
	-- corners (#77); the island is as plain as the notch itself.
	CreateBackground()

	local palette = style.palette
	strong, normal = ns.Hex(palette.textStrong), ns.Hex(palette.text)
	muted, faint = ns.Hex(palette.textMuted), ns.Hex(palette.textFaint)

	for _, spec in ipairs(RowSpecs()) do
		rows[#rows + 1] = CreateRow(spec)
	end

	-- While hidden the island does no work beyond the cheap cursor check below;
	-- while shown it polls, which
	-- also covers values without change events (FPS, latency, time, position).
	island:SetScript("OnShow", function(self)
		self.elapsed = 0
		if IsInGuild() then
			C_GuildInfo.GuildRoster()
		end
		if config.minimapButtons then
			Buttons.Scan(config.buttonSize)
		end
		Refresh()
	end)
	island:SetScript("OnUpdate", function(self, elapsed)
		self.elapsed = self.elapsed + elapsed
		if self.elapsed >= config.updateInterval then
			self.elapsed = 0
			Refresh()
		end
	end)

	-- The cursor position is polled instead of relying on OnEnter/OnLeave: those
	-- only fire when mouse focus changes, so the island never came up when the
	-- cursor was already in the notch (after turning the camera, a loading
	-- screen or a UI rescale) or when another frame held the mouse focus.
	local state = Zone.New()
	local islandRect = {}
	local input, options = {}, { hideDelay = config.hideDelay, margin = config.islandMargin }
	local sinceCheck = 0
	local watcher = CreateFrame("Frame", "StevioUI_NotchWatcher", UIParent)
	watcher:SetScript("OnUpdate", function(_, elapsed)
		sinceCheck = sinceCheck + elapsed
		if sinceCheck < config.pollInterval then
			return
		end
		local x, y = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		input.x, input.y = x / scale, y / scale
		input.cursorHidden = IsMouselooking()
		input.notch = notchRect
		input.island = nil
		if island:IsShown() then
			islandRect.left, islandRect.right, islandRect.bottom =
				island:GetLeft(), island:GetRight(), island:GetBottom()
			input.island = islandRect
		end
		island:SetShown(Zone.Step(state, input, sinceCheck, options))
		sinceCheck = 0
	end)
end

-- Dumps the notch geometry for checking the placement outside the game.
local function DumpGeometry()
	local physicalWidth, physicalHeight = GetPhysicalScreenSize()
	local left, right, height, topOffset, real = GetNotchRect()
	local lines = {
		("physical: %d x %d"):format(physicalWidth, physicalHeight),
		"left ear: " .. strjoin(", ", tostringall(C_UI.GetTopLeftNotchSafeRegion())),
		"right ear: " .. strjoin(", ", tostringall(C_UI.GetTopRightNotchSafeRegion())),
		("avoid notch: %s, NotchedDisplayMode: %s"):format(
			tostring(C_UI.ShouldUIParentAvoidNotch()),
			tostring(C_CVar.GetCVar("NotchedDisplayMode"))
		),
		("UIParent: %.1f x %.1f, top %.1f, effective scale %.3f"):format(
			UIParent:GetWidth(),
			UIParent:GetHeight(),
			UIParent:GetTop(),
			UIParent:GetEffectiveScale()
		),
		("notch: left %.1f, right %.1f, height %.1f, top offset %.1f, real %s"):format(
			left,
			right,
			height,
			topOffset,
			tostring(real)
		),
		("trigger: left %.1f, right %.1f, bottom %.1f"):format(notchRect.left, notchRect.right, notchRect.bottom),
		("cursor: %.1f, %.1f"):format(GetCursorPosition()),
	}
	ns.ShowDebugDump(table.concat(lines, "\n"))
end

-- Where things hanging below the notch go (the roll cards): the horizontal
-- center and the bottom edge of the notch, or of the island while it is open,
-- in UIParent units. Nil before the module is set up (or when it is off).
function ns.NotchBottom()
	if not notchRect then
		return nil
	end
	local center = (notchRect.left + notchRect.right) / 2
	if island:IsShown() and island:GetBottom() then
		return center, island:GetBottom()
	end
	return center, notchRect.bottom + config.hoverBelow
end

function Notch:OnEnable()
	CreateIsland()
	UpdateGeometry()

	-- Blizzard shifts UIParent below the notch only later (entering the world,
	-- notch mode or display changes); the offset to the screen top must follow.
	hooksecurefunc("UpdateUIParentPosition", UpdateGeometry)
	ns.RegisterEvent("UI_SCALE_CHANGED", function()
		C_Timer.After(0, UpdateGeometry)
	end)

	-- Adopting the buttons early keeps them from showing on the map until the
	-- island first opens; buttons created later are picked up when it opens.
	if config.minimapButtons then
		ns.RegisterEvent("PLAYER_ENTERING_WORLD", function()
			C_Timer.After(config.buttonScanDelay, function()
				Buttons.Scan(config.buttonSize)
			end)
		end)
		Buttons.Scan(config.buttonSize)
	end
end

ns.RegisterModuleCommand("notch", "notch", DumpGeometry)
