local _, ns = ...

-- Game-independent part of the loot ticker: turning loot messages into
-- entries, the capped list of entries and their fading over time.
local Feed = {}
ns.LootFeed = Feed
Feed.__index = Feed

-- Turns a format string such as LOOT_ITEM_SELF_MULTIPLE ("You receive loot:
-- %sx%d.") into an anchored Lua pattern; positional specifiers (%1$s) are
-- understood because some locales use them.
function Feed.PatternFromFormat(format)
	local pattern = format:gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0")
	pattern = pattern:gsub("%%%d+%%%$([sd])", "%%%1")
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

-- Returns the link and count of a loot message matching one of `patterns`.
function Feed.Parse(text, patterns)
	for _, pattern in ipairs(patterns) do
		local captures = { text:match(pattern) }
		if captures[1] then
			local link, count
			for _, capture in ipairs(captures) do
				if capture:find("|H", 1, true) then
					link = capture
				elseif capture:match("^%d+$") then
					count = tonumber(capture)
				end
			end
			if link then
				return link, count or 1
			end
		end
	end
end

-- Patterns for the coin amounts in a money message, from format strings such
-- as GOLD_AMOUNT ("%d Gold"). Digits may carry thousands separators.
function Feed.MoneyPatterns(goldFormat, silverFormat, copperFormat)
	local patterns = {}
	for i, format in ipairs({ goldFormat, silverFormat, copperFormat }) do
		local pattern = format:gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0")
		pattern = pattern:gsub("%%%d+%%%$d", "%%d")
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

-- Opacity of an entry `age` seconds old, or nil once it has faded out.
function Feed.Alpha(age, options)
	if age < options.fadeInTime then
		return age / options.fadeInTime
	end
	age = age - options.fadeInTime - options.holdTime
	if age <= 0 then
		return 1
	end
	if age >= options.fadeOutTime then
		return nil
	end
	return 1 - age / options.fadeOutTime
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
-- With `merge`, an entry for the same link is replaced and its count added.
function Feed:Add(entry, now, merge)
	entry.time = now
	if merge then
		for i, old in ipairs(self.entries) do
			if old.link == entry.link then
				table.remove(self.entries, i)
				entry.count = entry.count + old.count
				entry.y = old.y
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

-- Drops entries that have faded out and returns how many are left.
function Feed:Expire(now, options)
	for i = #self.entries, 1, -1 do
		if not Feed.Alpha(now - self.entries[i].time, options) then
			table.remove(self.entries, i)
		end
	end
	return #self.entries
end
