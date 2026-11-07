-- Run with: lua tests/loot_feed_test.lua  (from the repo root)
local ns = {}
assert(loadfile("Modules/LootTicker/Feed.lua"))("stevio-ui", ns)
local Feed = ns.LootFeed

local function check(cond, msg)
	if not cond then
		error("FAIL: " .. msg, 2)
	end
end

local link = "|cff0070dd|Hitem:2589::::::::80:::::|h[Linen Cloth]|h|r"
local currency = "|cffffffff|Hcurrency:3008:0|h[Valorstones]|h|r"

-- Format strings as the enUS / deDE clients define them.
local patterns = Feed.Patterns(
	"You receive loot: %sx%d.",
	"You receive loot: %s.",
	nil, -- a global this client doesn't have
	"Ihr erhaltet Beute: %2$dx %1$s.",
	"You receive currency: %s x%d.",
	"You receive currency: %s."
)
check(#patterns == 5, "missing formats are skipped")

local l, n = Feed.Parse("You receive loot: " .. link .. ".", patterns)
check(l == link and n == 1, "single item")
l, n = Feed.Parse("You receive loot: " .. link .. "x12.", patterns)
check(l == link and n == 12, "stack is not swallowed by the single pattern")
l, n = Feed.Parse("Ihr erhaltet Beute: 3x " .. link .. ".", patterns)
check(l == link and n == 3, "positional specifiers")
l, n = Feed.Parse("You receive currency: " .. currency .. " x25.", patterns)
check(l == currency and n == 25, "currency")
check(Feed.Parse("Bob receives loot: " .. link .. ".", patterns) == nil, "others' loot is ignored")
check(Feed.Parse("You receive loot: nothing.", patterns) == nil, "no link, no entry")

-- Money messages (enUS / deDE coin formats).
local money = Feed.MoneyPatterns("%d Gold", "%d Silver", "%d Copper")
check(Feed.ParseMoney("You loot 1 Gold, 23 Silver, 45 Copper", money) == 12345, "all coins")
check(Feed.ParseMoney("You loot 7 Copper", money) == 7, "copper only")
check(Feed.ParseMoney("Your share of the loot is 2 Silver, 3 Copper.", money) == 203, "share")
check(Feed.ParseMoney("You loot 1,234 Gold", money) == 12340000, "thousands separator")
check(Feed.ParseMoney("You loot 5 Silver (1 Copper deposited to guild bank)", money) == 500, "guild part ignored")
check(Feed.ParseMoney("You loot nothing", money) == nil, "no coins")
local geld = Feed.MoneyPatterns("%d Gold", "%d Silber", "%d Kupfer")
check(Feed.ParseMoney("Ihr erhaltet 3 Gold, 4 Kupfer.", geld) == 30004, "German coins")
check(Feed.ParseMoney("2 Gold", Feed.MoneyPatterns("%1$d Gold", "%1$d Silver", "%1$d Copper")) == 20000, "positional")

check(Feed.LinkName(link) == "Linen Cloth", "name without brackets")
check(Feed.LinkColor(link) == "ff0070dd", "link color")

local options = { fadeInTime = 0.2, holdTime = 10, fadeOutTime = 5 }
check(Feed.Alpha(0, options) == 0, "starts invisible")
check(Feed.Alpha(0.1, options) == 0.5, "fades in")
check(Feed.Alpha(5, options) == 1, "holds")
check(math.abs(Feed.Alpha(12.7, options) - 0.5) < 1e-9, "fades out")
check(Feed.Alpha(15.2, options) == nil, "gone")

check(Feed.Slide(0, 18, 0.1, 18, 0.2) == 9, "slides half a row")
check(Feed.Slide(9, 18, 0.2, 18, 0.2) == 18, "stops at the target")
check(Feed.Slide(18, 0, 0.1, 18, 0.2) == 9, "slides down too")

-- FIFO: the newest is first, the oldest drops out of a full feed.
local feed = Feed.New(3)
for i = 1, 4 do
	feed:Add({ link = "item" .. i, key = "item" .. i, count = 1 }, i)
end
check(#feed.entries == 3, "capped")
check(feed.entries[1].link == "item4" and feed.entries[3].link == "item2", "oldest dropped")

-- Merging moves the line to the bottom with the summed count.
feed:Add({ link = "item2", key = "item2", count = 4 }, 5, true)
check(#feed.entries == 3 and feed.entries[1].link == "item2", "merged entry is newest")
check(feed.entries[1].count == 5, "counts add up")
feed:Add({ link = "item2", key = "item2", count = 1 }, 6, false)
check(feed.entries[1].count == 1 and feed.entries[2].link == "item2", "no merge when disabled")

check(feed:Expire(6 + 0.2 + 10 + 5 - 0.5, options) == 1, "old entries expire")
check(feed.entries[1].time == 6, "newest survives")
check(feed:Expire(100, options) == 0, "all gone")

-- Other players' loot: the name comes out of the message.
local others = Feed.Patterns("%s receives loot: %sx%d.", "%s receives loot: %s.", "%2$s erhält Beute: %1$s.")
local _, count, name = Feed.Parse("Bob receives loot: " .. link .. "x3.", others)
check(name == "Bob" and count == 3, "others' loot with count")
_, count, name = Feed.Parse("Bob receives loot: " .. link .. ".", others)
check(name == "Bob" and count == 1, "others' loot")
local l2
l2, _, name = Feed.Parse("Anna erhält Beute: " .. link .. ".", others)
check(l2 == link and name == "Anna", "others' loot, positional")
check(select(3, Feed.Parse("You receive loot: " .. link .. ".", patterns)) == nil, "own loot has no name")

local qualityHex = { [2] = "ff1eff00", [3] = "ff0070dd", [4] = "ffa335ee" }
check(Feed.QualityFromColor("ff0070dd", qualityHex) == 3, "quality from link color")
check(Feed.QualityFromColor("FFA335EE", qualityHex) == 4, "case-insensitive")
check(Feed.QualityFromColor("ff123456", qualityHex) == nil, "unknown color")
check(Feed.QualityFromColor(nil, qualityHex) == nil, "no color")

-- Same item by different players stays apart; rolls never merge.
local group = Feed.New(5)
group:Add({ link = link, key = "Bob" .. link, count = 1 }, 1, true)
group:Add({ link = link, key = "Al" .. link, count = 1 }, 2, true)
group:Add({ link = link, key = "Bob" .. link, count = 2 }, 3, true)
check(#group.entries == 2 and group.entries[1].count == 3, "merged per player")

-- A roll replaces the row of its drop in place, without adding counts,
-- even when repeats don't merge.
local rolls = Feed.New(5)
rolls:Add({ link = link, key = "drop:1:1", replace = true, roll = true, count = 1, y = 0 }, 1, false)
rolls:Add({ link = link, key = "Bob" .. link, count = 1 }, 2, false)
local decided = rolls:Add({ link = link, key = "drop:1:1", replace = true, roll = true, count = 1 }, 3, false)
check(#rolls.entries == 2 and rolls.entries[2] == decided, "roll keeps its row")
check(decided.count == 1 and decided.y == 0 and decided.time == 3, "roll replaced, not added up")

-- Loot history drops.
local State = Feed.RollState
check(Feed.ShortName("Bob-Antonidas") == "Bob" and Feed.ShortName("Bob") == "Bob", "short name")
check(Feed.ShortName(nil) == nil, "no name")

local open = Feed.RollSummary({
	itemHyperlink = link,
	playerRollState = State.NeedMainSpec,
	allPassed = false,
	rollInfos = {
		{ playerName = "Bob", playerClass = "MAGE", isSelf = false, state = State.Greed },
		{ playerName = "Me", playerClass = "PRIEST", isSelf = true, state = State.NeedMainSpec },
	},
})
check(open.pending and not open.winner, "open roll")
check(open.mine and open.mine.state == State.NeedMainSpec and open.mine.roll == nil, "own choice, no number yet")

local undecided = Feed.RollSummary({ playerRollState = State.NoRoll, rollInfos = {} })
check(undecided.pending and undecided.mine == nil, "not chosen yet")
check(
	Feed.RollSummary({ playerRollState = State.Pass, rollInfos = {} }).mine.state == State.Pass,
	"own pass from state"
)

local won = Feed.RollSummary({
	playerRollState = State.Greed,
	winner = { playerName = "Bob-Realm", playerClass = "MAGE", isSelf = false, state = State.NeedMainSpec, roll = 98 },
	rollInfos = {
		{ playerName = "Bob-Realm", playerClass = "MAGE", isSelf = false, state = State.NeedMainSpec, roll = 98 },
		{ playerName = "Me", playerClass = "PRIEST", isSelf = true, state = State.Greed, roll = 45 },
	},
})
check(not won.pending and won.winner.name == "Bob" and won.winner.roll == 98, "winner without realm")
check(won.mine.roll == 45, "own roll number")
local passed = Feed.RollSummary({ allPassed = true, playerRollState = State.Pass, rollInfos = {} })
check(passed.allPassed and not passed.pending, "all passed")

-- A loot message for a won item belongs to its roll row; the loot line it
-- would have made before the roll was decided is taken back.
local drops = Feed.New(5)
drops:Add({ link = link, key = "drop:1:2", replace = true, roll = true, count = 1, winner = won.winner }, 1)
check(drops:RollFor(link, "Bob-Realm") == drops.entries[1], "loot of the winner")
check(drops:RollFor(link, "Anna") == nil, "loot of someone else")
check(drops:RollFor(link, nil) == nil, "own loot of an item Bob won")
check(drops:RollFor(currency, "Bob") == nil, "other item")
drops.entries[1].received = true
check(drops:RollFor(link, "Bob") == nil, "each roll claims one message")
local mine = Feed.New(5)
mine:Add({ link = link, key = "drop:1:3", replace = true, roll = true, count = 1, winner = { isSelf = true } }, 1)
check(mine:RollFor(link, nil) ~= nil and mine:RollFor(link, "Bob") == nil, "own win")

local early = Feed.New(5)
early:Add({ link = link, key = "Bob" .. link, count = 1, looter = "Bob-Realm" }, 10)
early:Add({ link = link, key = link, count = 1 }, 10)
check(not early:TakeLoot(link, "Bob", 20, 5), "too old to take back")
check(early:TakeLoot(link, "Bob", 12, 5) and #early.entries == 1, "winner's line taken back")
check(early.entries[1].looter == nil, "own line stays")
check(early:TakeLoot(link, nil, 12, 5) and #early.entries == 0, "own line taken back")

-- Fading: group lines stay shorter, open rolls stay until they end.
local opts = { fadeInTime = 0.2, holdTime = 10, fadeOutTime = 5, groupHoldTime = 3 }
check(Feed.EntryAlpha({ time = 0 }, 8, opts) == 1, "own line held")
check(Feed.EntryAlpha({ time = 0, other = true }, 9, opts) == nil, "group line gone")
local pending = { time = 0, pendingUntil = 60 }
check(Feed.EntryAlpha(pending, 0.1, opts) == 0.5, "open roll fades in")
check(Feed.EntryAlpha(pending, 59, opts) == 1, "open roll held")
check(Feed.EntryAlpha(pending, 65, opts) == 1, "held after it timed out")
check(Feed.EntryAlpha(pending, 76, opts) == nil, "then fades out")

print("loot feed tests passed")
