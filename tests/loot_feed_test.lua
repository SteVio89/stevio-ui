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
	feed:Add({ link = "item" .. i, count = 1 }, i)
end
check(#feed.entries == 3, "capped")
check(feed.entries[1].link == "item4" and feed.entries[3].link == "item2", "oldest dropped")

-- Merging moves the line to the bottom with the summed count.
feed:Add({ link = "item2", count = 4 }, 5, true)
check(#feed.entries == 3 and feed.entries[1].link == "item2", "merged entry is newest")
check(feed.entries[1].count == 5, "counts add up")
feed:Add({ link = "item2", count = 1 }, 6, false)
check(feed.entries[1].count == 1 and feed.entries[2].link == "item2", "no merge when disabled")

check(feed:Expire(6 + 0.2 + 10 + 5 - 0.5, options) == 1, "old entries expire")
check(feed.entries[1].time == 6, "newest survives")
check(feed:Expire(100, options) == 0, "all gone")

print("loot feed tests passed")
