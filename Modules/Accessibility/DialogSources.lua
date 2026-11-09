local _, ns = ...

-- Each source tells QuickJump whether its window is open and which buttons
-- are selectable right now, in the order they should be labelled.

local QuickJump = ns.QuickJump
local Internal = ns.AccessibilityInternal

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

-- Calls fn with every popup frame that exists, until fn returns true;
-- returns whether one did.
local function ForEachPopup(fn)
	for i = 1, POPUP_COUNT do
		local dialog = _G["StaticPopup" .. i]
		if dialog and fn(dialog) then
			return true
		end
	end
	return false
end

local function IsShown(frame)
	return frame:IsShown()
end

local function AnyPopupShown()
	return ForEachPopup(IsShown)
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
		ForEachPopup(function(dialog)
			if dialog:IsShown() then
				local buttons = dialog.ButtonContainer
				tAppendAll(
					targets,
					Shown(buttons.Button1, buttons.Button2, buttons.Button3, buttons.Button4, dialog.ExtraButton)
				)
			end
		end)
		return QuickJump.SortByPosition(targets)
	end,
	OnFinished = function()
		popupRequested = false
	end,
}

-- Returns whether popups took the leader press.
function Internal.RequestPopupLabels()
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
			-- QuestInfo picks the rewards frame per display, so read it from there.
			local rewardsFrame = ns.QuestChoices.RewardsFrame()
			local targets = ns.QuestChoices.Buttons(rewardsFrame and rewardsFrame.RewardButtons or {}, false)
			QuickJump.SortByPosition(targets)
			targets[#targets + 1] = QuestFrameCompleteQuestButton
			return targets
		end
		return {}
	end,
	GetScrollBar = function()
		for _, scrollFrame in ipairs({
			QuestGreetingScrollFrame,
			QuestDetailScrollFrame,
			QuestProgressScrollFrame,
			QuestRewardScrollFrame,
		}) do
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

function Internal.IsDialogOpen()
	return questSource.IsOpen() or gossipSource.IsOpen() or Internal.IsTaxiListOpen()
end

function Internal.SetupDialogSources()
	QuickJump:RegisterSource(popupSource)
	QuickJump:RegisterSource(questSource)
	QuickJump:RegisterSource(gossipSource)

	ForEachPopup(function(dialog)
		dialog:HookScript("OnHide", RequestRefresh)
	end)

	QuestFrame:HookScript("OnHide", RequestRefresh)
	for _, panel in ipairs({
		QuestFrameGreetingPanel,
		QuestFrameDetailPanel,
		QuestFrameProgressPanel,
		QuestFrameRewardPanel,
	}) do
		panel:HookScript("OnShow", RequestRefresh)
	end
	-- A reward picked by label has no mouse over it, so its tooltip is shown as
	-- if hovered, and the labels come back to compare the next one.
	hooksecurefunc("QuestInfoItem_OnClick", function(button)
		if button.type == "choice" and QuestFrameRewardPanel:IsShown() then
			button:OnEnter()
			RequestRefresh()
		end
	end)

	GossipFrame:HookScript("OnHide", RequestRefresh)
	hooksecurefunc(GossipFrame, "Update", RequestRefresh)
end
