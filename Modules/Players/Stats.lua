local _, ns = ...

-- Statistics over the whole player database (#86): the groups you were in,
-- roll behaviour compared with everyone, who you play with most and who to
-- watch out for. Free of WoW API calls like Store.lua, which it extends;
-- times are passed in. `dayStart` is the local midnight of today (seconds
-- like time()), so days follow the player's clock.

local Store = ns.PlayersStore

local DAY = 24 * 60 * 60

-- When a session ends: its stop, now while it is open.
local function Stop(session, now)
	return session.stop or (session.open and now) or session.start or 0
end

-- Rolls ----------------------------------------------------------------------

-- A player's rolls ({ need = 3, ... }) as { count = n, total = n, share = 0..1 }
-- per choice in Store.CHOICES, plus total.
function Store.RollShares(rolls)
	local shares, total = {}, 0
	for _, choice in ipairs(Store.CHOICES) do
		total = total + (rolls and rolls[choice] or 0)
	end
	for _, choice in ipairs(Store.CHOICES) do
		local count = rolls and rolls[choice] or 0
		shares[choice] = { count = count, share = total > 0 and count / total or 0 }
	end
	shares.total = total
	return shares
end

-- The rolls of everyone in the database together, as Store.RollShares: the
-- "average of your fellow players".
function Store:RollAverages()
	local sums = {}
	for _, player in pairs(self.db.players) do
		for choice, count in pairs(player.rolls or {}) do
			sums[choice] = (sums[choice] or 0) + count
		end
	end
	return Store.RollShares(sums)
end

Store.OUTLIER_MIN_ROLLS = 10
Store.OUTLIER_FACTOR = 1.5

-- Whether `player` rolls Need conspicuously often: at least 10 rolls and a
-- Need share of at least 1.5 times the average (Store:RollAverages).
function Store.NeedOutlier(player, averages)
	local shares = Store.RollShares(player.rolls)
	if shares.total < Store.OUTLIER_MIN_ROLLS or shares.need.count == 0 then
		return false
	end
	-- Cross-multiplied, so exactly 1.5 times isn't lost to rounding.
	return shares.need.count * averages.total >= Store.OUTLIER_FACTOR * averages.need.count * shares.total
end

-- The Need outliers, highest Need share first: { player, share, total }.
function Store:NeedOutliers(averages)
	local list = {}
	for _, player in pairs(self.db.players) do
		if Store.NeedOutlier(player, averages) then
			local shares = Store.RollShares(player.rolls)
			list[#list + 1] = { player = player, share = shares.need.share, total = shares.total }
		end
	end
	table.sort(list, function(a, b)
		if a.share ~= b.share then
			return a.share > b.share
		end
		return a.player.name < b.player.name
	end)
	return list
end

-- Groups -----------------------------------------------------------------------

-- Your groups since `since` (nil: all): sessions whose times overlap belong to
-- the same group, since everyone in a group gets a session at once. Oldest
-- first; each { start, stop, entries = { { player, session } }, instance
-- (any instance entered), kills, wipes }. Bosses go into every session of
-- the group, so the group's count is the largest of its sessions.
function Store:Groups(now, since)
	local entries = {}
	for _, player in pairs(self.db.players) do
		for _, session in ipairs(player.sessions) do
			if session.start and (not since or session.start >= since) then
				entries[#entries + 1] = { player = player, session = session }
			end
		end
	end
	table.sort(entries, function(a, b)
		if a.session.start ~= b.session.start then
			return a.session.start < b.session.start
		end
		return a.player.name < b.player.name
	end)

	local groups, current = {}, nil
	for _, entry in ipairs(entries) do
		local session = entry.session
		local stop = Stop(session, now)
		if not current or session.start >= current.stop then
			current = { start = session.start, stop = stop, entries = {}, kills = 0, wipes = 0 }
			groups[#groups + 1] = current
		end
		current.stop = math.max(current.stop, stop)
		current.entries[#current.entries + 1] = entry
		current.instance = current.instance or session.instance or #(session.instances or {}) > 0
		current.kills = math.max(current.kills, #(session.kills or {}))
		current.wipes = math.max(current.wipes, session.wipes or 0)
	end
	return groups
end

-- Groups since `since` with players still to rate (finished, unrated
-- sessions), newest first; each { start, entries = { { name, class, session } } }
-- as the rating popup takes them.
function Store:UnratedGroups(now, since)
	local list = {}
	local groups = self:Groups(now, since)
	for index = #groups, 1, -1 do
		local group = groups[index]
		local entries = {}
		for _, entry in ipairs(group.entries) do
			local session = entry.session
			if not session.open and not session.stars then
				entries[#entries + 1] = { name = entry.player.name, class = entry.player.class, session = session }
			end
		end
		if #entries > 0 then
			list[#list + 1] = { start = group.start, entries = entries }
		end
	end
	return list
end

-- Players whose sessions overlap those of `player` in time ("often in the
-- same group"), most shared groups first: { player, count } with count the
-- number of their sessions that overlap one of `player`'s. Open sessions
-- count as running on.
function Store:Partners(player, limit)
	local list = {}
	for _, other in pairs(self.db.players) do
		if other ~= player then
			local count = 0
			for _, theirs in ipairs(other.sessions) do
				local theirStop = Stop(theirs, math.huge)
				for _, mine in ipairs(player.sessions) do
					if
						theirs.start
						and mine.start
						and theirs.start < Stop(mine, math.huge)
						and mine.start < theirStop
					then
						count = count + 1
						break
					end
				end
			end
			if count > 0 then
				list[#list + 1] = { player = other, count = count }
			end
		end
	end
	table.sort(list, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.player.name < b.player.name
	end)
	for index = #list, (limit or #list) + 1, -1 do
		list[index] = nil
	end
	return list
end

-- Overview -----------------------------------------------------------------------

Store.ATTENTION_STARS = 2

-- Why a player needs attention: "blocked" (marked guild), "avoid" (verdict)
-- or "low" (average of at most 2 stars); nil when none. Also returns the
-- overall rating ({ average, count }, nil when unrated).
function Store.Attention(player)
	local overall = Store.Summary(player).overall
	if player.blocked then
		return "blocked", overall
	elseif player.verdict == "avoid" then
		return "avoid", overall
	elseif overall and overall.average <= Store.ATTENTION_STARS then
		return "low", overall
	end
	return nil, overall
end

-- The first second of the period of the last `days` days, today included
-- (nil days: everything, nil).
function Store.PeriodStart(dayStart, days)
	return days and dayStart - (days - 1) * DAY or nil
end

Store.ALL_DAYS_CHART = 90
Store.TOP_COUNT = 5
Store.UNRATED_DAYS = 7

-- Everything the overview page shows, for the last `days` days (nil: all):
--   players, newPlayers (first seen in the period), groups, dungeons,
--   seconds (time in groups), averageSeconds, kills, wipes (of the period);
--   rated (players with a rating), averageStars (mean of their averages),
--   distribution[1..5] (players per rounded average);
--   top: up to 5 { player, seconds } by time together in the period;
--   perDay: groups per day, oldest first, today last (90 days for "all");
--   attention: { player, reason, overall }, marked and avoided first, then
--     by last seen;
--   unrated, unratedGroups: unrated sessions and groups of the last 7 days.
function Store:Overview(now, days, dayStart)
	local since = Store.PeriodStart(dayStart, days)
	local overview = {
		players = 0,
		newPlayers = 0,
		groups = 0,
		dungeons = 0,
		seconds = 0,
		averageSeconds = 0,
		kills = 0,
		wipes = 0,
		rated = 0,
		distribution = { 0, 0, 0, 0, 0 },
		top = {},
		perDay = {},
		attention = {},
	}

	local starSum = 0
	local together = {}
	for _, player in pairs(self.db.players) do
		overview.players = overview.players + 1
		if not since or (player.firstSeen or 0) >= since then
			overview.newPlayers = overview.newPlayers + 1
		end
		local reason, overall = Store.Attention(player)
		if overall then
			overview.rated = overview.rated + 1
			starSum = starSum + overall.average
			local rounded = math.max(1, math.min(Store.MAX_STARS, math.floor(overall.average + 0.5)))
			overview.distribution[rounded] = overview.distribution[rounded] + 1
		end
		if reason then
			overview.attention[#overview.attention + 1] = { player = player, reason = reason, overall = overall }
		end
		local seconds = 0
		for _, session in ipairs(player.sessions) do
			if session.start and (not since or session.start >= since) then
				seconds = seconds + math.max(0, Stop(session, now) - session.start)
			end
		end
		if seconds > 0 then
			together[#together + 1] = { player = player, seconds = seconds }
		end
	end
	overview.averageStars = overview.rated > 0 and starSum / overview.rated or nil

	table.sort(together, function(a, b)
		if a.seconds ~= b.seconds then
			return a.seconds > b.seconds
		end
		return a.player.name < b.player.name
	end)
	for index = 1, math.min(Store.TOP_COUNT, #together) do
		overview.top[index] = together[index]
	end

	table.sort(overview.attention, function(a, b)
		local aLow, bLow = a.reason == "low", b.reason == "low"
		if aLow ~= bLow then
			return bLow
		end
		if (a.player.lastSeen or 0) ~= (b.player.lastSeen or 0) then
			return (a.player.lastSeen or 0) > (b.player.lastSeen or 0)
		end
		return a.player.name < b.player.name
	end)

	local chartDays = days or Store.ALL_DAYS_CHART
	local chartStart = Store.PeriodStart(dayStart, chartDays)
	for index = 1, chartDays do
		overview.perDay[index] = 0
	end
	for _, group in ipairs(self:Groups(now, since)) do
		overview.groups = overview.groups + 1
		overview.dungeons = overview.dungeons + (group.instance and 1 or 0)
		overview.seconds = overview.seconds + math.max(0, group.stop - group.start)
		overview.kills = overview.kills + group.kills
		overview.wipes = overview.wipes + group.wipes
		local day = math.floor((group.start - chartStart) / DAY) + 1
		if day >= 1 and day <= chartDays then
			overview.perDay[day] = overview.perDay[day] + 1
		end
	end
	overview.averageSeconds = overview.groups > 0 and overview.seconds / overview.groups or 0

	local unratedGroups = self:UnratedGroups(now, Store.PeriodStart(dayStart, Store.UNRATED_DAYS))
	overview.unratedGroups, overview.unrated = #unratedGroups, 0
	for _, group in ipairs(unratedGroups) do
		overview.unrated = overview.unrated + #group.entries
	end
	return overview
end

-- Where a time falls for the list's sections: "today", "yesterday", "week"
-- (the last 7 days), "month" (the last 30 days) or "older".
function Store.Age(time, dayStart)
	time = time or 0
	if time >= dayStart then
		return "today"
	elseif time >= dayStart - DAY then
		return "yesterday"
	elseif time >= dayStart - 6 * DAY then
		return "week"
	elseif time >= dayStart - 29 * DAY then
		return "month"
	end
	return "older"
end
