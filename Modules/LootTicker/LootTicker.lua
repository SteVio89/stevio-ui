local _, ns = ...

local LootTicker = ns:RegisterModule("lootTicker", {})

-- Own loot, gold and currency gains as a short list above the bags: icon, name in
-- quality color and count. Lines enter at the bottom, move up as new ones
-- arrive and fade out after a while. Click-through, so it never blocks the world.

local Feed = ns.LootFeed

local config, feed, container, patterns, moneyPatterns
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

-- Icon and quality (nil if not known yet) of an item or currency link.
local function LinkInfo(link)
	if link:find("|Hcurrency:", 1, true) then
		local info = C_CurrencyInfo.GetCurrencyInfoFromLink(link)
		return info and info.iconFile, info and info.quality, true
	end
	local _, _, _, _, icon = C_Item.GetItemInfoInstant(link)
	return icon, C_Item.GetItemQualityByID(link), false
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
	if entry.money then
		-- The count is copper; the string shows it with coin icons.
		row.text:SetText(GetMoneyString(entry.count, true))
		row.text:SetTextColor(1, 1, 1)
		return
	end
	local name = Feed.LinkName(entry.link)
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
			row:SetAlpha(Feed.Alpha(now - entry.time, config))
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

local function Add(link, count)
	local icon, quality, isCurrency = LinkInfo(link)
	if isCurrency and not config.showCurrency then
		return
	end
	if quality and not isCurrency and quality < config.minQuality then
		return
	end
	AddEntry({
		link = link,
		count = count,
		icon = icon,
		color = { QualityColor(quality, link) },
	})
end

-- All money shares one line ("money" is never a real link), so it merges.
local function AddMoney(copper)
	AddEntry({ link = "money", count = copper, icon = 133784, money = true }) -- coin icon
end

local function OnLoot(_, text)
	-- Message contents can be secret (e.g. in encounters) and can't be read then.
	if issecretvalue(text) then
		return
	end
	local link, count = Feed.Parse(text, patterns)
	if link then
		Add(link, count)
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
