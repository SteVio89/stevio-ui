-- Run with: lua tests/roll_logic_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")
local ns = loadAddonFile("Modules/Rolls/Logic.lua")
local Logic = ns.RollLogic
local State = Logic.State

local link = "|cffa335ee|Hitem:19019::::::::60:::::|h[Thunderfury]|h|r"
local otherLink = "|cffa335ee|Hitem:17182::::::::60:::::|h[Sulfuras]|h|r"
-- The same item with other bonus data in its link.
local sameItem = "|cffa335ee|Hitem:19019::::::::60:::1:3524::|h[Thunderfury]|h|r"

check(Logic.ShortName("Bob-Realm") == "Bob" and Logic.ShortName("Bob") == "Bob", "short name")
check(Logic.ShortName(nil) == nil, "no name")
check(Logic.ItemID(link) == 19019 and Logic.ItemID("money") == nil, "item id")
check(Logic.StateOfRollType(Logic.RollType.Need) == State.NeedMainSpec, "need click")
check(Logic.StateOfRollType(Logic.RollType.Transmog) == State.Transmog, "transmog click")
check(Logic.StateOfRollType(Logic.RollType.Pass) == State.Pass, "pass click")

-- Loot history drops.
local function Info(name, state, roll, isSelf, class)
	return { playerName = name, playerClass = class or "MAGE", state = state, roll = roll, isSelf = isSelf }
end

local open = Logic.Summary({
	itemHyperlink = link,
	playerRollState = State.Greed,
	rollInfos = {
		Info("Tom", State.NoRoll),
		Info("Ann-Realm", State.Greed, 71),
		Info("Me", State.Greed, nil, true),
		Info("Bob", State.Pass),
		Info("Cid", State.NeedMainSpec, 12),
	},
})
check(open.pending and not open.winner and not open.allPassed, "open roll")
check(#open.rolls == 4, "players who haven't chosen are left out")
check(open.rolls[1].name == "Ann" and open.rolls[2].name == "Cid", "numbers high to low")
check(open.rolls[3].isSelf and open.rolls[4].state == State.Pass, "then choices without number, passes last")
check(open.mine.isSelf and open.mine.state == State.Greed, "own choice")

local decided = Logic.Summary({
	itemHyperlink = link,
	playerRollState = State.Greed,
	winner = Info("Cid", State.NeedMainSpec, 12),
	rollInfos = {
		Info("Ann", State.Greed, 99),
		Info("Me", State.Greed, 45, true),
		Info("Cid", State.NeedMainSpec, 12),
		Info("Dan", State.Greed, 30),
		Info("Eve", State.Greed, 20),
	},
})
check(not decided.pending and decided.winner.name == "Cid", "decided")
check(decided.rolls[1].name == "Cid" and decided.rolls[2].name == "Ann", "need beats a higher greed: winner first")

local mineFromState = Logic.Summary({ playerRollState = State.Pass, rollInfos = {} })
check(mineFromState.mine.state == State.Pass, "own choice from the drop state")
check(Logic.Summary({ playerRollState = State.NoRoll, rollInfos = {} }).mine == nil, "not chosen yet")
check(Logic.Summary({ allPassed = true, rollInfos = {} }).pending == false, "all passed is decided")

-- Top 3 others plus the own roll where it ranks.
local top = Logic.TopRolls(decided, 3)
check(#top == 4, "three others and mine")
check(top[1].name == "Cid" and top[2].name == "Ann" and top[3].isSelf and top[4].name == "Dan", "mine where it ranks")
local low = Logic.Summary({
	rollInfos = {
		Info("A", State.Greed, 90),
		Info("B", State.Greed, 80),
		Info("C", State.Greed, 70),
		Info("D", State.Greed, 60),
		Info("Me", State.Greed, 5, true),
	},
})
top = Logic.TopRolls(low, 3)
check(#top == 4 and top[3].name == "C" and top[4].isSelf, "D left out, mine last")
top = Logic.TopRolls(mineFromState, 3)
check(#top == 1 and top[1].state == State.Pass, "own choice without a roll entry")

-- Texts. Class colors are marked as "<class:name>".
local function classColored(name, class)
	return class and ("<%s:%s>"):format(class, name) or name
end
local L = { you = "you", rolling = "rolling", allPassed = "All passed", youWin = "You win", wins = "%s wins" }
local labels = { [State.NeedMainSpec] = "Need", [State.Greed] = "Greed", [State.Pass] = "Pass" }
check(Logic.RollText({ state = State.Greed }, labels) == "Greed", "choice without number")
check(Logic.RollText({ state = State.Greed, roll = 45 }, labels) == "Greed 45", "choice with number")
check(
	Logic.RollsLine({ decided.rolls[1], decided.mine }, L, labels, classColored)
		== "<MAGE:Cid> |cffaaaaaaNeed 12|r · you |cffaaaaaaGreed 45|r",
	"rolls line"
)
check(Logic.ResultText(decided, L, classColored) == "<MAGE:Cid> wins", "winner")
check(Logic.ResultText(open, L, classColored) == "|cffaaaaaarolling|r", "still rolling")
check(Logic.ResultText(nil, L, classColored) == "|cffaaaaaarolling|r", "no drop yet")
check(Logic.ResultText({ allPassed = true }, L, classColored) == "|cffaaaaaaAll passed|r", "all passed")
check(Logic.ResultText({ winner = { isSelf = true } }, L, classColored) == "|cff40ff40You win|r", "own win")

-- A drop belongs to the earliest card of the same item without a drop.
local cards = {
	{ rollID = 1, link = otherLink, started = 1 },
	{ rollID = 2, link = link, started = 5 },
	{ rollID = 3, link = sameItem, started = 3 },
	{ rollID = 4, link = link, started = 0, dropKey = "1:1" },
	{ rollID = 5, link = link, started = -1, preview = true },
}
check(Logic.MatchCard(cards, link).rollID == 3, "same item, earliest, not taken, not a preview")
check(Logic.MatchCard(cards, "|cff|Hitem:1|h[X]|h|r") == nil, "no card for that item")

-- Open rolls first, each in start order.
local sorted = Logic.SortCards({
	{ rollID = 1, started = 1, choice = 2 },
	{ rollID = 2, started = 3 },
	{ rollID = 3, started = 2 },
	{ rollID = 4, started = 0, choice = 0 },
})
check(sorted[1].rollID == 3 and sorted[2].rollID == 2, "open ones on top")
check(sorted[3].rollID == 4 and sorted[4].rollID == 1, "answered below")

local fade = { fadeOutTime = 2 }
check(Logic.CardAlpha({}, 100, fade) == 1, "no fade while rolling")
check(Logic.CardAlpha({ fadeAt = 10 }, 9, fade) == 1, "held until fadeAt")
check(Logic.CardAlpha({ fadeAt = 10 }, 11, fade) == 0.5, "fading")
check(Logic.CardAlpha({ fadeAt = 10 }, 12, fade) == nil, "gone")
check(Logic.TimeLeft({ started = 10, duration = 60 }, 40) == 30, "time left")
check(Logic.TimeLeft({ started = 10, duration = 60 }, 99) == 0, "never below zero")

-- History records.
local fight = { encounterID = 672, name = "Ragnaros", instance = "Molten Core", time = 1000 }
local record = Logic.Record(decided, fight, 2, 1060)
check(record.encounter == "Ragnaros" and record.instance == "Molten Core" and record.fightTime == 1000, "fight")
check(record.link == link and record.winner.name == "Cid" and #record.rolls == 5, "drop")
check(record.mine == true, "greed counts as rolled on")
check(Logic.Record(mineFromState, fight, 3, 1060).mine == nil, "a pass doesn't")
check(Logic.Record({ rolls = {}, winner = { isSelf = true } }, fight, 4, 1060).mine == true, "a win does")

local records = {}
check(Logic.SaveRecord(records, record) == 1, "added")
local again = Logic.Record(decided, { encounterID = 672, name = "Ragnaros", time = 1002 }, 2, 1070)
check(Logic.SaveRecord(records, again) == 1 and records[1] == again and #records == 1, "same drop replaced")
local nextFight = Logic.Record(decided, { encounterID = 672, name = "Ragnaros", time = 5000 }, 2, 5060)
check(Logic.SaveRecord(records, nextFight) == 2, "same boss and key in a later fight is new")

local function linkName(itemLink)
	return itemLink:match("|h%[(.-)%]|h")
end
check(Logic.Matches(record, "", false, linkName), "no filter")
check(Logic.Matches(record, "thunder", false, linkName), "item name")
check(Logic.Matches(record, "ragna", false, linkName), "boss")
check(Logic.Matches(record, "eve", false, linkName), "player")
check(not Logic.Matches(record, "sulfuras", false, linkName), "no match")
check(not Logic.Matches({ link = link, rolls = {} }, "", true, linkName), "mine only")

-- Rows: newest first, a header per fight, rolls under an expanded drop.
local history = {
	Logic.Record(decided, { encounterID = 1, name = "Lucifron", time = 100 }, 1, 110),
	Logic.Record(decided, { encounterID = 2, name = "Magmadar", time = 200 }, 1, 210),
	Logic.Record(open, { encounterID = 2, name = "Magmadar", time = 200 }, 2, 220),
}
local rows = Logic.HistoryRows(history, {}, {}, linkName)
check(#rows == 5, "two headers, three drops")
check(rows[1].kind == "header" and rows[1].record.encounter == "Magmadar", "newest fight first")
check(rows[2].record == history[3] and rows[3].record == history[2], "newest drop first")
check(rows[4].kind == "header" and rows[5].record == history[1], "older fight below")
rows = Logic.HistoryRows(history, {}, { [history[1]] = true }, linkName)
check(#rows == 10 and rows[6].kind == "roll" and rows[6].roll.name == "Cid", "expanded drop lists its rolls")
rows = Logic.HistoryRows(history, { search = "lucif" }, {}, linkName)
check(#rows == 2 and rows[2].record == history[1], "filtered")

local function formatDate(time)
	return "d" .. time
end
check(Logic.HeaderText(history[1], formatDate, "?") == "Lucifron · d100", "header without instance")
check(Logic.HeaderText(record, formatDate, "?") == "Ragnaros · Molten Core · d1000", "header with instance")
check(Logic.HeaderText({ encounter = "", time = 5 }, formatDate, "Loot") == "Loot · d5", "unnamed fight")

-- Simulated rolls (/sui roll).
check(Logic.Winner({ Info("Ann", State.Greed, 99), Info("Cid", State.NeedMainSpec, 12) }).playerName == "Cid", "need wins")
check(Logic.Winner({ Info("Ann", State.Greed, 40), Info("Dan", State.Greed, 70) }).playerName == "Dan", "highest roll")
check(
	Logic.Winner({ Info("Ann", State.Greed, 99), Info("Eve", State.Transmog, 5) }).playerName == "Eve",
	"transmog before greed"
)
check(Logic.Winner({ Info("Ann", State.Pass), Info("Bob", State.NoRoll) }) == nil, "nobody rolled")

local function Fixed(...)
	local values, i = { ... }, 0
	return function()
		i = i + 1
		return values[i]
	end
end
check(Logic.SimulatedChoice(Fixed(2), false) == State.NeedMainSpec, "simulated need")
check(Logic.SimulatedChoice(Fixed(5), false) == State.Greed, "simulated greed")
check(Logic.SimulatedChoice(Fixed(5), true) == State.Transmog, "simulated transmog")
check(Logic.SimulatedChoice(Fixed(9), true) == State.Pass, "simulated pass")

local sim = {
	link = link,
	players = {
		{ playerName = "Me", isSelf = true, state = State.Greed },
		{ playerName = "Bob", playerClass = "MAGE", state = State.Greed },
		{ playerName = "Ann", playerClass = "PRIEST" },
	},
}
local running = Logic.Summary(Logic.SimulatedDrop(sim))
check(running.pending and #running.rolls == 2 and running.mine.state == State.Greed, "simulated roll still open")
Logic.DecideSimulated(sim, Fixed(50, 50, 80))
check(sim.players[1].roll == 50 and sim.players[2].roll == 80, "a tie is rolled again")
check(sim.players[3].state == State.Pass and sim.players[3].roll == nil, "no choice passes")
local done = Logic.Summary(Logic.SimulatedDrop(sim))
check(not done.pending and done.winner.name == "Bob" and done.rolls[1].name == "Bob", "simulated winner")
check(done.mine.roll == 50, "own number")
local passed = { link = link, players = { { playerName = "Me", isSelf = true, state = State.Pass } } }
Logic.DecideSimulated(passed, Fixed())
check(Logic.Summary(Logic.SimulatedDrop(passed)).allPassed, "all passed")

print("roll logic tests passed")
