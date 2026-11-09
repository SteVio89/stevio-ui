local _, ns = ...

-- Game-independent part of the loot ticker: turning loot messages and loot
-- history drops into entries, the capped list of entries and their fading
-- over time.
local Feed = {}
ns.LootFeed = Feed
Feed.__index = Feed

-- Escapes the pattern characters of a format string and turns its positional
-- specifiers (%1$s, which some locales use) of the `conversions` pattern class
-- ("[sd]" or "d") into plain ones.
local function EscapeFormat(format, conversions)
	local pattern = format:gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0")
	return (pattern:gsub("%%%d+%%%$(" .. conversions .. ")", "%%%1"))
end

-- Turns a format string such as LOOT_ITEM_SELF_MULTIPLE ("You receive loot:
-- %sx%d.") into an anchored Lua pattern; positional specifiers (%1$s) are
-- understood because some locales use them.
function Feed.PatternFromFormat(format)
	local pattern = EscapeFormat(format, "[sd]")
	pattern = pattern:gsub("%%s", "(.+)")
	pattern = pattern:gsub("%%d", "(%%d+)")
	return "^" .. pattern .. "$"
end

-- Builds the pattern list from format strings; nil formats (strings this
-- client does not have) are skipped. Formats with a count must come before
-- their single variant, because "(.+)" would also swallow the count.
function Feed.Patterns(...)
	local patterns = {}
	for i = 1, select("#", ...) do
		local format = select(i, ...)
		if format then
			patterns[#patterns + 1] = Feed.PatternFromFormat(format)
		end
	end
	return patterns
end

-- Sorts the captures of a match: the one holding a link, a number, and any
-- other (a player name).
local function SortCaptures(captures)
	local link, number, name
	for _, capture in ipairs(captures) do
		if capture:find("|H", 1, true) then
			link = capture
		elseif capture:match("^%d+$") then
			number = tonumber(capture)
		else
			name = capture
		end
	end
	return link, number, name
end

-- Returns link, count and player name (nil for own loot) of a loot message
-- matching one of `patterns`, plus the index of the matching pattern.
function Feed.Parse(text, patterns)
	for index, pattern in ipairs(patterns) do
		local captures = { text:match(pattern) }
		if captures[1] then
			local link, count, name = SortCaptures(captures)
			if link then
				return link, count or 1, name, index
			end
		end
	end
end

-- Item quality from the color of a link ("ffa335ee"), using `qualityHex`
-- ({ [quality] = "ffa335ee" }); nil when no quality has that color.
function Feed.QualityFromColor(hex, qualityHex)
	if not hex then
		return nil
	end
	hex = hex:lower()
	for quality, qualityColor in pairs(qualityHex) do
		if qualityColor:lower() == hex then
			return quality
		end
	end
end

-- Patterns for the coin amounts in a money message, from format strings such
-- as GOLD_AMOUNT ("%d Gold"). Digits may carry thousands separators.
function Feed.MoneyPatterns(goldFormat, silverFormat, copperFormat)
	local patterns = {}
	for i, format in ipairs({ goldFormat, silverFormat, copperFormat }) do
		local pattern = EscapeFormat(format, "d")
		pattern = pattern:gsub("%%d", "(%%d[%%d.,]*)")
		patterns[i] = pattern
	end
	return patterns
end

-- Copper amount of a money message such as "You loot 1 Gold, 2 Silver", or
-- nil if it names no coins. Anything in parentheses (e.g. the part deposited
-- to the guild bank) is not counted.
function Feed.ParseMoney(text, patterns)
	text = text:gsub("%b()", "")
	local copper, found = 0, false
	for i, factor in ipairs({ 10000, 100, 1 }) do
		local amount = text:match(patterns[i])
		if amount then
			copper = copper + tonumber((amount:gsub("%D", ""))) * factor
			found = true
		end
	end
	if found and copper > 0 then
		return copper
	end
end

function Feed.LinkName(link)
	return link:match("|h%[(.-)%]|h") or link:match("|h(.-)|h") or link
end

-- Color of the link text as "ffrrggbb", for when the quality is unknown.
function Feed.LinkColor(link)
	return link:match("|c(%x%x%x%x%x%x%x%x)")
end

-- Red, green and blue (0 to 1) of a color as "ffrrggbb".
function Feed.HexToRGB(hex)
	return tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, tonumber(hex:sub(7, 8), 16) / 255
end

-- Opacity of an entry `age` seconds old, or nil once it has faded out. It
-- stays for `holdTime` (default options.holdTime) after fading in.
function Feed.Alpha(age, options, holdTime)
	if age < options.fadeInTime then
		return age / options.fadeInTime
	end
	age = age - options.fadeInTime - (holdTime or options.holdTime)
	if age <= 0 then
		return 1
	end
	if age >= options.fadeOutTime then
		return nil
	end
	return 1 - age / options.fadeOutTime
end

-- Opacity of an entry at `now`: lines about other players (`other`) stay
-- only groupHoldTime; an open roll (`pendingUntil`) stays fully visible until
-- then and fades as if it had just faded in once that time is reached.
function Feed.EntryAlpha(entry, now, options)
	local age = now - entry.time
	if entry.pendingUntil then
		if now < entry.pendingUntil then
			return math.min(age / options.fadeInTime, 1)
		end
		age = options.fadeInTime + now - entry.pendingUntil
	end
	return Feed.Alpha(age, options, entry.other and options.groupHoldTime or nil)
end

-- Moves `current` towards `target`, covering one row height in `slideTime`.
function Feed.Slide(current, target, elapsed, rowHeight, slideTime)
	local step = rowHeight / slideTime * elapsed
	if math.abs(target - current) <= step then
		return target
	end
	return current + (target > current and step or -step)
end

function Feed.New(maxEntries)
	return setmetatable({ entries = {}, maxEntries = maxEntries }, Feed)
end

-- entries[1] is the newest. Adding to a full feed drops the oldest entry.
-- With `merge`, an entry with the same `key` (an item looted by the same
-- player, all money) is replaced and its count added. An entry with
-- `replace` (a roll on one drop) always takes the place of the one with its
-- key, keeping its row, so a roll stays one line while it changes.
function Feed:Add(entry, now, merge)
	entry.time = now
	if (merge or entry.replace) and entry.key then
		for i, old in ipairs(self.entries) do
			if old.key == entry.key then
				entry.y = old.y
				if entry.replace then
					self.entries[i] = entry
					return entry
				end
				table.remove(self.entries, i)
				entry.count = entry.count + old.count
				break
			end
		end
	end
	table.insert(self.entries, 1, entry)
	while #self.entries > self.maxEntries do
		table.remove(self.entries)
	end
	return entry
end

-- The entry with `key`, or nil.
function Feed:Find(key)
	for _, entry in ipairs(self.entries) do
		if entry.key == key then
			return entry
		end
	end
end

-- Drops entries that have faded out and returns how many are left.
function Feed:Expire(now, options)
	for i = #self.entries, 1, -1 do
		if not Feed.EntryAlpha(self.entries[i], now, options) then
			table.remove(self.entries, i)
		end
	end
	return #self.entries
end

-- A player name without its realm ("Bob-Realm" -> "Bob").
function Feed.ShortName(name)
	return name and (name:match("^([^-]+)-") or name)
end

-- Roll states of C_LootHistory (Enum.EncounterLootDropRollState).
Feed.RollState = { NeedMainSpec = 0, NeedOffSpec = 1, Transmog = 2, Greed = 3, NoRoll = 4, Pass = 5 }

local function RollOf(info)
	return {
		name = Feed.ShortName(info.playerName),
		class = info.playerClass,
		isSelf = info.isSelf,
		state = info.state,
		roll = info.roll,
	}
end

-- The parts of a loot history drop (C_LootHistory.GetSortedInfoForDrop) the
-- ticker shows: whether the roll is still open, all passed, the winner and the
-- player's own choice (`mine`, nil when they haven't chosen yet), each as
-- { name, class, isSelf, state, roll }.
function Feed.RollSummary(drop)
	local summary = { allPassed = drop.allPassed and true or false }
	if drop.winner then
		summary.winner = RollOf(drop.winner)
	end
	for _, info in ipairs(drop.rollInfos or {}) do
		if info.isSelf then
			summary.mine = RollOf(info)
		end
	end
	if not summary.mine and drop.playerRollState and drop.playerRollState ~= Feed.RollState.NoRoll then
		summary.mine = { isSelf = true, state = drop.playerRollState }
	end
	if summary.mine and summary.mine.state == Feed.RollState.NoRoll then
		summary.mine = nil
	end
	summary.pending = not summary.winner and not summary.allPassed
	return summary
end

-- Whether a roll entry was won by `looter` (nil: the player) for an item
-- named like `link`.
local function WonBy(entry, link, looter)
	local winner = entry.winner
	if not entry.roll or not winner or Feed.LinkName(entry.link) ~= Feed.LinkName(link) then
		return false
	end
	if looter then
		return not winner.isSelf and winner.name == Feed.ShortName(looter)
	end
	return winner.isSelf
end

-- The roll entry a loot message ("Bob receives loot: [Item]") belongs to:
-- that item won by that player and not claimed by an earlier message.
function Feed:RollFor(link, looter)
	for _, entry in ipairs(self.entries) do
		if not entry.received and WonBy(entry, link, looter) then
			return entry
		end
	end
end

-- Removes the single item `link` looted by `looter` (nil: the player) within
-- `window` seconds before `now`, for when the loot message came before the
-- roll was decided. Returns whether one was removed.
function Feed:TakeLoot(link, looter, now, window)
	local name, short = Feed.LinkName(link), Feed.ShortName(looter)
	for i, entry in ipairs(self.entries) do
		if
			not entry.roll
			and not entry.money
			and entry.count == 1
			and now - entry.time <= window
			and Feed.ShortName(entry.looter) == short
			and Feed.LinkName(entry.link) == name
		then
			table.remove(self.entries, i)
			return true
		end
	end
	return false
end
