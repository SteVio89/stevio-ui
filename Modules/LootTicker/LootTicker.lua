local _, ns = ...

local LootTicker = ns.RegisterModule("lootTicker", {})

-- Own loot, gold and currency gains as a short list above the bags: icon, name in
-- quality color and count. Lines enter at the bottom, move up as new ones
-- arrive and fade out after a while. Click-through, so it never blocks the world.
-- The group's loot ("item  Name") is listed too, dimmed and shorter. A group
-- loot roll is one line per drop, read from the loot history and updated in
-- place: rolling (with your own choice), then the winner and their roll. The
-- winner's "receives loot" message adds no second line.
-- Each line has the item name on the left and the details (count, player,
-- roll) on the right; only the item name is shortened when space runs out.

local Feed = ns.LootFeed
local State = Feed.RollState

-- An open roll stays fully visible this long at most (the game's roll timer
-- is shorter), in case its result never arrives (e.g. after leaving the group).
local ROLL_TIMEOUT = 150
-- A loot line this many seconds older than the roll result is still taken
-- back into the roll's line.
local LOOT_BEFORE_RESULT = 10
local GREY = "|cffaaaaaa%s|r"

local L = ns.isGerman and {
	rolling = "würfelt",
	allPassed = "alle gepasst",
	you = "Du",
	yourRoll = "du",
} or {
	rolling = "rolling",
	allPassed = "all passed",
	you = "You",
	yourRoll = "you",
}

local stateLabels = {
	[State.NeedMainSpec] = NEED or "Need",
	[State.NeedOffSpec] = (NEED or "Need") .. " (OS)",
	[State.Transmog] = "Transmog",
	[State.Greed] = GREED or "Greed",
	[State.Pass] = PASS or "Pass",
}

local config = ns.config.lootTicker
local feed, container, patterns, moneyPatterns, groupPatterns
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

-- "Need 87", or just "Need" before the numbers are rolled.
local function RollText(roll)
	local text = stateLabels[roll.state] or ""
	if roll.roll then
		text = text .. " " .. roll.roll
	end
	return text
end

-- The right part of a roll line: "rolling · you: Need", "Bob Need 98 · you:
-- Greed 45", "You Need 87" or "all passed".
local function RollDetail(summary)
	if summary.allPassed then
		return GREY:format(L.allPassed)
	end
	local winner, mine = summary.winner, summary.mine
	if winner and winner.isSelf then
		return ("|cff40ff40%s|r %s"):format(L.you, GREY:format(RollText(winner)))
	end
	local text
	if winner then
		text = ClassColored(winner.name, winner.class) .. " " .. GREY:format(RollText(winner))
	else
		text = GREY:format(L.rolling)
	end
	if mine then
		text = text .. GREY:format((" · %s: %s"):format(L.yourRoll, RollText(mine)))
	end
	return text
end

local function CreateRow()
	local row = CreateFrame("Frame", nil, container)
	row:SetSize(config.width, config.iconSize)
	row:EnableMouse(false)

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(config.iconSize, config.iconSize)
	row.icon:SetPoint("LEFT")
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	-- The details size to their text; the item name takes the space left.
	row.detail = ns.CreateFontString(row, config.fontSize, "RIGHT")
	row.detail:SetPoint("RIGHT")
	row.text = ns.CreateFontString(row, config.fontSize, "LEFT")
	row.text:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
	row.text:SetPoint("RIGHT", row.detail, "LEFT", -6, 0)
	return row
end

-- Count and looter of a loot line: "x3 Bob".
local function LootDetail(entry)
	local parts = {}
	if entry.count > 1 then
		parts[#parts + 1] = ("|cffffffffx%d|r"):format(entry.count)
	end
	if entry.looter then
		parts[#parts + 1] = ClassColored(Feed.ShortName(entry.looter), entry.class)
	end
	return table.concat(parts, " ")
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
		detail = entry.roll and entry.detail or LootDetail(entry)
	end
	-- Very long details (a long name and both rolls) are capped too, so the
	-- item name always keeps some room.
	row.detail:SetWidth(0)
	row.detail:SetText(detail)
	row.detail:SetTextColor(1, 1, 1)
	local maxDetail = config.width * 0.6
	if row.detail:GetStringWidth() > maxDetail then
		row.detail:SetWidth(maxDetail)
	end
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
			row:SetAlpha(Feed.EntryAlpha(entry, now, config) * (entry.other and config.groupAlpha or 1))
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
-- Loot won in a listed roll only marks that roll's line as received.
local function Add(link, count, looter, guid)
	local roll = feed:RollFor(link, looter)
	if roll then
		roll.received = true
		return
	end
	local icon, quality, isCurrency = LinkInfo(link)
	if isCurrency and not config.showCurrency then
		return
	end
	local minQuality = looter and config.groupMinQuality or config.minQuality
	if quality and not isCurrency and quality < minQuality then
		return
	end
	AddEntry({
		link = link,
		-- The same item looted by the same player adds up.
		key = (looter or "") .. link,
		count = count,
		icon = icon,
		color = { QualityColor(quality, link) },
		looter = looter,
		other = looter ~= nil,
		class = looter and PlayerClass(looter, guid),
	})
end

-- All money shares one line ("money" is never a real link), so it merges.
local function AddMoney(copper)
	AddEntry({ link = "money", key = "money", count = copper, icon = 133784, money = true }) -- coin icon
end

-- One line per loot history drop (`key`), replaced on every update. Rolls
-- the player passed on or didn't join are dimmed like other players' loot.
local function AddDrop(key, drop)
	local summary = Feed.RollSummary(drop)
	local detail = RollDetail(summary)
	local old = feed:Find(key)
	if old and old.detail == detail then
		return -- nothing new, e.g. the loot history window was opened
	end
	local link = drop.itemHyperlink
	local icon, quality = LinkInfo(link)
	local winner, mine = summary.winner, summary.mine
	local now = GetTime()
	local entry = {
		link = link,
		key = key,
		replace = true,
		roll = true,
		count = 1,
		icon = icon,
		color = { QualityColor(quality, link) },
		detail = detail,
		winner = winner,
		received = old and old.received,
		other = not (winner and winner.isSelf) and not (mine and mine.state ~= State.Pass),
		pendingUntil = summary.pending and now + ROLL_TIMEOUT or nil,
	}
	AddEntry(entry)
	-- The winner's loot message may have come first.
	if winner and not entry.received then
		local looter = not winner.isSelf and winner.name or nil
		entry.received = feed:TakeLoot(link, looter, now, LOOT_BEFORE_RESULT)
	end
end

-- Whether any text of a drop is secret (can't be read, e.g. in encounters).
local function HasSecrets(drop)
	if issecretvalue(drop.itemHyperlink) then
		return true
	end
	if drop.winner and issecretvalue(drop.winner.playerName) then
		return true
	end
	for _, info in ipairs(drop.rollInfos or {}) do
		if issecretvalue(info.playerName) then
			return true
		end
	end
	return false
end

local function OnDrop(_, encounterID, lootListID)
	if not config.showRolls or issecretvalue(encounterID) or issecretvalue(lootListID) then
		return
	end
	local drop = C_LootHistory.GetSortedInfoForDrop(encounterID, lootListID)
	if drop and drop.itemHyperlink and not HasSecrets(drop) then
		AddDrop(("drop:%s:%s"):format(encounterID, lootListID), drop)
	end
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

-- /sui loot: lists a few items from the bags, gold and two made-up rolls
-- (one open, one won by "Bob") to check the look.
local function Preview()
	local links = {}
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.hyperlink and #links < 5 then
				links[#links + 1] = info.hyperlink
				Add(info.hyperlink, info.stackCount or 1)
			end
		end
	end
	if config.showMoney then
		AddMoney(12345)
	end
	if config.showRolls and links[1] then
		local me = { playerName = UnitName("player"), playerClass = select(2, UnitClass("player")), isSelf = true }
		local bob = { playerName = "Bob", playerClass = "MAGE", isSelf = false }
		AddDrop("preview:open", {
			itemHyperlink = links[1],
			playerRollState = State.NeedMainSpec,
			rollInfos = {
				{ playerName = me.playerName, playerClass = me.playerClass, isSelf = true, state = State.NeedMainSpec },
			},
		})
		AddDrop("preview:won", {
			itemHyperlink = links[2] or links[1],
			playerRollState = State.Greed,
			winner = {
				playerName = bob.playerName,
				playerClass = bob.playerClass,
				state = State.NeedMainSpec,
				roll = 98,
			},
			rollInfos = {
				{
					playerName = me.playerName,
					playerClass = me.playerClass,
					isSelf = true,
					state = State.Greed,
					roll = 45,
				},
			},
		})
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

	ns.RegisterEvent("CHAT_MSG_LOOT", OnLoot)
	ns.RegisterEvent("CHAT_MSG_CURRENCY", OnLoot)
	ns.RegisterEvent("CHAT_MSG_MONEY", OnMoney)
	ns.RegisterEvent("LOOT_HISTORY_UPDATE_DROP", OnDrop)
	ns.RegisterSlashCommand("loot", Preview)
end
