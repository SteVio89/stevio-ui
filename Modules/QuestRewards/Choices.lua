local _, ns = ...

-- Quest choice rewards, shared with the quick-jump quest source. The pure
-- parts take plain values so they can be tested outside the game.
local Choices = {}
ns.QuestChoices = Choices

-- The rewards frame QuestInfo picked for the current display (may be nil).
function Choices.RewardsFrame()
	return QuestInfoFrame.rewardsFrame or QuestInfoRewardsFrame
end

-- The shown choice buttons among `rewardButtons`, in their order; with
-- `itemsOnly`, only those offering an item.
function Choices.Buttons(rewardButtons, itemsOnly)
	local buttons = {}
	for _, button in ipairs(rewardButtons) do
		if button:IsShown() and button.type == "choice" and (not itemsOnly or button.objectType == "item") then
			buttons[#buttons + 1] = button
		end
	end
	return buttons
end

-- Index of the highest value; ties go to the first, and nil when no value is
-- above zero.
function Choices.MostValuable(values)
	local best, bestValue = nil, 0
	for index, value in ipairs(values) do
		if value > bestValue then
			best, bestValue = index, value
		end
	end
	return best
end
