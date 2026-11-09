local _, ns = ...

local QuestRewards = ns.RegisterModule("questRewards", {})

local config = ns.config.questRewards
local Choices = ns.QuestChoices
local coins = {}
local pendingLoad

local function GetCoin(button)
	local coin = coins[button]
	if not coin then
		coin = button:CreateTexture(nil, "OVERLAY", nil, 4)
		coin:SetAtlas("coin-gold")
		coin:SetSize(config.coinSize, config.coinSize)
		coin:SetPoint("TOPRIGHT", button.Icon, "TOPRIGHT", 2, 2)
		coins[button] = coin
	end
	return coin
end

local function GetChoiceButtons()
	local rewardsFrame = Choices.RewardsFrame()
	return Choices.Buttons(rewardsFrame.RewardButtons or {}, true)
end

-- `items` holds { count, itemID } per button, read from the quest before the
-- items were loaded.
local function MarkMostValuable(buttons, items)
	local values = {}
	for index, item in ipairs(items) do
		local sellPrice = item.itemID and select(11, C_Item.GetItemInfo(item.itemID))
		values[index] = (sellPrice or 0) * (item.count or 1)
	end
	local best = Choices.MostValuable(values)
	if best then
		GetCoin(buttons[best]):Show()
	end
end

-- Reward buttons are shared with the quest log, so coins are cleared on every
-- display and only set again on the turn-in page.
local function Update(template)
	if pendingLoad then
		pendingLoad:Cancel()
		pendingLoad = nil
	end
	for _, coin in pairs(coins) do
		coin:Hide()
	end
	if template ~= QUEST_TEMPLATE_REWARD then
		return
	end
	local buttons = GetChoiceButtons()
	if #buttons < 2 then
		return
	end

	-- Sell prices are only known once the items are cached.
	local container = ContinuableContainer:Create()
	local items = {}
	for index, button in ipairs(buttons) do
		local _, _, count, _, _, itemID = GetQuestItemInfo("choice", button:GetID())
		items[index] = { count = count, itemID = itemID }
		if itemID then
			container:AddContinuable(Item:CreateFromItemID(itemID))
		end
	end
	pendingLoad = container
	container:ContinueOnLoad(function()
		pendingLoad = nil
		MarkMostValuable(buttons, items)
	end)
end

function QuestRewards:OnEnable()
	hooksecurefunc("QuestInfo_Display", Update)
end
