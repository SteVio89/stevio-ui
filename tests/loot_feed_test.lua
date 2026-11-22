-- Run with: lua tests/loot_feed_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")
local ns = loadAddonFile("Modules/LootTicker/Feed.lua")
local Feed = ns.LootFeed

local link = "|cff0070dd|Hitem:2589::::::::80:::::|h[Linen Cloth]|h|r"
local currency = "|cffffffff|Hcurrency:3008:0|h[Valorstones]|h|r"

-- Format strings become anchored patterns: magic characters escaped,
-- positional specifiers made plain.
check(Feed.PatternFromFormat("You receive loot: %sx%d.") == "^You receive loot: (.+)x(%d+)%.$", "pattern")
check(
	Feed.PatternFromFormat("Ihr erhaltet Beute: %2$dx %1$s.") == "^Ihr erhaltet Beute: (%d+)x (.+)%.$",
	"positional pattern"
)
check(Feed.PatternFromFormat("[%s] (+%d%%)?") == "^%[(.+)%] %(%+(%d+)%%%)%?$", "magic characters")

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
local r, g, b = Feed.HexToRGB("ff0070dd")
check(r == 0 and g == 0x70 / 255 and b == 0xdd / 255, "link color as RGB")
r, g, b = Feed.HexToRGB("FFFFFFFF")
check(r == 1 and g == 1 and b == 1, "uppercase hex")

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

check(Feed.Parse("Bob receives loot: " .. link .. ".", patterns) == nil, "others' loot never matches")

local qualityHex = { [2] = "ff1eff00", [3] = "ff0070dd", [4] = "ffa335ee" }
check(Feed.QualityFromColor("ff0070dd", qualityHex) == 3, "quality from link color")
check(Feed.QualityFromColor("FFA335EE", qualityHex) == 4, "case-insensitive")
check(Feed.QualityFromColor("ff123456", qualityHex) == nil, "unknown color")
check(Feed.QualityFromColor(nil, qualityHex) == nil, "no color")

-- Fading of a whole entry.
check(Feed.EntryAlpha({ time = 0 }, 8, options) == 1, "line held")
check(Feed.EntryAlpha({ time = 0 }, 16, options) == nil, "line gone")

check(Feed.LootDetail({ count = 1 }) == "", "single item")
check(Feed.LootDetail({ count = 3 }) == "|cffffffffx3|r", "stack")

-- Filter: currency by option, items from their minimum quality on.
local filter = { showCurrency = true, minQuality = 1 }
check(Feed.Passes(1, false, filter), "item at the minimum")
check(not Feed.Passes(0, false, filter), "item below the minimum")
check(Feed.Passes(nil, false, filter), "unknown quality passes")
check(Feed.Passes(0, true, filter), "currency ignores the quality")
check(not Feed.Passes(5, true, { showCurrency = false, minQuality = 0 }), "currency off")

-- Messages kept during the chat lockdown are read once it is over; the ones
-- still unreadable are dropped.
do
	local secret = {}
	local texts = { [11] = "You receive loot: " .. link .. ".", [12] = secret }
	local read = {}
	Feed.ReadPending({
		{ event = "CHAT_MSG_LOOT", lineID = 11 },
		{ event = "CHAT_MSG_LOOT", lineID = 12 },
		{ event = "CHAT_MSG_MONEY", lineID = 13 },
	}, function(lineID)
		return texts[lineID]
	end, function(event, text)
		read[#read + 1] = event .. ":" .. text
	end, function(value)
		return value == secret
	end)
	check(#read == 1 and read[1] == "CHAT_MSG_LOOT:" .. texts[11], "readable line handled, others dropped")
end

-- CurrencyDisplay reads the fields C_CurrencyInfo returns.
do
	local icon, quality = Feed.CurrencyDisplay({ iconFileID = 4638724, quality = 3, name = "Valorstones" })
	check(icon == 4638724 and quality == 3, "currency icon and quality")
	check(Feed.CurrencyDisplay(nil) == nil, "unknown currency")
end

print("loot feed tests passed")
