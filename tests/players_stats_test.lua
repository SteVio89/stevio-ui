-- Run with: lua tests/players_stats_test.lua  (from the repo root)
-- Modules/Players/Stats.lua: roll averages, Need outliers, partners, groups
-- and the overview page's numbers (#86).
local check, loadAddonFile = dofile("tests/helpers.lua")
local ns = loadAddonFile("Modules/Players/Store.lua")
loadAddonFile("Modules/Players/Stats.lua", ns)
local Store = ns.PlayersStore

local DAY = 24 * 60 * 60
local HOUR = 60 * 60

local function near(a, b)
	return math.abs(a - b) < 1e-9
end

-- Rolls: the average over everyone, outliers from 10 rolls at 1.5 times it.
local store = Store.New(nil)
store:Ensure("Greedy", nil, 0).rolls = { need = 7, greed = 2, pass = 1 }
store:Ensure("Fair", nil, 0).rolls = { need = 3, greed = 20, transmog = 4, pass = 3 }
store:Ensure("Few", nil, 0).rolls = { need = 5 }
store:Ensure("Quiet", nil, 0)
local averages = store:RollAverages()
check(averages.total == 45 and near(averages.need.share, 15 / 45), "need share of all rolls")
check(averages.greed.count == 22 and averages.transmog.count == 4 and averages.pass.count == 4, "counts")
check(Store.NeedOutlier(store:Player("Greedy"), averages), "70% need at 10 rolls")
check(not Store.NeedOutlier(store:Player("Fair"), averages), "10% need")
check(not Store.NeedOutlier(store:Player("Few"), averages), "under 10 rolls")
check(not Store.NeedOutlier(store:Player("Quiet"), averages), "no rolls")
local outliers = store:NeedOutliers(averages)
check(#outliers == 1 and outliers[1].player.name == "Greedy" and near(outliers[1].share, 0.7), "outlier list")
check(outliers[1].total == 10, "with the roll count")
check(Store.RollShares(nil).total == 0 and Store.RollShares(nil).need.share == 0, "nothing rolled")
-- At exactly 1.5 times the average it counts.
store = Store.New(nil)
store:Ensure("Edge", nil, 0).rolls = { need = 3, greed = 7 }
store:Ensure("Rest", nil, 0).rolls = { need = 3, greed = 17 }
local edgeAverages = store:RollAverages() -- need 6 of 30: 20 %
check(Store.NeedOutlier(store:Player("Edge"), edgeAverages), "30 % is exactly 1.5 x 20 %")
store:Player("Edge").rolls = { need = 3, greed = 8 }
check(not Store.NeedOutlier(store:Player("Edge"), store:RollAverages()), "just under")
print("rolls ok")

-- Partners: overlapping sessions count, most shared groups first.
store = Store.New(nil)
local function Session(name, start, stop, extra)
	local player = store:Ensure(name, nil, start)
	local session = { start = start, stop = stop, zones = {}, instances = {} }
	for key, value in pairs(extra or {}) do
		session[key] = value
	end
	player.sessions[#player.sessions + 1] = session
	player.lastSeen = math.max(player.lastSeen or 0, stop or start)
	return session
end
Session("Me2", 100, 200)
Session("Me2", 1000, 1200)
Session("Me2", 5000, 5100)
Session("Pal", 150, 250)
Session("Pal", 1100, 1150)
Session("Once", 5050, 5060)
Session("Never", 300, 400)
Session("Touch", 200, 300) -- starts as Me2's ends: not the same group
local partners = store:Partners(store:Player("Me2"), 5)
check(#partners == 2 and partners[1].player.name == "Pal" and partners[1].count == 2, "most shared first")
check(partners[2].player.name == "Once" and partners[2].count == 1, "then the rest")
check(#store:Partners(store:Player("Me2"), 1) == 1, "limited")
local open = Session("Open", 5080, nil)
open.open = true
check(#store:Partners(store:Player("Me2"), 5) == 3, "open session overlaps")
print("partners ok")

-- Groups: overlapping sessions are one group; bosses counted once per group.
store = Store.New(nil)
local today = 100 * DAY -- local midnight
local now = today + 20 * HOUR
-- Today, a dungeon with three players, two kills and a wipe each.
local kills = { "A", "B" }
Session("Tank", today + 10 * HOUR, today + 11 * HOUR, { instance = true, kills = kills, wipes = 1, stars = 5 })
Session("Heal", today + 10 * HOUR, today + 11 * HOUR, { instance = true, kills = kills, wipes = 1 })
Session("Dps", today + 10 * HOUR + 600, today + 11 * HOUR, { instances = { "X" }, kills = kills, wipes = 1 })
-- Yesterday, open world with Tank again (rated 1) and someone new.
Session("Tank", today - 5 * HOUR, today - 4 * HOUR, { stars = 1 })
Session("Mage", today - 5 * HOUR, today - 4 * HOUR, { stars = 2 })
-- Ten days ago, outside 7 days.
Session("Old", today - 10 * DAY, today - 10 * DAY + HOUR, { stars = 4 })
store:Player("Old").firstSeen = today - 10 * DAY
for _, name in ipairs({ "Tank", "Heal", "Dps", "Mage" }) do
	store:Player(name).firstSeen = today - 5 * HOUR
end
store:SetVerdict("Heal", "avoid", now)
store:Player("Heal").lastSeen = today + 11 * HOUR
store:Ensure("Marked", nil, today - 20 * DAY).blocked = { guild = "Bad", time = 1 }
store:Player("Marked").firstSeen = today - 20 * DAY
store:Player("Mage").lastSeen = today - 4 * HOUR

local groups = store:Groups(now)
check(#groups == 3, "three groups")
check(#groups[3].entries == 3 and groups[3].instance and groups[3].kills == 2 and groups[3].wipes == 1, "today's")
check(groups[1].stop - groups[1].start == HOUR, "group time")

local week = store:Overview(now, 7, today)
check(week.players == 6 and week.newPlayers == 4, "players and new ones")
check(week.groups == 2 and week.dungeons == 1, "groups in 7 days")
check(week.seconds == 2 * HOUR and week.averageSeconds == HOUR, "time")
check(week.kills == 2 and week.wipes == 1, "bosses once per group")
check(week.rated == 3, "rated players: Tank, Mage, Old")
check(near(week.averageStars, (3 + 2 + 4) / 3), "mean of the averages")
check(week.distribution[3] == 1 and week.distribution[2] == 1 and week.distribution[4] == 1, "distribution")
check(#week.perDay == 7 and week.perDay[7] == 1 and week.perDay[6] == 1 and week.perDay[1] == 0, "per day")
check(week.top[1].player.name == "Tank" and week.top[1].seconds == 2 * HOUR, "most time first")
check(#week.top == 4, "only players of the period")
local reasons = {}
for index, entry in ipairs(week.attention) do
	reasons[index] = entry.player.name .. ":" .. entry.reason
end
check(table.concat(reasons, ",") == "Heal:avoid,Marked:blocked,Mage:low", "attention, worst first")
check(week.unratedGroups == 1 and week.unrated == 2, "unrated: Heal and Dps today; yesterday's all rated")

local all = store:Overview(now, nil, today)
check(all.groups == 3 and all.newPlayers == 6 and #all.perDay == Store.ALL_DAYS_CHART, "everything")
check(all.perDay[Store.ALL_DAYS_CHART - 10] == 1, "old group on the chart")
local empty = Store.New(nil):Overview(now, 30, today)
check(empty.groups == 0 and empty.averageStars == nil and empty.averageSeconds == 0 and #empty.top == 0, "empty")

local unrated = store:UnratedGroups(now, today - 6 * DAY)
check(#unrated == 1 and #unrated[1].entries == 2, "today's group with two unrated")
check(unrated[1].entries[1].session and unrated[1].entries[1].name, "entries as the popup takes them")
print("overview ok")

-- Sections of the list.
check(Store.Age(today + 5, today) == "today" and Store.Age(today - 5, today) == "yesterday", "today, yesterday")
check(Store.Age(today - 6 * DAY, today) == "week" and Store.Age(today - 7 * DAY, today) == "month", "week")
check(Store.Age(today - 29 * DAY, today) == "month" and Store.Age(today - 30 * DAY, today) == "older", "month")
check(Store.Age(nil, today) == "older", "never")
print("ages ok")

-- List filters and counts.
store = Store.New(nil)
local liked = store:Ensure("Liked", nil, 1)
liked.verdict = "like"
liked.sessions = { { start = 1, stop = 2, role = "HEALER", stars = 4 }, { start = 3, stop = 4 } }
local avoided = store:Ensure("Avoided", nil, 1)
avoided.verdict, avoided.note = "avoid", "no"
avoided.sessions = { { start = 1, stop = 100, role = "TANK" } }
store:Ensure("Marked", nil, 1).blocked = { guild = "X" }
check(Store.LastRole(liked) == "HEALER" and Store.LastRole(store:Player("Marked")) == nil, "last role")
local counts = store:ListCounts(nil, nil)
check(counts.all == 3 and counts.rated == 1 and counts.like == 1 and counts.avoid == 1, "chip counts")
check(counts.note == 1 and counts.marked == 1, "note and marked")
check(store:ListCounts(nil, "TANK").all == 1 and store:ListCounts("lik", nil).all == 1, "role and search")
local function names(list)
	local result = {}
	for index, player in ipairs(list) do
		result[index] = player.name
	end
	return table.concat(result, ",")
end
check(names(store:Players(nil, "time", 0)) == "Avoided,Liked,Marked", "most time together first")
check(names(store:Players(nil, "name", 0, function(player)
	return Store.ListFilter(player, "avoid")
end)) == "Avoided", "filtered list")
print("list ok")

print("players stats tests passed")
