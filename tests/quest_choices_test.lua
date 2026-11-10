-- Run with: lua tests/quest_choices_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")
local ns = loadAddonFile("Modules/QuestRewards/Choices.lua")
local Choices = ns.QuestChoices

-- Strictly greater wins, so ties go to the first; nothing above zero, no pick.
check(Choices.MostValuable({ 5, 9, 3 }) == 2, "highest value")
check(Choices.MostValuable({ 7, 7, 2 }) == 1, "tie goes to the first")
check(Choices.MostValuable({ 0, 0 }) == nil, "all zero")
check(Choices.MostValuable({}) == nil, "no choices")

local function button(shown, type, objectType)
	return {
		type = type,
		objectType = objectType,
		IsShown = function()
			return shown
		end,
	}
end
local item = button(true, "choice", "item")
local currency = button(true, "choice", "currency")
local hidden = button(false, "choice", "item")
local reward = button(true, "reward", "item")
local all = { reward, item, hidden, currency }

local buttons = Choices.Buttons(all, false)
check(#buttons == 2 and buttons[1] == item and buttons[2] == currency, "shown choices in order")
buttons = Choices.Buttons(all, true)
check(#buttons == 1 and buttons[1] == item, "items only")

print("quest choices tests passed")
