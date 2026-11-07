local _, ns = ...

local LootTicker = ns:RegisterModule("lootTicker", {})

-- Own loot, gold and currency gains as a short list above the bags: icon, name in
-- quality color and count. Lines enter at the bottom, move up as new ones
-- arrive and fade out after a while. Click-through, so it never blocks the world.
-- The group's loot ("Name: item") and loot roll messages are listed too, those
-- about other players dimmed.

local Feed = ns.LootFeed

local config, feed, container, patterns, moneyPatterns, groupPatterns, rollPatterns
local rows = {}
local rowHeight

local function QualityColor(quality, link)
	if quality and C_Item.GetItemQualityColor then
		local r, g, b = C_Item.GetItemQualityColor(quality)
		if r then
			return r, g, b
		end
	end
	local hex = Feed.LinkColor(link)
	if hex then
		return tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, tonumber(hex:sub(7, 8), 16) / 255
	end
	return 1, 1, 1
end

-- Item qualities by link color ({ [quality] = "ffrrggbb" }), for items not cached yet.
local function QualityHex()
	local hex = {}
	for quality, color in pairs(ITEM_QUALITY_COLORS) do
		hex[quality] = color.hex and color.hex:match("|c(%x%x%x%x%x%x%x%x)")
	end
	return hex
end

-- Icon and quality of an item or currency link; an uncached item's quality
-- comes from its link color (nil if that is unknown too).
local function LinkInfo(link)
	if link:find("|Hcurrency:", 1, true) then
		local info = C_CurrencyInfo.GetCurrencyInfoFromLink(link)
		return info and info.iconFile, info and info.quality, true
	end
	local _, _, _, _, icon = C_Item.GetItemInfoInstant(link)
	local quality = C_Item.GetItemQualityByID(link) or Feed.QualityFromColor(Feed.LinkColor(link), QualityHex())
	return icon, quality, false
end

-- The class of a group member, from the message's GUID or else by name.
local function PlayerClass(name, guid)
	if guid and not issecretvalue(guid) and guid ~= "" then
		local _, class = GetPlayerInfoByGUID(guid)
		if class then
			return class
		end
	end
	local prefix = IsInRaid() and "raid" or "party"
	for i = 1, GetNumGroupMembers() do
		local unit = prefix .. i
		local unitName = UnitName(unit)
		if unitName and not issecretvalue(unitName) and unitName == name then
			return select(2, UnitClass(unit))
		end
	end
end

local function ClassColored(name, class)
	local color = class and C_ClassColor.GetClassColor(class)
	return color and color:WrapTextInColorCode(name) or name
end

local function CreateRow()
	local row = CreateFrame("Frame", nil, container)
	row:SetSize(config.width, config.iconSize)
	row:EnableMouse(false)

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(config.iconSize, config.iconSize)
	row.icon:SetPoint("LEFT")
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	row.text = ns.CreateFontString(row, config.fontSize, "LEFT")
	row.text:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
	row.text:SetPoint("RIGHT")
	return row
end

local function ShowEntry(row, entry)
	row.entry = entry
	row.icon:SetTexture(entry.icon or 134400) -- question mark
	if entry.roll then
		-- Blizzard's own wording; the item link inside keeps its quality color.
		row.text:SetText(entry.text)
		row.text:SetTextColor(1, 1, 1)
		return
	end
	if entry.money then
		-- The count is copper; the string shows it with coin icons.
		row.text:SetText(GetMoneyString(entry.count, true))
		row.text:SetTextColor(1, 1, 1)
		return
	end
	local name = Feed.LinkName(entry.link)
	if entry.looter then
		-- The item keeps its quality color inside the line; the name has its class color.
		name = ("%s: |c%s%s|r"):format(ClassColored(entry.looter, entry.class), entry.hex, name)
	end
	if entry.count > 1 then
		row.text:SetFormattedText("%s |cffffffffx%d|r", name, entry.count)
	else
		row.text:SetText(name)
	end
	row.text:SetTextColor(unpack(entry.color))
end

-- Called on every frame while something is listed.
local function OnUpdate(_, elapsed)
	local now = GetTime()
	local count = feed:Expire(now, config)
	for i, row in ipairs(rows) do
		local entry = feed.entries[i]
		if entry then
			if row.entry ~= entry then
				ShowEntry(row, entry)
			end
			local target = (i - 1) * rowHeight
			entry.y = Feed.Slide(entry.y or target, target, elapsed, rowHeight, config.slideTime)
			row:SetPoint("BOTTOMLEFT", 0, entry.y)
			row:SetAlpha(Feed.Alpha(now - entry.time, config) * (entry.other and config.groupAlpha or 1))
			row:Show()
		else
			row.entry = nil
			row:Hide()
		end
	end
	if count == 0 then
		container:Hide()
	end
end

local function AddEntry(entry)
	feed:Add(entry, GetTime(), config.mergeRepeats)
	-- A merged entry keeps its table but changes its count.
	for _, row in ipairs(rows) do
		row.entry = nil
	end
	container:Show()
end

-- Own loot, or another group member's (`looter`, with the message's `guid`).
local function Add(link, count, looter, guid)
	local icon, quality, isCurrency = LinkInfo(link)
	if isCurrency and not config.showCurrency then
		return
	end
	local minQuality = looter and config.groupMinQuality or config.minQuality
	if quality and not isCurrency and quality < minQuality then
		return
	end
	local r, g, b = QualityColor(quality, link)
	AddEntry({
		link = link,
		-- The same item looted by the same player adds up.
		key = (looter or "") .. link,
		count = count,
		icon = icon,
		color = { r, g, b },
		looter = looter,
		other = looter ~= nil,
		class = looter and PlayerClass(looter, guid),
		hex = CreateColor(r, g, b):GenerateHexColor(),
	})
end

-- All money shares one line ("money" is never a real link), so it merges.
local function AddMoney(copper)
	AddEntry({ link = "money", key = "money", count = copper, icon = 133784, money = true }) -- coin icon
end

-- A roll message about another player is dimmed like their loot.
local function AddRoll(text, link, roller)
	local icon = LinkInfo(link)
	local other = roller ~= nil and roller ~= UnitName("player")
	AddEntry({ link = link, text = text, roll = true, count = 1, icon = icon, other = other })
end

-- The GUID of the message's player is the 12th event argument.
local function OnLoot(_, text, _, ...)
	-- Message contents can be secret (e.g. in encounters) and can't be read then.
	if issecretvalue(text) then
		return
	end
	local link, count = Feed.Parse(text, patterns)
	if link then
		Add(link, count)
		return
	end
	if config.showRolls then
		local rollLink, roller = Feed.ParseRoll(text, rollPatterns)
		if rollLink then
			AddRoll(text, rollLink, roller)
			return
		end
	end
	if config.showGroupLoot then
		local looter
		link, count, looter = Feed.Parse(text, groupPatterns)
		if link and looter then
			Add(link, count, looter, select(10, ...))
		end
	end
end

local function OnMoney(_, text)
	if issecretvalue(text) or not config.showMoney then
		return
	end
	local copper = Feed.ParseMoney(text, moneyPatterns)
	if copper then
		AddMoney(copper)
	end
end

-- /sui loot: lists a few items from the bags to check the look.
local function Preview()
	local added = 0
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.hyperlink and added < 5 then
				Add(info.hyperlink, info.stackCount or 1)
				added = added + 1
			end
		end
	end
	if config.showMoney then
		AddMoney(12345)
	end
end

function LootTicker:OnEnable(moduleConfig)
	config = moduleConfig
	rowHeight = config.iconSize + config.rowGap
	feed = Feed.New(config.maxRows)

	-- Only the player's own loot; formats with a count come first.
	patterns = Feed.Patterns(
		LOOT_ITEM_SELF_MULTIPLE,
		LOOT_ITEM_SELF,
		LOOT_ITEM_PUSHED_SELF_MULTIPLE,
		LOOT_ITEM_PUSHED_SELF,
		LOOT_ITEM_CREATED_SELF_MULTIPLE,
		LOOT_ITEM_CREATED_SELF,
		LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE,
		LOOT_ITEM_BONUS_ROLL_SELF,
		LOOT_ITEM_REFUND_MULTIPLE,
		LOOT_ITEM_REFUND,
		CURRENCY_GAINED_MULTIPLE_BONUS,
		CURRENCY_GAINED_MULTIPLE,
		CURRENCY_GAINED
	)

	-- Roll messages about yourself come first, since "%s won: %s" would also
	-- match "You won: %s"; a variant with more text before its plain one.
	-- Strings this client lacks are skipped.
	rollPatterns = Feed.Patterns(
		LOOT_ROLL_YOU_WON_NO_SPAM_NEED,
		LOOT_ROLL_YOU_WON_NO_SPAM_GREED,
		LOOT_ROLL_YOU_WON_NO_SPAM_DE,
		LOOT_ROLL_YOU_WON,
		LOOT_ROLL_NEED_SELF,
		LOOT_ROLL_GREED_SELF,
		LOOT_ROLL_DISENCHANT_SELF,
		LOOT_ROLL_TRANSMOG_SELF,
		LOOT_ROLL_PASSED_SELF_AUTO,
		LOOT_ROLL_PASSED_SELF,
		LOOT_ROLL_ALL_PASSED,
		LOOT_ROLL_WON_NO_SPAM_NEED,
		LOOT_ROLL_WON_NO_SPAM_GREED,
		LOOT_ROLL_WON_NO_SPAM_DE,
		LOOT_ROLL_WON,
		LOOT_ROLL_ROLLED_NEED_ROLE_BONUS,
		LOOT_ROLL_ROLLED_NEED,
		LOOT_ROLL_ROLLED_GREED,
		LOOT_ROLL_ROLLED_DE,
		LOOT_ROLL_ROLLED_TRANSMOG,
		LOOT_ROLL_NEED,
		LOOT_ROLL_GREED,
		LOOT_ROLL_DISENCHANT,
		LOOT_ROLL_TRANSMOG,
		LOOT_ROLL_PASSED_AUTO_FEMALE,
		LOOT_ROLL_PASSED_AUTO,
		LOOT_ROLL_PASSED
	)

	-- Other group members' loot; formats with a count come first.
	groupPatterns = Feed.Patterns(
		LOOT_ITEM_MULTIPLE,
		LOOT_ITEM,
		LOOT_ITEM_PUSHED_MULTIPLE,
		LOOT_ITEM_PUSHED,
		LOOT_ITEM_BONUS_ROLL_MULTIPLE,
		LOOT_ITEM_BONUS_ROLL
	)

	moneyPatterns = Feed.MoneyPatterns(GOLD_AMOUNT, SILVER_AMOUNT, COPPER_AMOUNT)

	container = CreateFrame("Frame", nil, UIParent)
	container:SetFrameStrata("LOW")
	container:SetSize(config.width, config.maxRows * rowHeight - config.rowGap)
	container:EnableMouse(false)
	ns.SetPoint(container, ns.layout.lootTicker)
	container:Hide()
	container:SetScript("OnUpdate", OnUpdate)

	for i = 1, config.maxRows do
		rows[i] = CreateRow()
		rows[i]:Hide()
	end

	ns:RegisterEvent("CHAT_MSG_LOOT", OnLoot)
	ns:RegisterEvent("CHAT_MSG_CURRENCY", OnLoot)
	ns:RegisterEvent("CHAT_MSG_MONEY", OnMoney)
	ns:RegisterSlashCommand("loot", Preview)
end
