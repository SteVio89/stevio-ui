local _, ns = ...

-- Game-independent part of the loot ticker: turning loot messages into
-- entries, the capped list of entries and their fading over time.
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

-- Sorts the captures of a match: the one holding a link and the count.
local function SortCaptures(captures)
	local link, number
	for _, capture in ipairs(captures) do
		if capture:find("|H", 1, true) then
			link = capture
		elseif capture:match("^%d+$") then
			number = tonumber(capture)
		end
	end
	return link, number
end

-- Returns link and count of a loot message matching one of `patterns`, plus
-- the index of the matching pattern.
function Feed.Parse(text, patterns)
	for index, pattern in ipairs(patterns) do
		local captures = { text:match(pattern) }
		if captures[1] then
			local link, count = SortCaptures(captures)
			if link then
				return link, count or 1, index
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
-- stays for options.holdTime after fading in.
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

-- Opacity of an entry at `now`, or nil once it has faded out.
function Feed.EntryAlpha(entry, now, options)
	return Feed.Alpha(now - entry.time, options)
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
-- With `merge`, an entry with the same `key` (the same item, all money) is
-- replaced and its count added.
function Feed:Add(entry, now, merge)
	entry.time = now
	if merge and entry.key then
		for i, old in ipairs(self.entries) do
			if old.key == entry.key then
				entry.y = old.y
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

-- Drops entries that have faded out and returns how many are left.
function Feed:Expire(now, options)
	for i = #self.entries, 1, -1 do
		if not Feed.EntryAlpha(self.entries[i], now, options) then
			table.remove(self.entries, i)
		end
	end
	return #self.entries
end

-- Icon and quality of a currency from C_CurrencyInfo.GetCurrencyInfoFromLink
-- (nil for an unknown currency).
function Feed.CurrencyDisplay(info)
	if info then
		return info.iconFileID, info.quality
	end
end

-- The count of a loot line: "x3", or nothing for a single item.
function Feed.LootDetail(entry)
	if entry.count > 1 then
		return ("|cffffffffx%d|r"):format(entry.count)
	end
	return ""
end

-- Whether a loot line is shown: currency only with showCurrency, items of a
-- known quality from minQuality on.
function Feed.Passes(quality, isCurrency, options)
	if isCurrency then
		return options.showCurrency
	end
	return not quality or quality >= options.minQuality
end

-- Loot messages that arrived secret during the chat lockdown are kept as
-- { event, lineID } and read again once it is over: `read(lineID)` returns
-- the message text (nil or a secret value when it still can't be read) and
-- `handle(event, text)` takes each readable one. Lines that stay unreadable
-- are dropped, since the client won't keep them forever.
function Feed.ReadPending(pending, read, handle, isSecret)
	for _, line in ipairs(pending) do
		local text = read(line.lineID)
		if not isSecret(text) and type(text) == "string" then
			handle(line.event, text)
		end
	end
end
