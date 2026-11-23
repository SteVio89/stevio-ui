local _, ns = ...

-- The roll cards below the notch. A card opens for every group loot roll the
-- player is offered: icon, name, a timer bar and Need · Greed (or Transmog)
-- · Pass. Once answered it shrinks to the result: the winner and the best
-- rolls (plus the player's), filled in from the loot history as they come.
-- Cards of answered rolls fade out a while after the winner is known.

local Cards = {}
ns.RollCards = Cards

local Logic = ns.RollLogic
local State = Logic.State
local RollType = Logic.RollType
local config = ns.config.rolls
local style = ns.config.style
local T = ns.T

Cards.L = {
	you = T("you", "du"),
	rolling = T("rolling…", "würfelt…"),
	allPassed = T("All passed", "Alle gepasst"),
	youWin = T("You win", "Du gewinnst"),
	wins = T("%s wins", "%s gewinnt"),
}

Cards.stateLabels = {
	[State.NeedMainSpec] = NEED or "Need",
	[State.NeedOffSpec] = (NEED or "Need") .. " (OS)",
	[State.Transmog] = TRANSMOGRIFICATION or "Transmog",
	[State.Greed] = GREED or "Greed",
	[State.Pass] = PASS or "Pass",
}

-- Neutral color of the stripe and timer while the quality can't be read.
local UNKNOWN_QUALITY = { 0.6, 0.6, 0.6 }

local cards = {}
local holder
local pool = {}
local holderTop

-- Values of GetLootRollItemInfo may be secret during the chat lockdown: those
-- must not even be tested ("x and y"), only handed to widgets.
local function Known(value)
	return not issecretvalue(value) and value
end

function Cards.ClassColored(name, class)
	local color = Known(class) and C_ClassColor.GetClassColor(class)
	return color and color:WrapTextInColorCode(name) or name
end

local function QualityColor(quality)
	if Known(quality) and C_Item.GetItemQualityColor then
		local r, g, b = C_Item.GetItemQualityColor(quality)
		if r then
			return { r, g, b }
		end
	end
	return UNKNOWN_QUALITY
end

-- Moves `current` towards `target` at `speed` units per second.
local function Slide(current, target, elapsed, speed)
	local step = speed * elapsed
	if math.abs(target - current) <= step then
		return target
	end
	return current + (target > current and step or -step)
end

local function Remove(card)
	for i, other in ipairs(cards) do
		if other == card then
			table.remove(cards, i)
			break
		end
	end
	if card.frame then
		card.frame:Hide()
		card.frame.card = nil
		pool[#pool + 1] = card.frame
		card.frame = nil
	end
end

-- Buttons ----------------------------------------------------------------------

local function OnRollEnter(button)
	if button.reason then
		GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
		GameTooltip:SetText(button.reason, 1, 1, 1, 1, true)
		GameTooltip:Show()
	end
end

local function OnRollClick(button)
	local card = button:GetParent().card
	if not card or card.choice then
		return
	end
	if not card.preview then
		RollOnLoot(card.rollID, button.rollType)
	end
	card.choice = button.rollType
	Cards.Layout()
end

local function CreateRollButton(frame)
	local button = CreateFrame("Button", nil, frame)
	button:SetHeight(18)
	button.label = ns.CreateFontString(button, config.fontSize, "CENTER")
	button.label:SetAllPoints()
	button:SetHighlightTexture(style.texture)
	button:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.1)
	-- Disabled buttons still show why on hover.
	button:SetMotionScriptsWhileDisabled(true)
	button:SetScript("OnClick", OnRollClick)
	button:SetScript("OnEnter", OnRollEnter)
	button:SetScript("OnLeave", GameTooltip_Hide)
	return button
end

-- `enabled` may be secret (in the chat lockdown); then the button stays
-- usable and the game refuses a roll it doesn't allow.
local function SetRollButton(button, text, rollType, enabled, reason)
	button.label:SetText(text)
	button.rollType = rollType
	local usable = issecretvalue(enabled) or enabled
	button:SetEnabled(usable and true or false)
	button.label:SetTextColor(usable and 1 or 0.4, usable and 1 or 0.4, usable and 1 or 0.4)
	button.reason = nil
	if not usable and Known(reason) then
		button.reason = _G["LOOT_ROLL_INELIGIBLE_REASON" .. reason]
	end
end

-- Card frames --------------------------------------------------------------------

local function OnCardEnter(frame)
	local card = frame.card
	if card then
		card.hovered = true
		if card.link then
			GameTooltip:SetOwner(frame, "ANCHOR_BOTTOM")
			GameTooltip:SetHyperlink(card.link)
			GameTooltip:Show()
		end
	end
end

local function OnCardLeave(frame)
	if frame.card then
		frame.card.hovered = false
	end
	GameTooltip:Hide()
end

local function OnCardClick(frame)
	local card = frame.card
	if card and card.link then
		HandleModifiedItemClick(card.link)
	end
end

local function CreateCardFrame()
	local frame = CreateFrame("Button", nil, holder)
	frame:SetWidth(config.width)
	frame:RegisterForClicks("LeftButtonUp")
	frame:SetScript("OnEnter", OnCardEnter)
	frame:SetScript("OnLeave", OnCardLeave)
	frame:SetScript("OnClick", OnCardClick)
	ns.CreatePanel(frame)

	frame.stripe = frame:CreateTexture(nil, "ARTWORK")
	frame.stripe:SetTexture(style.texture)
	frame.stripe:SetPoint("TOPLEFT")
	frame.stripe:SetPoint("BOTTOMLEFT")
	frame.stripe:SetWidth(config.stripeWidth)

	local padding = config.padding
	local left = config.stripeWidth + padding
	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	frame.icon:SetSize(config.iconSize, config.iconSize)
	frame.icon:SetPoint("TOPLEFT", left, -padding)
	ns.CropIcon(frame.icon)

	frame.close = CreateFrame("Button", nil, frame)
	frame.close:SetSize(config.iconSize, config.iconSize)
	frame.close:SetPoint("TOPRIGHT", -padding + 4, -padding)
	frame.close.label = ns.CreateFontString(frame.close, config.fontSize, "CENTER")
	frame.close.label:SetAllPoints()
	frame.close.label:SetText("✕")
	frame.close.label:SetTextColor(0.7, 0.7, 0.7)
	frame.close:SetHighlightTexture(style.texture)
	frame.close:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.1)
	frame.close:SetScript("OnClick", function(self)
		local card = self:GetParent().card
		if card then
			Remove(card)
			Cards.Layout()
		end
	end)

	frame.name = ns.CreateFontString(frame, config.fontSize)
	frame.name:SetPoint("LEFT", frame.icon, "RIGHT", 6, 0)
	frame.name:SetPoint("RIGHT", frame.close, "LEFT", -4, 0)

	-- Open roll: timer bar with the seconds left, then the three buttons.
	frame.timer = ns.CreateStatusBar(frame)
	frame.timer:SetHeight(config.timerHeight)
	-- Widths are set, not anchored to the right edge: a second anchor would
	-- also pull at the height.
	local inner = config.width - left - padding
	frame.timer:SetPoint("TOPLEFT", frame.icon, "BOTTOMLEFT", 0, -6)
	frame.timer:SetWidth(inner - 36)
	ns.CreateBackground(frame.timer, { 1, 1, 1, 0.08 })
	frame.seconds = ns.CreateFontString(frame, config.fontSize - 2, "RIGHT")
	frame.seconds:SetPoint("LEFT", frame.timer, "RIGHT", 4, 0)
	frame.seconds:SetWidth(32)
	frame.seconds:SetTextColor(0.7, 0.7, 0.7)

	frame.buttons = {}
	local buttonWidth = inner / 3
	for i = 1, 3 do
		local button = CreateRollButton(frame)
		button:SetWidth(buttonWidth)
		button:SetPoint("TOPLEFT", frame.timer, "BOTTOMLEFT", (i - 1) * buttonWidth, -4)
		frame.buttons[i] = button
	end

	-- Answered roll: the result, then the rolls (wrapping onto a second line).
	frame.result = ns.CreateFontString(frame, config.fontSize)
	frame.result:SetPoint("TOPLEFT", frame.icon, "BOTTOMLEFT", 0, -4)
	frame.result:SetWidth(inner)
	frame.rolls = ns.CreateFontString(frame, config.fontSize - 2)
	frame.rolls:SetPoint("TOPLEFT", frame.result, "BOTTOMLEFT", 0, -2)
	frame.rolls:SetWidth(inner)
	frame.rolls:SetWordWrap(true)
	frame.rolls:SetMaxLines(2)
	return frame
end

local function AcquireFrame()
	local frame = table.remove(pool) or CreateCardFrame()
	frame:SetAlpha(1)
	return frame
end

local function ShowOpen(frame, card)
	frame.timer:Show()
	frame.seconds:Show()
	frame.result:Hide()
	frame.rolls:Hide()
	frame.close:Hide()
	local greedType, greedText, canGreed, greedReason =
		RollType.Greed, Cards.stateLabels[State.Greed], card.canGreed, card.reasonGreed
	-- Like Blizzard's frame: Transmog takes Greed's place when the item allows it.
	if Known(card.canTransmog) then
		greedType, greedText, canGreed, greedReason = RollType.Transmog, Cards.stateLabels[State.Transmog], true, nil
	end
	SetRollButton(frame.buttons[1], Cards.stateLabels[State.NeedMainSpec], RollType.Need, card.canNeed, card.reasonNeed)
	SetRollButton(frame.buttons[2], greedText, greedType, canGreed, greedReason)
	SetRollButton(frame.buttons[3], Cards.stateLabels[State.Pass], RollType.Pass, true)
	for _, button in ipairs(frame.buttons) do
		button:Show()
	end
	local padding = config.padding
	frame:SetHeight(padding + config.iconSize + 6 + config.timerHeight + 4 + 18 + padding)
end

local function ShowAnswered(frame, card)
	frame.timer:Hide()
	frame.seconds:Hide()
	for _, button in ipairs(frame.buttons) do
		button:Hide()
	end
	frame.close:Show()
	frame.result:Show()
	frame.rolls:Show()
	local summary = card.summary
	local L, labels = Cards.L, Cards.stateLabels
	frame.result:SetText(Logic.ResultText(summary, L, Cards.ClassColored))
	local rolls
	if summary then
		rolls = Logic.TopRolls(summary, config.topRolls)
	else
		rolls = { { isSelf = true, state = Logic.StateOfRollType(card.choice) } }
	end
	frame.rolls:SetText(Logic.RollsLine(rolls, L, labels, Cards.ClassColored))
	local padding = config.padding
	local textHeight = frame.result:GetStringHeight() + 2 + frame.rolls:GetStringHeight()
	frame:SetHeight(padding + config.iconSize + 4 + textHeight + padding)
end

local function Render(card)
	local frame = card.frame
	frame.card = card
	if issecretvalue(card.icon) or card.icon then
		frame.icon:SetTexture(card.icon)
	else
		frame.icon:SetTexture(134400) -- question mark
	end
	frame.name:SetText(card.name)
	if Known(card.name) and Known(card.count) and card.count > 1 then
		frame.name:SetText(("%s |cffffffffx%d|r"):format(card.name, card.count))
	end
	local color = QualityColor(card.quality)
	frame.name:SetTextColor(unpack(color == UNKNOWN_QUALITY and { 1, 1, 1 } or color))
	frame.stripe:SetVertexColor(unpack(color))
	frame.timer:SetStatusBarColor(unpack(color))
	frame.timer:SetMinMaxValues(0, card.duration)
	if card.choice then
		ShowAnswered(frame, card)
	else
		ShowOpen(frame, card)
	end
end

-- Stack ----------------------------------------------------------------------------

-- Re-sorts and re-renders the cards; positions glide in OnUpdate.
-- Cards waiting for an answer in Blizzard's popup (replaceBlizzardRolls
-- off) stay hidden until then.
function Cards.Layout()
	Logic.SortCards(cards)
	local shown = 0
	for _, card in ipairs(cards) do
		if card.choice or not card.answerElsewhere then
			card.frame = card.frame or AcquireFrame()
			Render(card)
			card.frame:Show()
			shown = shown + 1
		end
	end
	holder:SetShown(shown > 0)
end

-- The top of the stack, from the UIParent's top edge: below the notch (or
-- its open island), or near the screen top without the notch module.
local function StackTop()
	local _, bottom = (ns.NotchBottom or function() end)()
	if not bottom then
		return -10
	end
	return bottom - UIParent:GetTop() - config.notchGap
end

local function PassedOn(card)
	if card.summary and card.summary.mine then
		return card.summary.mine.state == State.Pass
	end
	return card.choice == RollType.Pass
end

local function OnUpdate(_, elapsed)
	local now = GetTime()
	local speed = (config.iconSize * 3) / config.slideTime
	holderTop = Slide(holderTop or StackTop(), StackTop(), elapsed, speed * 2)
	holder:ClearAllPoints()
	holder:SetPoint("TOP", UIParent, "TOP", 0, holderTop)

	local changed = false
	for i = #cards, 1, -1 do
		local card = cards[i]
		if card.hovered and card.fadeAt and card.fadeAt < now then
			card.fadeAt = now
		end
		-- The game ends every roll with CANCEL_LOOT_ROLL; should that ever not
		-- come (or for the preview), a roll whose time ran out counts as passed.
		if not card.choice and now > card.started + card.duration + 5 then
			card.choice = RollType.Pass
			changed = true
		end
		-- A roll answered but never decided (no loot history entry, left the
		-- group) goes once its timer ran out long enough ago.
		if card.choice and not card.fadeAt and Logic.TimeLeft(card, now) == 0 then
			card.fadeAt = card.started + card.duration + config.resultTimeout
		end
		if not Logic.CardAlpha(card, now, config) then
			Remove(card)
			changed = true
		end
	end
	if changed then
		Cards.Layout()
	end

	local y = 0
	for _, card in ipairs(cards) do
		local frame = card.frame
		if frame and frame:IsShown() then
			card.y = Slide(card.y or y, y, elapsed, speed)
			frame:ClearAllPoints()
			frame:SetPoint("TOP", holder, "TOP", 0, -card.y)
			local alpha = Logic.CardAlpha(card, now, config)
			frame:SetAlpha(alpha * (PassedOn(card) and config.passedAlpha or 1))
			if not card.choice then
				local left = Logic.TimeLeft(card, now)
				frame.timer:SetValue(left)
				frame.seconds:SetText(("%ds"):format(math.ceil(left)))
			end
			y = y + frame:GetHeight() + config.cardGap
		end
	end
	if not holder:IsShown() then
		holderTop = nil
	end
end

function Cards.Setup()
	holder = CreateFrame("Frame", "StevioUI_RollCards", UIParent)
	holder:SetSize(config.width, 1)
	holder:SetFrameStrata("HIGH")
	holder:Hide()
	holder:SetScript("OnUpdate", OnUpdate)
end

-- Data ------------------------------------------------------------------------------

function Cards.Find(rollID)
	for _, card in ipairs(cards) do
		if card.rollID == rollID then
			return card
		end
	end
end

function Cards.All()
	return cards
end

-- A roll the player is offered (START_LOOT_ROLL, or one still open after a
-- reload): `duration` and `timeLeft` in seconds. With `answerElsewhere` the
-- card waits hidden until the player answered in Blizzard's popup.
function Cards.Open(rollID, duration, timeLeft, answerElsewhere)
	if Cards.Find(rollID) then
		return
	end
	local texture, name, count, quality, bindOnPickUp, canNeed, canGreed, _, reasonNeed, reasonGreed, _, _, canTransmog =
		GetLootRollItemInfo(rollID)
	-- Like Blizzard's frame: no name, no roll (it is already gone).
	if not issecretvalue(name) and name == nil then
		return
	end
	local link = GetLootRollItemLink(rollID)
	local card = {
		rollID = rollID,
		link = not issecretvalue(link) and link or nil,
		icon = texture,
		name = name,
		count = count,
		quality = quality,
		bindOnPickUp = bindOnPickUp,
		canNeed = canNeed,
		canGreed = canGreed,
		canTransmog = canTransmog,
		reasonNeed = reasonNeed,
		reasonGreed = reasonGreed,
		duration = duration,
		started = GetTime() - (duration - (timeLeft or duration)),
		answerElsewhere = answerElsewhere,
	}
	cards[#cards + 1] = card
	Cards.Layout()
	return card
end

-- The roll ended for the player (CANCEL_LOOT_ROLL): unanswered it was passed
-- by the game.
function Cards.Ended(rollID)
	local card = Cards.Find(rollID)
	if card and not card.choice then
		card.choice = RollType.Pass
		Cards.Layout()
	end
end

-- A loot history drop changed: the card it belongs to (found by its item
-- the first time) shows the new state; decided, it starts to fade.
function Cards.UpdateDrop(dropKey, summary)
	local card
	for _, other in ipairs(cards) do
		if other.dropKey == dropKey then
			card = other
			break
		end
	end
	card = card or Logic.MatchCard(cards, summary.link)
	if not card then
		return
	end
	card.dropKey = dropKey
	card.summary = summary
	-- Answered elsewhere (Blizzard's popup, with replaceBlizzardRolls off).
	if summary.mine and not card.choice then
		card.choice = Logic.RollTypeOfState(summary.mine.state)
	end
	if not summary.pending and not card.fadeAt then
		card.fadeAt = GetTime() + config.holdAfterWinner
	end
	Cards.Layout()
end

-- Two made-up cards (one open, one won by "Bob") to check the look.
function Cards.Preview(link)
	local now = GetTime()
	local name, _, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(link)
	local base = { link = link, name = name or link, quality = quality, icon = icon, preview = true }
	local open = setmetatable({
		rollID = -1,
		canNeed = false,
		reasonNeed = 1,
		canGreed = true,
		duration = 60,
		started = now,
	}, { __index = base })
	local won = setmetatable({
		rollID = -2,
		choice = RollType.Greed,
		duration = 60,
		started = now - 30,
		fadeAt = now + config.holdAfterWinner,
		summary = Logic.Summary({
			itemHyperlink = link,
			winner = { playerName = "Bob", playerClass = "MAGE", state = State.NeedMainSpec, roll = 98 },
			rollInfos = {
				{ playerName = "Bob", playerClass = "MAGE", state = State.NeedMainSpec, roll = 98 },
				{ playerName = "Ann", playerClass = "PRIEST", state = State.Greed, roll = 71 },
				{ playerName = UnitName("player"), isSelf = true, state = State.Greed, roll = 45 },
				{ playerName = "Tom", playerClass = "WARRIOR", state = State.Pass },
			},
		}),
	}, { __index = base })
	for _, card in ipairs({ open, won }) do
		local old = Cards.Find(card.rollID)
		if old then
			Remove(old)
		end
		cards[#cards + 1] = card
	end
	Cards.Layout()
end
