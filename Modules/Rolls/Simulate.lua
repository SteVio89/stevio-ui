local _, ns = ...

-- /sui roll: made-up group loot rolls, to try the roll cards without a group.
-- Each drop (items from the bags) gets a card whose buttons work but don't
-- really roll; four made-up group members choose within a few seconds, and
-- once everyone has chosen (or the timer ran out) the numbers and the winner
-- are in. The drops go through the same summary as real ones from the loot
-- history. They aren't saved: `/sui roll history` shows them in the history
-- window until it is closed.

local Logic = ns.RollLogic
local Cards = ns.RollCards
local History = ns.RollHistory
local T = ns.T

local DURATION = 30
-- Made-up group members choose this many seconds (at most) after the drop.
local LATEST_CHOICE = 8
local MAX_DROPS = 5
local GROUP = {
	{ playerName = "Bob", playerClass = "MAGE" },
	{ playerName = "Ann", playerClass = "PRIEST" },
	{ playerName = "Tom", playerClass = "WARRIOR" },
	{ playerName = "Kim", playerClass = "ROGUE" },
}

-- Decided simulated drops of this session, oldest first, as history records.
local records = {}
local simulations = 0
local drops = 0

-- Item links from the bags, one per item.
local function BagItems()
	local links, seen = {}, {}
	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.hyperlink and not seen[info.itemID] then
				seen[info.itemID] = true
				links[#links + 1] = info.hyperlink
			end
		end
	end
	return links
end

local function Group(now)
	local _, class = UnitClass("player")
	local players = { { playerName = UnitName("player"), playerClass = class, isSelf = true } }
	for _, member in ipairs(GROUP) do
		players[#players + 1] = {
			playerName = member.playerName,
			playerClass = member.playerClass,
			chooseAt = now + 1 + math.random() * (LATEST_CHOICE - 1),
		}
	end
	return players
end

local function Update(sim, card)
	Cards.UpdateDrop(card.dropKey, Logic.Summary(Logic.SimulatedDrop(sim)))
end

local function Finish(sim, card)
	Logic.DecideSimulated(sim, math.random)
	local summary = Logic.Summary(Logic.SimulatedDrop(sim))
	Cards.UpdateDrop(card.dropKey, summary)
	records[#records + 1] = Logic.Record(summary, sim.fight, sim.index, time())
	History.Refresh()
end

-- Runs every few frames until the roll is decided.
local function Step(sim, card, ticker)
	local now = GetTime()
	local changed, waiting = false, false
	for _, player in ipairs(sim.players) do
		if not player.state then
			if player.isSelf and card.choice then
				player.state = Logic.StateOfRollType(card.choice)
				changed = true
			elseif player.chooseAt and now >= player.chooseAt then
				player.state = Logic.SimulatedChoice(math.random, sim.canTransmog)
				changed = true
			else
				waiting = true
			end
		end
	end
	local timeUp = now >= card.started + card.duration
	if timeUp and not card.choice then
		-- What CANCEL_LOOT_ROLL does to an unanswered roll.
		Cards.Ended(card.rollID)
	end
	if timeUp or not waiting then
		ticker:Cancel()
		Finish(sim, card)
	elseif changed then
		Update(sim, card)
	end
end

local function Drop(link, index, fight)
	drops = drops + 1
	local now = GetTime()
	local name, _, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(link)
	local canTransmog = math.random(1, 3) == 1
	local card = Cards.Add({
		rollID = -100 - drops,
		dropKey = "simulated:" .. drops,
		preview = true,
		link = link,
		name = name or link,
		quality = quality,
		icon = icon,
		canNeed = true,
		canGreed = true,
		canTransmog = canTransmog or nil,
		duration = DURATION,
		started = now,
	})
	local sim = { link = link, index = index, fight = fight, canTransmog = canTransmog, players = Group(now) }
	local ticker
	ticker = C_Timer.NewTicker(0.1, function()
		Step(sim, card, ticker)
	end)
end

local function ShowHistory()
	if #records == 0 then
		ns.Print(T("No simulated drops yet: /sui roll [1-5]", "Noch keine simulierte Beute: /sui roll [1-5]"))
		return
	end
	History.Preview(records)
end

local function Simulate(input)
	if input == "history" then
		ShowHistory()
		return
	end
	local count = math.min(MAX_DROPS, math.max(1, tonumber(input) or 1))
	local links = BagItems()
	if #links == 0 then
		ns.Print(
			T(
				"Put an item in your bags to simulate a drop",
				"Für eine simulierte Beute einen Gegenstand in die Taschen legen"
			)
		)
		return
	end
	simulations = simulations + 1
	local fight = {
		encounterID = -100 - simulations,
		name = T("Simulated drops", "Simulierte Beute"),
		instance = "/sui roll",
		time = time(),
	}
	for i = 1, count do
		-- Different items while the bags have enough of them.
		local link = table.remove(links, math.random(1, #links))
		if #links == 0 then
			links = BagItems()
		end
		Drop(link, i, fight)
	end
end

ns.RegisterModuleCommand("roll", "rolls", Simulate)
