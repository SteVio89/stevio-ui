local _, ns = ...

local QuestRewards = ns:RegisterModule("questRewards", {})

local config
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
	local buttons = {}
	local rewardsFrame = QuestInfoFrame.rewardsFrame or QuestInfoRewardsFrame
	for _, button in ipairs(rewardsFrame.RewardButtons or {}) do
		if button:IsShown() and button.type == "choice" and button.objectType == "item" then
			buttons[#buttons + 1] = button
		end
	end
	return buttons
end

local function MarkMostValuable(buttons)
	local best, bestValue = nil, 0
	for _, button in ipairs(buttons) do
		local _, _, count, _, _, itemID = GetQuestItemInfo("choice", button:GetID())
		local sellPrice = itemID and select(11, C_Item.GetItemInfo(itemID))
		local value = (sellPrice or 0) * (count or 1)
		if value > bestValue then
			best, bestValue = button, value
		end
	end
	if best then
		GetCoin(best):Show()
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
	for _, button in ipairs(buttons) do
		local itemID = select(6, GetQuestItemInfo("choice", button:GetID()))
		if itemID then
			container:AddContinuable(Item:CreateFromItemID(itemID))
		end
	end
	pendingLoad = container
	container:ContinueOnLoad(function()
		pendingLoad = nil
		MarkMostValuable(buttons)
	end)
end

function QuestRewards:OnEnable(moduleConfig)
	config = moduleConfig
	hooksecurefunc("QuestInfo_Display", Update)
end
