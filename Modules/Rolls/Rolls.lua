local _, ns = ...

local Rolls = ns.RegisterModule("rolls", {})

-- Group loot rolls: a card below the notch for every roll the player is
-- offered (Cards.lua), in place of Blizzard's popup, and a history of every
-- decided roll (History.lua), opened from the notch island and saved per
-- character. Results come from the loot history (C_LootHistory); drops whose
-- names are secret during the chat lockdown are read again once it is over.

local Logic = ns.RollLogic
local Cards = ns.RollCards
local History = ns.RollHistory
local config = ns.config.rolls
local T = ns.T

-- Drops ({ encounterID, lootListKey }) that couldn't be read yet.
local pending = {}
-- The instance each encounter of this session was fought in, taken when its
-- first drop shows up (the player may have left when the roll ends).
local instances = {}

local function Saved()
	StevioUIRollHistory = StevioUIRollHistory or {}
	StevioUIRollHistory.records = StevioUIRollHistory.records or {}
	return StevioUIRollHistory.records
end

-- Whether any text of a drop is secret (can't be read, e.g. in encounters).
local function HasSecrets(drop)
	if issecretvalue(drop.itemHyperlink) or issecretvalue(drop.allPassed) then
		return true
	end
	local winner = drop.winner
	if winner and (issecretvalue(winner.playerName) or issecretvalue(winner.roll) or issecretvalue(winner.isSelf)) then
		return true
	end
	for _, info in ipairs(drop.rollInfos or {}) do
		if
			issecretvalue(info.playerName)
			or issecretvalue(info.state)
			or issecretvalue(info.roll)
			or issecretvalue(info.isSelf)
		then
			return true
		end
	end
	return false
end

-- The fight a drop belongs to: its name, instance and when it started (as
-- seconds since the epoch; the loot history counts from the session start).
-- Without encounter info all drops of the encounter share the time the
-- first of them was recorded, so they stay under one header.
local fightTimes = {}

local function Fight(encounterID)
	local info = C_LootHistory.GetInfoForEncounter(encounterID)
	local now = time()
	fightTimes[encounterID] = fightTimes[encounterID] or now
	local fight =
		{ encounterID = encounterID, name = "", instance = instances[encounterID], time = fightTimes[encounterID] }
	if info and not issecretvalue(info.encounterName) and not issecretvalue(info.startTime) then
		fight.name = info.encounterName
		fight.time = math.floor(now - (C_LootHistory.GetLootHistoryTime() - info.startTime) + 0.5)
	end
	return fight
end

local function ReadDrop(encounterID, lootListKey)
	local drop = C_LootHistory.GetSortedInfoForDrop(encounterID, lootListKey)
	if not drop then
		return
	end
	-- Secret values can't even be tested, so this comes first.
	if HasSecrets(drop) then
		pending[#pending + 1] = { encounterID = encounterID, lootListKey = lootListKey }
		return
	end
	if not drop.itemHyperlink then
		return
	end
	if not instances[encounterID] then
		local instance = GetInstanceInfo()
		instances[encounterID] = not issecretvalue(instance) and instance or nil
	end
	local summary = Logic.Summary(drop)
	Cards.UpdateDrop(("%s:%s"):format(encounterID, lootListKey), summary)
	if not summary.pending then
		local record = Logic.Record(summary, Fight(encounterID), lootListKey, time())
		local saved = Saved()
		-- The loot history repeats drops after a reload: only new ones go to
		-- the player database (Modules/Players).
		local isNew = not Logic.FindRecord(saved, record.encounterID, record.lootListKey, record.fightTime)
		Logic.SaveRecord(saved, record)
		History.Refresh()
		if isNew and ns.PlayersRecordLoot then
			ns.PlayersRecordLoot(record)
		end
	end
end

local function OnDrop(_, encounterID, lootListKey)
	if issecretvalue(encounterID) or issecretvalue(lootListKey) then
		return
	end
	ReadDrop(encounterID, lootListKey)
end

local function ReadPending()
	if #pending == 0 then
		return
	end
	local drops = pending
	pending = {}
	for _, drop in ipairs(drops) do
		ReadDrop(drop.encounterID, drop.lootListKey)
	end
end

-- A frame later: the lockdown may only be lifted once the event is through.
local function ReadSoon()
	if #pending > 0 then
		C_Timer.After(0, ReadPending)
	end
end

local function OnStartRoll(_, rollID, rollTime)
	if issecretvalue(rollID) or issecretvalue(rollTime) then
		return
	end
	Cards.Open(rollID, rollTime / 1000, nil, not config.replaceBlizzardRolls)
end

local function OnCancelRoll(_, rollID)
	if not issecretvalue(rollID) then
		Cards.Ended(rollID)
	end
end

-- E.g. after leaving the group: every open roll is over.
local function OnCancelAll()
	-- A copy: ending a roll re-sorts the cards.
	for _, card in ipairs(CopyTable(Cards.All(), true)) do
		if not card.preview then
			Cards.Ended(card.rollID)
		end
	end
end

-- Rolls still open after a /reload get their card again.
local function OpenActiveRolls()
	for _, rollID in ipairs(GetActiveLootRollIDs()) do
		local duration = C_Loot.GetLootRollDuration(rollID)
		local timeLeft = GetLootRollTimeLeft(rollID)
		if not issecretvalue(duration) and not issecretvalue(timeLeft) and duration and timeLeft then
			Cards.Open(rollID, duration / 1000, timeLeft / 1000, not config.replaceBlizzardRolls)
		end
	end
end

-- Blizzard opens its popup from its game event router; without that route
-- its roll frames never show, while the bind-on-pickup confirmation (its own
-- event) still comes from Blizzard.
local function SuppressBlizzard()
	if config.replaceBlizzardRolls then
		GameEvent.UnregisterInternalEvent("START_LOOT_ROLL")
	end
end

local function CreateNotchButton()
	if not ns.NotchButtons then
		return
	end
	-- Parked in a hidden frame until the notch island adopts it.
	local parking = CreateFrame("Frame")
	parking:Hide()
	local size = ns.config.notch.buttonSize
	local button = CreateFrame("Button", "StevioUI_RollsButton", parking)
	button:SetSize(size, size)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Up")
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	button:SetScript("OnClick", History.Toggle)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText(T("Loot rolls", "Beutewürfe"))
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	ns.NotchButtons.AddOwn(button, "StevioUI_RollHistory")
end

-- /sui rolls: two made-up cards with an item from the bags and the history
-- with made-up entries, to check the look.
local function Preview()
	local link
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.hyperlink and not link then
				link = info.hyperlink
			end
		end
	end
	if not link then
		ns.Print(
			T("Put an item in your bags for the preview", "Für die Vorschau einen Gegenstand in die Taschen legen")
		)
		return
	end
	Cards.Preview(link)

	local State = Logic.State
	local me = UnitName("player")
	local function Drop(winner, mine)
		return Logic.Summary({
			itemHyperlink = link,
			winner = winner,
			rollInfos = {
				{ playerName = "Bob", playerClass = "MAGE", state = State.NeedMainSpec, roll = 98 },
				{ playerName = "Ann", playerClass = "PRIEST", state = State.Greed, roll = 71 },
				{ playerName = me, isSelf = true, state = mine, roll = mine ~= State.Pass and 87 or nil },
				{ playerName = "Tom", playerClass = "WARRIOR", state = State.Pass },
			},
		})
	end
	local bob = { playerName = "Bob", playerClass = "MAGE", state = State.NeedMainSpec, roll = 98 }
	local ann = { playerName = "Ann", playerClass = "PRIEST", state = State.Greed, roll = 71 }
	local now = time()
	local first = { encounterID = -1, name = "Lucifron", instance = "Molten Core", time = now - 3600 }
	local second = { encounterID = -2, name = "Magmadar", instance = "Molten Core", time = now - 1800 }
	History.Preview({
		Logic.Record(Drop(bob, State.Greed), first, 1, now - 3500),
		Logic.Record(Drop(ann, State.Pass), first, 2, now - 3500),
		Logic.Record(Drop(bob, State.Pass), second, 1, now - 1700),
		Logic.Record(
			Drop({ playerName = me, isSelf = true, state = State.NeedMainSpec, roll = 87 }, State.NeedMainSpec),
			second,
			2,
			now - 1700
		),
	})
end

function Rolls:OnEnable()
	Cards.Setup()
	History.SetRecords(Saved())
	SuppressBlizzard()
	CreateNotchButton()
	-- The island would push the cards down while the cursor reaches for them.
	ns.NotchBlocked = Cards.Shown

	ns.RegisterEvent("START_LOOT_ROLL", OnStartRoll)
	ns.RegisterEvent("CANCEL_LOOT_ROLL", OnCancelRoll)
	ns.RegisterEvent("CANCEL_ALL_LOOT_ROLLS", OnCancelAll)
	ns.RegisterEvent("LOOT_HISTORY_UPDATE_DROP", OnDrop)
	ns.RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED", ReadSoon)
	ns.RegisterEvent("PLAYER_REGEN_ENABLED", ReadSoon)
	OpenActiveRolls()
end

ns.RegisterModuleCommand("rolls", "rolls", Preview)
