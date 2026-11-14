local _, ns = ...

-- Game-independent part of the notes: players with their group sessions and
-- ratings, item notes and general notes, all in one saved table. Times are
-- passed in (`now`, seconds like time()) so this can be tested outside the game.

local Store = {}
ns.NotesStore = Store
Store.__index = Store

Store.VERSION = 1
Store.ROLES = { "TANK", "HEALER", "DAMAGER" }
Store.MAX_STARS = 5

local DAY = 24 * 60 * 60

-- Wraps the saved table `db` (created when nil) and fills in missing parts.
function Store.New(db, options)
	db = db or {}
	db.version = db.version or Store.VERSION
	db.players = db.players or {}
	db.items = db.items or {}
	db.notes = db.notes or {}
	options = options or {}
	return setmetatable({ db = db, rejoinGrace = options.rejoinGrace or 0 }, Store)
end

-- Players ------------------------------------------------------------------

function Store:Player(name)
	return self.db.players[name]
end

-- The player's entry, created when missing. `class` (a class file name such
-- as "PRIEST") is kept from the latest call that knows it.
function Store:Ensure(name, class, now)
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
	local player = self.db.players[name]
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
	player.note = Trimmed(text)
	return player
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

-- Deletes the players last seen more than `days` ago that have neither a
-- rated session nor a note (nor an open session). Returns how many.
function Store:Prune(now, days)
	local cutoff = now - days * DAY
	local removed = 0
	for name, player in pairs(self.db.players) do
		local keep = player.note or Store.HasRating(player) or OpenSession(player) or (player.lastSeen or 0) >= cutoff
		if not keep then
			self.db.players[name] = nil
			removed = removed + 1
		end
	end
	return removed
end

local function Matches(player, filter)
	if not filter or filter == "" then
		return true
	end
	filter = filter:lower()
	return player.name:lower():find(filter, 1, true) or (player.note and player.note:lower():find(filter, 1, true))
end

-- Players matching `filter` (part of the name or note), sorted by `sortBy`:
-- "name", "rating" (best first, unrated last) or "recent" (the default).
function Store:Players(filter, sortBy)
	local list, ratings = {}, {}
	for _, player in pairs(self.db.players) do
		if Matches(player, filter) then
			list[#list + 1] = player
			local overall = Store.Summary(player).overall
			ratings[player] = overall and overall.average or -1
		end
	end
	table.sort(list, function(a, b)
		if sortBy == "rating" and ratings[a] ~= ratings[b] then
			return ratings[a] > ratings[b]
		elseif sortBy ~= "name" and sortBy ~= "rating" and a.lastSeen ~= b.lastSeen then
			return (a.lastSeen or 0) > (b.lastSeen or 0)
		end
		return a.name < b.name
	end)
	return list
end

-- "4.3": an average with one decimal.
function Store.FormatAverage(average)
	return ("%.1f"):format(math.floor(average * 10 + 0.5) / 10)
end

-- Items --------------------------------------------------------------------

function Store:ItemNote(itemID)
	local item = self.db.items[itemID]
	return item and item.text
end

-- Sets the note of an item type; empty text removes it.
function Store:SetItemNote(itemID, text, now)
	text = Trimmed(text)
	if text then
		self.db.items[itemID] = { text = text, changed = now }
	else
		self.db.items[itemID] = nil
	end
end

-- Item IDs with a note, the most recently changed first.
function Store:ItemIDs()
	local ids = {}
	for id in pairs(self.db.items) do
		ids[#ids + 1] = id
	end
	table.sort(ids, function(a, b)
		local ca, cb = self.db.items[a].changed or 0, self.db.items[b].changed or 0
		if ca ~= cb then
			return ca > cb
		end
		return a < b
	end)
	return ids
end

-- General notes ------------------------------------------------------------

function Store:AddNote(now)
	local note = { text = "", created = now, changed = now }
	table.insert(self.db.notes, note)
	return note
end

function Store.SetNoteText(note, text, now)
	note.text, note.changed = text or "", now
end

function Store:RemoveNote(note)
	for index, candidate in ipairs(self.db.notes) do
		if candidate == note then
			table.remove(self.db.notes, index)
			return true
		end
	end
	return false
end

-- General notes matching `filter`, the most recently changed first.
function Store:Notes(filter)
	local list = {}
	filter = filter and filter:lower() or ""
	for _, note in ipairs(self.db.notes) do
		if filter == "" or note.text:lower():find(filter, 1, true) then
			list[#list + 1] = note
		end
	end
	table.sort(list, function(a, b)
		return (a.changed or 0) > (b.changed or 0)
	end)
	return list
end

-- The first non-empty line of a text, for lists.
function Store.Title(text)
	return (text or ""):match("^%s*([^\n]-)%s*\n") or (text or ""):match("^%s*(.-)%s*$")
end
