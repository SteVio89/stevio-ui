local _, ns = ...

-- Game-independent part of the player database: everyone you group with,
-- their group sessions with ratings, bosses and wipes, their loot rolls and
-- the items they won. Times are passed in (`now`, seconds like time()) so
-- this can be tested outside the game.

local Store = {}
ns.PlayersStore = Store
Store.__index = Store

-- 2 (#86): names normalized, verdict, tags, noteTime, win.choice.
Store.VERSION = 2
Store.ROLES = { "TANK", "HEALER", "DAMAGER" }
Store.MAX_STARS = 5

local DAY = 24 * 60 * 60

-- Wraps the saved table `db` (created when nil) and fills in missing parts.
-- options: rejoinGrace, ownRealm (see Store.NormalizeName; entries saved
-- under another spelling of a name are merged into one).
-- `upgradedFrom` is the version of an older table, for the upgrades that need
-- the game (Store:FillWinChoices).
function Store.New(db, options)
	db = db or { version = Store.VERSION }
	db.players = db.players or {}
	db.recentTags = db.recentTags or {}
	options = options or {}
	local store = setmetatable({ db = db, rejoinGrace = options.rejoinGrace or 0, ownRealm = options.ownRealm }, Store)
	store:MergeDuplicates()
	local version = db.version or 1
	if version < Store.VERSION then
		store.upgradedFrom = version
		-- Version 2 only adds optional fields; the merge above did the rest.
		db.version = Store.VERSION
	end
	return store
end

-- Names ----------------------------------------------------------------------

-- The one spelling players are stored under: "Name" on your realm, else
-- "Name-Realm" with the realm's spaces and hyphens removed, as
-- Ambiguate(..., "none") gives chat names. Takes "Name-Realm", "Name Realm",
-- "Name - Realm Name", "Name (Realm)" and "Name": character names have no
-- spaces or hyphens, so whatever follows them is the realm. `ownRealm` is
-- GetNormalizedRealmName() (nil: unknown, the realm is kept).
-- WoW Forever names characters "First Last" (#42): the group roster gives
-- them as "First-Last", the loot history as "First Last" and chat events as
-- "First Last-OwnRealm". All three end up as "First-Last". Nil for no name.
function Store.NormalizeName(name, ownRealm)
	if type(name) ~= "string" then
		return nil
	end
	if ownRealm and ownRealm ~= "" and name:sub(-#ownRealm - 1) == "-" .. ownRealm then
		name = name:sub(1, -#ownRealm - 2)
	end
	local short, rest = name:match("^%s*([^%s%-%(%)]+)(.*)$")
	if not short then
		return nil
	end
	local realm = rest:gsub("[%s%-%(%)]", "")
	if realm == "" or realm == ownRealm then
		return short
	end
	return short .. "-" .. realm
end

-- The name a whisper or invite goes to: WoW Forever wants "First Last"
-- without a realm (#42), so the stored "First-Last" gets its space back.
function Store.SendName(name)
	return (name:gsub("^([^-]+)-", "%1 ", 1))
end

function Store:Key(name)
	return Store.NormalizeName(name, self.ownRealm)
end

local function SortBy(list, field)
	table.sort(list, function(a, b)
		return (a[field] or 0) < (b[field] or 0)
	end)
end

-- Moves everything of `from` into `into` (two entries of the same player):
-- sessions, rolls, wins, note, mark; first seen is the earlier, last seen
-- the later of both.
function Store.MergeInto(into, from)
	for _, session in ipairs(from.sessions or {}) do
		into.sessions[#into.sessions + 1] = session
	end
	SortBy(into.sessions, "start")
	if from.rolls then
		into.rolls = into.rolls or {}
		for choice, count in pairs(from.rolls) do
			into.rolls[choice] = (into.rolls[choice] or 0) + count
		end
	end
	if from.wins then
		into.wins = into.wins or {}
		for _, win in ipairs(from.wins) do
			into.wins[#into.wins + 1] = win
		end
		SortBy(into.wins, "time")
	end
	if from.note and from.note ~= into.note then
		into.note = into.note and (into.note .. "\n" .. from.note) or from.note
	end
	if from.noteTime and (into.noteTime or 0) < from.noteTime then
		into.noteTime = from.noteTime
	end
	-- Avoid outweighs like: a warning should never get lost in a merge.
	if from.verdict == "avoid" or not into.verdict then
		into.verdict = from.verdict or into.verdict
	end
	for _, tag in ipairs(from.tags or {}) do
		Store.AddTagTo(into, tag)
	end
	if from.blocked and (not into.blocked or (from.blocked.time or 0) < (into.blocked.time or 0)) then
		into.blocked = from.blocked
	end
	into.class = into.class or from.class
	if from.guild and (not into.guild or (from.lastSeen or 0) > (into.lastSeen or 0)) then
		into.guild = from.guild
	end
	into.firstSeen = math.min(into.firstSeen or from.firstSeen or 0, from.firstSeen or into.firstSeen or 0)
	into.lastSeen = math.max(into.lastSeen or 0, from.lastSeen or 0)
end

-- Saves every player under Store.NormalizeName, merging entries that turn
-- out to be the same player. Returns how many were merged away.
function Store:MergeDuplicates()
	local players = self.db.players
	local names = {}
	for name in pairs(players) do
		names[#names + 1] = name
	end
	-- Fixed order, so the same entry survives on every machine.
	table.sort(names)
	local merged = 0
	for _, name in ipairs(names) do
		local key = self:Key(name)
		local player = players[name]
		if key and key ~= name then
			players[name] = nil
			local existing = players[key]
			if existing then
				Store.MergeInto(existing, player)
				merged = merged + 1
			else
				player.name = key
				players[key] = player
			end
		elseif key then
			player.name = key
		end
	end
	return merged
end

-- Players ------------------------------------------------------------------

function Store:Player(name)
	local key = self:Key(name)
	return key and self.db.players[key]
end

-- The player's entry, created when missing. `class` (a class file name such
-- as "PRIEST") is kept from the latest call that knows it.
function Store:Ensure(name, class, now)
	name = self:Key(name)
	local player = self.db.players[name]
	if not player then
		player = { name = name, firstSeen = now, lastSeen = now, sessions = {} }
		self.db.players[name] = player
	end
	if class then
		player.class = class
	end
	return player
end

local function OpenSession(player)
	local last = player.sessions[#player.sessions]
	if last and last.open then
		return last
	end
end

-- Moves the session's time at its current place into its zone totals.
local function Credit(session, now)
	if session.at and session.since then
		session.zones[session.at] = (session.zones[session.at] or 0) + math.max(0, now - session.since)
	end
	session.since = now
end

local function SetPlace(session, place, isInstance, now)
	Credit(session, now)
	session.at = place
	if place and isInstance then
		for _, name in ipairs(session.instances) do
			if name == place then
				return
			end
		end
		session.instances[#session.instances + 1] = place
	end
end

-- Starts (or continues) a session with `name`. info: class, role (as the game
-- assigned it: "TANK", "HEALER", "DAMAGER"; anything else counts as none),
-- place and isInstance (where you are now). A session that ended less than
-- rejoinGrace seconds ago is continued. Returns the session and whether it is new.
function Store:Open(name, info, now)
	local player = self:Ensure(name, info.class, now)
	player.lastSeen = now
	local role = Store.IsRole(info.role) and info.role or nil

	local session = OpenSession(player)
	local isNew = false
	if not session then
		local last = player.sessions[#player.sessions]
		if last and last.stop and now - last.stop <= self.rejoinGrace then
			session = last
			session.open, session.stop = true, nil
			session.zones, session.instances = session.zones or {}, session.instances or {}
		else
			session = { start = now, open = true, zones = {}, instances = {} }
			player.sessions[#player.sessions + 1] = session
			isNew = true
		end
		SetPlace(session, info.place, info.isInstance, now)
	end
	if role and not session.role then
		session.role = role
	end
	return session, isNew
end

-- The place of a finished session: the instances entered in order, or else the
-- zone where most of the session was spent. Returns the text and whether it
-- names instances.
function Store.Where(session)
	if #session.instances > 0 then
		return table.concat(session.instances, ", "), true
	end
	local best, bestTime
	for zone, seconds in pairs(session.zones) do
		if not bestTime or seconds > bestTime or (seconds == bestTime and zone < best) then
			best, bestTime = zone, seconds
		end
	end
	return best, false
end

-- Ends the open session with `name`; returns it (nil when there was none).
function Store:Close(name, now)
	local player = self:Player(name)
	local session = player and OpenSession(player)
	if not session then
		return nil
	end
	Credit(session, now)
	session.where, session.instance = Store.Where(session)
	-- Zones and instances stay, so a rejoin continues from them.
	session.open, session.stop = nil, now
	session.at, session.since = nil, nil
	player.lastSeen = now
	return session
end

-- Names of the players with an open session, sorted.
function Store:OpenNames()
	local names = {}
	for name, player in pairs(self.db.players) do
		if OpenSession(player) then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	return names
end

-- You moved to `place`: every open session spends its time there from now on.
function Store:Visit(place, isInstance, now)
	for _, player in pairs(self.db.players) do
		local session = OpenSession(player)
		if session then
			SetPlace(session, place, isInstance, now)
		end
	end
end

function Store.IsRole(role)
	return role == "TANK" or role == "HEALER" or role == "DAMAGER"
end

-- The next role when cycling through them: none, tank, healer, DPS, none, ...
function Store.NextRole(role)
	if role == nil then
		return Store.ROLES[1]
	end
	for index, candidate in ipairs(Store.ROLES) do
		if candidate == role then
			return Store.ROLES[index + 1]
		end
	end
end

-- Sets (1 to 5) or clears (nil) a session's rating.
function Store.Rate(session, stars)
	if stars ~= nil then
		stars = math.max(1, math.min(Store.MAX_STARS, math.floor(stars)))
	end
	session.stars = stars
end

local function Trimmed(text)
	text = text and text:match("^%s*(.-)%s*$") or ""
	return text ~= "" and text or nil
end

function Store.SetComment(session, text)
	session.comment = Trimmed(text)
end

function Store:SetPlayerNote(name, text, now)
	local player = self:Ensure(name, nil, now)
	local note = Trimmed(text)
	if note ~= player.note then
		player.note = note
		player.noteTime = note and now or nil
	end
	return player
end

-- Empties the database: every player, their sessions, ratings, notes,
-- verdicts, tags and marks, and the tag suggestions. The window position
-- stays. Returns how many players were removed.
function Store:Reset()
	local count = 0
	for _ in pairs(self.db.players) do
		count = count + 1
	end
	self.db.players, self.db.recentTags, self.db.loggedOut = {}, {}, nil
	return count
end

-- Removes the player for good.
function Store:Forget(name)
	local key = self:Key(name)
	if key then
		self.db.players[key] = nil
	end
end

-- Verdict and tags (#86) ------------------------------------------------------

Store.VERDICTS = { like = true, avoid = true }

-- "like", "avoid" or nil (neutral): whether you want to play with them again,
-- apart from the stars.
function Store:SetVerdict(name, verdict, now)
	local player = self:Ensure(name, nil, now)
	player.verdict = Store.VERDICTS[verdict] and verdict or nil
	return player
end

Store.MAX_TAG_LENGTH = 24
Store.MAX_RECENT_TAGS = 20

-- A tag as saved: trimmed, inner spaces collapsed, cut to MAX_TAG_LENGTH
-- characters (UTF-8 aware, umlauts count once). Nil when empty.
function Store.CleanTag(text)
	text = Trimmed(type(text) == "string" and text:gsub("%s+", " ") or nil)
	if not text then
		return nil
	end
	local chars = 0
	for start in text:gmatch("()[^\128-\191]") do
		chars = chars + 1
		if chars > Store.MAX_TAG_LENGTH then
			return Trimmed(text:sub(1, start - 1))
		end
	end
	return text
end

-- Tags are the same when they differ only in case (ASCII letters).
local function SameTag(a, b)
	return a:lower() == b:lower()
end

-- Adds `tag` to the player's tags unless they have it; returns the saved tag
-- (nil when empty or already there).
function Store.AddTagTo(player, tag)
	tag = Store.CleanTag(tag)
	if not tag then
		return nil
	end
	player.tags = player.tags or {}
	for _, existing in ipairs(player.tags) do
		if SameTag(existing, tag) then
			return nil
		end
	end
	player.tags[#player.tags + 1] = tag
	return tag
end

-- Remembers `tag` as the most recently used one, for suggestions.
function Store:UseTag(tag)
	local recent = self.db.recentTags
	for index = #recent, 1, -1 do
		if SameTag(recent[index], tag) then
			table.remove(recent, index)
		end
	end
	table.insert(recent, 1, tag)
	for index = #recent, Store.MAX_RECENT_TAGS + 1, -1 do
		recent[index] = nil
	end
end

function Store:AddTag(name, text, now)
	local player = self:Ensure(name, nil, now)
	local tag = Store.AddTagTo(player, text)
	if tag then
		self:UseTag(tag)
	end
	return tag
end

function Store:RemoveTag(name, tag)
	local player = self:Player(name)
	for index = #(player and player.tags or {}), 1, -1 do
		if SameTag(player.tags[index], tag) then
			table.remove(player.tags, index)
		end
	end
	if player and player.tags and #player.tags == 0 then
		player.tags = nil
	end
end

-- Up to `limit` of the most recently used tags (anywhere in the database)
-- that `player` doesn't have yet.
function Store:TagSuggestions(player, limit)
	local list = {}
	for _, tag in ipairs(self.db.recentTags) do
		local has = false
		for _, own in ipairs(player and player.tags or {}) do
			has = has or SameTag(own, tag)
		end
		if not has then
			list[#list + 1] = tag
			if #list >= limit then
				break
			end
		end
	end
	return list
end

function Store.HasRating(player)
	for _, session in ipairs(player.sessions) do
		if session.stars then
			return true
		end
	end
	return false
end

-- Average stars of the rated sessions: overall and per role, each
-- { average, count }, or nil when nothing there is rated.
function Store.Summary(player)
	local sums = {}
	local function Add(key, stars)
		local sum = sums[key] or { total = 0, count = 0 }
		sum.total, sum.count = sum.total + stars, sum.count + 1
		sums[key] = sum
	end
	for _, session in ipairs(player.sessions) do
		if session.stars then
			Add("overall", session.stars)
			if session.role then
				Add(session.role, session.stars)
			end
		end
	end
	local summary = {}
	for key, sum in pairs(sums) do
		summary[key] = { average = sum.total / sum.count, count = sum.count }
	end
	return summary
end

-- Blocked guilds (#45) ------------------------------------------------------

-- The first of `patterns` (Lua patterns, case-insensitive) that `guild`
-- matches, or nil. A pattern that isn't valid Lua is matched as plain text.
function Store.MatchGuild(guild, patterns)
	if not guild or guild == "" or not patterns then
		return nil
	end
	local lower = guild:lower()
	for _, pattern in ipairs(patterns) do
		if type(pattern) == "string" and pattern ~= "" then
			local needle = pattern:lower()
			local ok, found = pcall(string.find, lower, needle)
			if not ok then
				found = lower:find(needle, 1, true)
			end
			if found then
				return pattern
			end
		end
	end
	return nil
end

-- The player `name` was seen in `guild` (nil: in none, as far as the game
-- says). Players already in the notes get their guild updated; one whose
-- guild matches `patterns` is added and marked as blocked. The mark stays
-- when they leave the guild later. Returns the player (nil when not in the
-- notes) and whether they were marked just now.
function Store:SeeGuild(name, guild, class, patterns, now)
	if guild == "" then
		guild = nil
	end
	local player = self:Player(name)
	local pattern = Store.MatchGuild(guild, patterns)
	if pattern and not (player and player.blocked) then
		player = self:Ensure(name, class, now)
		player.guild = guild
		player.blocked = { guild = guild, pattern = pattern, time = now }
		return player, true
	end
	if player then
		player.guild = guild
	end
	return player, false
end

-- Removes the blocked mark of `name` (e.g. a false match).
function Store:Unblock(name)
	local player = self:Player(name)
	if player then
		player.blocked = nil
	end
end

-- Deletes the players last seen more than `days` ago that have neither a
-- rated session, a note, a verdict, tags nor a blocked mark (nor an open
-- session). Returns how many.
function Store:Prune(now, days)
	local cutoff = now - days * DAY
	local removed = 0
	for name, player in pairs(self.db.players) do
		local keep = player.note
			or player.blocked
			or player.verdict
			or (player.tags and #player.tags > 0)
			or Store.HasRating(player)
			or OpenSession(player)
			or (player.lastSeen or 0) >= cutoff
		if not keep then
			self.db.players[name] = nil
			removed = removed + 1
		end
	end
	return removed
end

local function HasTag(player, filter)
	for _, tag in ipairs(player.tags or {}) do
		if tag:lower():find(filter, 1, true) then
			return true
		end
	end
	return false
end

local function Matches(player, filter)
	if not filter or filter == "" then
		return true
	end
	filter = filter:lower()
	return player.name:lower():find(filter, 1, true)
		or (player.note and player.note:lower():find(filter, 1, true))
		or (player.guild and player.guild:lower():find(filter, 1, true))
		or (player.blocked and player.blocked.guild and player.blocked.guild:lower():find(filter, 1, true))
		or HasTag(player, filter)
end

-- Players matching `filter` (part of the name, note, guild or a tag), sorted by `sortBy`:
-- "name", "rating" (best first, unrated last), "time" (most time together
-- up to `now` first) or "recent" (the default). `keep(player)`, when given,
-- narrows the list further (Store.ListFilter).
function Store:Players(filter, sortBy, now, keep)
	local list, keys = {}, {}
	for _, player in pairs(self.db.players) do
		if Matches(player, filter) and (not keep or keep(player)) then
			list[#list + 1] = player
			if sortBy == "rating" then
				local overall = Store.Summary(player).overall
				keys[player] = overall and overall.average or -1
			elseif sortBy == "time" then
				keys[player] = Store.Stats(player, now or 0).seconds
			elseif sortBy ~= "name" then
				keys[player] = player.lastSeen or 0
			end
		end
	end
	table.sort(list, function(a, b)
		if sortBy ~= "name" and keys[a] ~= keys[b] then
			return keys[a] > keys[b]
		end
		return a.name < b.name
	end)
	return list
end

-- "4.3": an average with one decimal.
function Store.FormatAverage(average)
	return ("%.1f"):format(math.floor(average * 10 + 0.5) / 10)
end

-- The first non-empty line of a text, for lists.
function Store.Title(text)
	return (text or ""):match("^%s*([^\n]-)%s*\n") or (text or ""):match("^%s*(.-)%s*$")
end

-- Bosses (#74) ---------------------------------------------------------------

-- A boss fight ended while grouped: every open session gets the kill (by
-- boss name; nil when the game didn't say it) or a wipe.
function Store:Encounter(boss, success)
	for _, player in pairs(self.db.players) do
		local session = OpenSession(player)
		if session then
			if success then
				session.kills = session.kills or {}
				session.kills[#session.kills + 1] = boss or "?"
			else
				session.wipes = (session.wipes or 0) + 1
			end
		end
	end
end

-- Loot (#74) -----------------------------------------------------------------

Store.CHOICES = { "need", "greed", "transmog", "pass" }

-- `name` chose `choice` ("need", "greed", "transmog" or "pass") on a drop.
function Store:AddRoll(name, class, choice, now)
	local player = self:Ensure(name, class, now)
	player.rolls = player.rolls or {}
	player.rolls[choice] = (player.rolls[choice] or 0) + 1
	return player
end

-- `name` won a drop. win: link, encounter (boss name), instance, time and
-- choice ("need", "greed" or "transmog", when known).
function Store:AddWin(name, class, win, now)
	local player = self:Ensure(name, class, now)
	player.wins = player.wins or {}
	player.wins[#player.wins + 1] = win
	return player
end

-- Wins saved before win.choice (#86): `choiceOf(name, win)` looks the choice
-- up (in the roll history). Returns how many it found.
function Store:FillWinChoices(choiceOf)
	local filled = 0
	for name, player in pairs(self.db.players) do
		for _, win in ipairs(player.wins or {}) do
			if not win.choice then
				win.choice = choiceOf(name, win)
				filled = filled + (win.choice and 1 or 0)
			end
		end
	end
	return filled
end

-- The wins of `player` during `session`, oldest first. The roll may end a
-- little after the group broke up, so wins up to rejoinGrace after the
-- session count too.
function Store:SessionWins(player, session)
	local list = {}
	local stop = session.stop and session.stop + self.rejoinGrace
	for _, win in ipairs(player.wins or {}) do
		if win.time and session.start and win.time >= session.start and (not stop or win.time <= stop) then
			list[#list + 1] = win
		end
	end
	return list
end

-- Group stats (#74) ----------------------------------------------------------

-- Everything done together: groups, seconds grouped (open sessions up to
-- `now`), bosses killed, wipes, items won (winsNeed of them with Need), and
-- the rolls by choice with their total.
function Store.Stats(player, now)
	local stats = { groups = #player.sessions, seconds = 0, kills = 0, wipes = 0, wins = #(player.wins or {}) }
	stats.winsNeed = 0
	for _, win in ipairs(player.wins or {}) do
		if win.choice == "need" then
			stats.winsNeed = stats.winsNeed + 1
		end
	end
	for _, session in ipairs(player.sessions) do
		local stop = session.stop or (session.open and now) or session.start
		if session.start and stop then
			stats.seconds = stats.seconds + math.max(0, stop - session.start)
		end
		stats.kills = stats.kills + #(session.kills or {})
		stats.wipes = stats.wipes + (session.wipes or 0)
	end
	stats.rolls, stats.rollCount = {}, 0
	for _, choice in ipairs(Store.CHOICES) do
		local count = player.rolls and player.rolls[choice] or 0
		stats.rolls[choice] = count
		stats.rollCount = stats.rollCount + count
	end
	return stats
end

-- "3h 05m", "45m", "<1m".
function Store.FormatDuration(seconds)
	local minutes = math.floor(seconds / 60)
	if minutes < 1 then
		return "<1m"
	elseif minutes < 60 then
		return ("%dm"):format(minutes)
	end
	return ("%dh %02dm"):format(math.floor(minutes / 60), minutes % 60)
end

-- The share of `count` in `total` as whole percent.
function Store.Percent(count, total)
	if total == 0 then
		return 0
	end
	return math.floor(count / total * 100 + 0.5)
end
