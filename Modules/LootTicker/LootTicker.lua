local _, ns = ...

local LootTicker = ns.RegisterModule("lootTicker", {})

-- Own loot, gold and currency gains as a short list above the bags: icon, name in
-- quality color and count. Lines enter at the bottom, move up as new ones
-- arrive and fade out after a while. Click-through, so it never blocks the world.
-- Only the player's own loot: other players' loot and group loot rolls are
-- left to the roll cards (Modules/Rolls).
-- Loot messages that arrive secret during the chat lockdown (boss encounters)
-- are read once it is over, so nothing looted in a fight goes missing.

local Feed = ns.LootFeed

local config = ns.config.lootTicker
local feed, holder, container, patterns, moneyPatterns
local rows = {}
local rowHeight
-- Secret loot messages waiting for the end of the chat lockdown.
local pending = {}

local function QualityColor(quality, link)
	if quality and C_Item.GetItemQualityColor then
		local r, g, b = C_Item.GetItemQualityColor(quality)
		if r then
			return r, g, b
		end
	end
	local hex = Feed.LinkColor(link)
	if hex then
		return Feed.HexToRGB(hex)
	end
	return 1, 1, 1
end

-- Item qualities by link color ({ [quality] = "ffrrggbb" }), for items not
-- cached yet. Built on every call, since the player can change quality colors
-- in Blizzard's accessibility settings.
local function QualityHex()
	local qualityHex = {}
	for quality, color in pairs(ITEM_QUALITY_COLORS) do
		qualityHex[quality] = color.hex and color.hex:match("|c(%x%x%x%x%x%x%x%x)")
	end
	return qualityHex
end

-- Icon and quality of an item or currency link; an uncached item's quality
-- comes from its link color (nil if that is unknown too).
local function LinkInfo(link)
	if link:find("|Hcurrency:", 1, true) then
		local icon, quality = Feed.CurrencyDisplay(C_CurrencyInfo.GetCurrencyInfoFromLink(link))
		return icon, quality, true
	end
	local _, _, _, _, icon = C_Item.GetItemInfoInstant(link)
	local quality = C_Item.GetItemQualityByID(link) or Feed.QualityFromColor(Feed.LinkColor(link), QualityHex())
	return icon, quality, false
end

local function CreateRow()
	local row = CreateFrame("Frame", nil, container)
	row:SetSize(config.width, config.iconSize)
	row:EnableMouse(false)

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(config.iconSize, config.iconSize)
	row.icon:SetPoint("LEFT")
	ns.CropIcon(row.icon)

	-- The details size to their text; the item name takes the space left.
	row.detail = ns.CreateFontString(row, config.fontSize, "RIGHT")
	row.detail:SetPoint("RIGHT")
	row.detail:SetTextColor(1, 1, 1)
	row.text = ns.CreateFontString(row, config.fontSize, "LEFT")
	row.text:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
	row.text:SetPoint("RIGHT", row.detail, "LEFT", -6, 0)
	return row
end

local function ShowEntry(row, entry)
	row.entry = entry
	row.icon:SetTexture(entry.icon or 134400) -- question mark
	local detail = ""
	if entry.money then
		-- The count is copper; the string shows it with coin icons.
		row.text:SetText(GetMoneyString(entry.count, true))
		row.text:SetTextColor(1, 1, 1)
	else
		row.text:SetText(Feed.LinkName(entry.link))
		row.text:SetTextColor(unpack(entry.color))
		detail = Feed.LootDetail(entry)
	end
	row.detail:SetText(detail)
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
			row:SetAlpha(Feed.EntryAlpha(entry, now, config))
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
	if not Feed.Passes(quality, isCurrency, config) then
		return
	end
	AddEntry({
		link = link,
		-- The same item looted again adds up.
		key = link,
		count = count,
		icon = icon,
		color = { QualityColor(quality, link) },
	})
end

-- All money shares one line ("money" is never a real link), so it merges.
local function AddMoney(copper)
	AddEntry({ link = "money", key = "money", count = copper, icon = 133784, money = true }) -- coin icon
end

local function ReadLoot(text)
	local link, count = Feed.Parse(text, patterns)
	if link then
		Add(link, count)
	end
end

local function ReadMoney(text)
	if not config.showMoney then
		return
	end
	local copper = Feed.ParseMoney(text, moneyPatterns)
	if copper then
		AddMoney(copper)
	end
end

local readers = { CHAT_MSG_LOOT = ReadLoot, CHAT_MSG_CURRENCY = ReadLoot, CHAT_MSG_MONEY = ReadMoney }

-- Message contents can be secret during the chat lockdown (e.g. in boss
-- encounters): those are kept by their chat line id (the 11th event
-- argument) and read once it is over.
local function OnMessage(event, text, _, ...)
	if not issecretvalue(text) then
		readers[event](text)
		return
	end
	local lineID = select(9, ...)
	if C_ChatInfo.GetChatLineText and not issecretvalue(lineID) and type(lineID) == "number" and lineID > 0 then
		pending[#pending + 1] = { event = event, lineID = lineID }
	end
end

local function ReadPending()
	if #pending == 0 or C_ChatInfo.InChatMessagingLockdown() then
		return
	end
	local lines = pending
	pending = {}
	Feed.ReadPending(lines, C_ChatInfo.GetChatLineText, function(event, text)
		readers[event](text)
	end, issecretvalue)
end

-- A frame later: the lockdown may only be lifted once the event is through.
local function ReadSoon()
	if #pending > 0 then
		C_Timer.After(0, ReadPending)
	end
end

-- /sui loot: lists a few items from the bags and some gold to check the look.
local function Preview()
	local shown = 0
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.hyperlink and shown < 5 then
				shown = shown + 1
				Add(info.hyperlink, info.stackCount or 1)
			end
		end
	end
	if config.showMoney then
		AddMoney(12345)
	end
end

-- Hides the ticker while the roll history takes its place (Modules/Rolls);
-- lines keep fading meanwhile.
function ns.SetLootTickerShown(shown)
	if holder then
		holder:SetShown(shown)
	end
end

function LootTicker:OnEnable()
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

	holder = CreateFrame("Frame", nil, UIParent)
	holder:SetAllPoints()
	container = CreateFrame("Frame", nil, holder)
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

	for event in pairs(readers) do
		ns.RegisterEvent(event, OnMessage)
	end
	ns.RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED", ReadSoon)
	ns.RegisterEvent("PLAYER_REGEN_ENABLED", ReadSoon)
end

ns.RegisterModuleCommand("loot", "lootTicker", Preview)
