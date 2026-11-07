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

-- Roll messages: the roll number isn't a count, the name is the roller.
-- Messages about yourself come first: "%s won" would also match "You won".
local rolls = Feed.Patterns(
	"You won: %s",
	"%1$s won: %3$s |cff818181(Need - %2$d)|r",
	"Need Roll - %d for %s by %s + Role Bonus",
	"Need Roll - %d for %s by %s",
	"%s won: %s",
	"Everyone passed on: %s"
)
local rollLink, roller = Feed.ParseRoll("Bob won: " .. link .. " |cff818181(Need - 87)|r", rolls)
check(rollLink == link and roller == "Bob", "won, with roll")
rollLink, roller = Feed.ParseRoll("Need Roll - 87 for " .. link .. " by Anna", rolls)
check(rollLink == link and roller == "Anna", "rolled")
rollLink, roller = Feed.ParseRoll("Need Roll - 5 for " .. link .. " by Anna + Role Bonus", rolls)
check(rollLink == link and roller == "Anna", "rolled with role bonus")
rollLink, roller = Feed.ParseRoll("You won: " .. link, rolls)
check(rollLink == link and roller == nil, "own win has no name")
rollLink, roller = Feed.ParseRoll("Everyone passed on: " .. link, rolls)
check(rollLink == link and roller == nil, "everyone passed")
check(Feed.ParseRoll("You receive loot: " .. link .. ".", rolls) == nil, "loot is no roll")

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
group:Add({ link = link, roll = true, count = 1 }, 4, true)
group:Add({ link = link, roll = true, count = 1 }, 5, true)
check(#group.entries == 4, "rolls don't merge")

print("loot feed tests passed")
