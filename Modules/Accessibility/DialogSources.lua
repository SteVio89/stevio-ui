local _, ns = ...

-- Each source tells QuickJump whether its window is open and which buttons
-- are selectable right now, in the order they should be labelled.

local QuickJump = ns.QuickJump

local function RequestRefresh()
	QuickJump:RequestRefresh()
end

local function Shown(...)
	local frames = {}
	for i = 1, select("#", ...) do
		local frame = select(i, ...)
		if frame and frame:IsShown() then
			frames[#frames + 1] = frame
		end
	end
	return frames
end

-- Popups appear unexpectedly, so they only get labels after the leader key;
-- otherwise their letters would block movement while a popup is up.
local popupRequested = false
local POPUP_COUNT = 4

local function AnyPopupShown()
	for i = 1, POPUP_COUNT do
		local dialog = _G["StaticPopup" .. i]
		if dialog and dialog:IsShown() then
			return true
		end
	end
	return false
end

local popupSource = {
	name = "popup",
	priority = 30,
	IsOpen = function()
		if not AnyPopupShown() then
			popupRequested = false
		end
		return popupRequested
	end,
	Collect = function()
		local targets = {}
		for i = 1, POPUP_COUNT do
			local dialog = _G["StaticPopup" .. i]
			if dialog and dialog:IsShown() then
				local buttons = dialog.ButtonContainer
				tAppendAll(targets, Shown(buttons.Button1, buttons.Button2, buttons.Button3, buttons.Button4, dialog.ExtraButton))
			end
		end
		return QuickJump.SortByPosition(targets)
	end,
	OnFinished = function()
		popupRequested = false
	end,
}

-- Returns whether popups took the leader press.
function ns.RequestPopupLabels()
	if AnyPopupShown() and not popupRequested then
		popupRequested = true
		RequestRefresh()
		return true
	end
	return false
end

local questSource = {
	name = "quest",
	priority = 20,
	IsOpen = function()
		return QuestFrame:IsShown()
	end,
	Collect = function()
		if QuestFrameGreetingPanel:IsShown() then
			local titles = {}
			for button in QuestFrameGreetingPanel.titleButtonPool:EnumerateActive() do
				titles[#titles + 1] = button
			end
			QuickJump.SortByPosition(titles)
			titles[#titles + 1] = QuestFrameGreetingGoodbyeButton
			return titles
		elseif QuestFrameDetailPanel:IsShown() then
			return { QuestFrameAcceptButton, QuestFrameDeclineButton }
		elseif QuestFrameProgressPanel:IsShown() then
			return { QuestFrameCompleteButton, QuestFrameGoodbyeButton }
		elseif QuestFrameRewardPanel:IsShown() then
			local targets = {}
			-- QuestInfo picks the rewards frame per display, so read it from there.
			local rewardsFrame = QuestInfoFrame.rewardsFrame or QuestInfoRewardsFrame
			for _, button in ipairs(rewardsFrame and rewardsFrame.RewardButtons or {}) do
				if button:IsShown() and button.type == "choice" then
					targets[#targets + 1] = button
				end
			end
			QuickJump.SortByPosition(targets)
			targets[#targets + 1] = QuestFrameCompleteQuestButton
			return targets
		end
		return {}
	end,
	GetScrollBar = function()
		for _, scrollFrame in ipairs({ QuestGreetingScrollFrame, QuestDetailScrollFrame, QuestProgressScrollFrame, QuestRewardScrollFrame }) do
			if scrollFrame:IsVisible() then
				return scrollFrame.ScrollBar
			end
		end
	end,
}

local gossipSource = {
	name = "gossip",
	priority = 10,
	IsOpen = function()
		return GossipFrame:IsShown()
	end,
	Collect = function()
		local targets = {}
		-- Greeting text and spacers share the list with the options but aren't buttons.
		GossipFrame.GreetingPanel.ScrollBox:ForEachFrame(function(frame)
			if frame:IsObjectType("Button") and frame:IsShown() then
				targets[#targets + 1] = frame
			end
		end)
		QuickJump.SortByPosition(targets)
		targets[#targets + 1] = GossipFrame.GreetingPanel.GoodbyeButton
		return targets
	end,
	GetScrollBar = function()
		return GossipFrame.GreetingPanel.ScrollBar
	end,
}

function ns.IsDialogOpen()
	return questSource.IsOpen() or gossipSource.IsOpen() or ns.IsTaxiListOpen()
end

function ns.SetupDialogSources()
	QuickJump:RegisterSource(popupSource)
	QuickJump:RegisterSource(questSource)
	QuickJump:RegisterSource(gossipSource)

	for i = 1, POPUP_COUNT do
		local dialog = _G["StaticPopup" .. i]
		if dialog then
			dialog:HookScript("OnHide", RequestRefresh)
		end
	end

	QuestFrame:HookScript("OnHide", RequestRefresh)
	for _, panel in ipairs({ QuestFrameGreetingPanel, QuestFrameDetailPanel, QuestFrameProgressPanel, QuestFrameRewardPanel }) do
		panel:HookScript("OnShow", RequestRefresh)
	end

	GossipFrame:HookScript("OnHide", RequestRefresh)
	hooksecurefunc(GossipFrame, "Update", RequestRefresh)
end
