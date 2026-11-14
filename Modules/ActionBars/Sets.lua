local _, ns = ...

-- Action sets: named snapshots of every action slot (all bars, all pages,
-- stance and form pages included). Keybindings belong to the buttons, not to
-- the slots, so swapping what sits in the slots keeps every key working as before.
-- This file is the game-independent part: snapshot format, comparison and the
-- list of slot changes a switch needs. SetSwitcher.lua does the rest.

local Sets = {}
ns.ActionSets = Sets

-- 12 bars of 12 slots in Blizzard's numbering (1-120 classic pages and
-- bonus bars, 121-180 the extra bars of newer clients).
Sets.MAX_SLOT = 180

-- An entry is { type = "spell" | "item" | "macro" | ..., id = number|string, name = string? }.
-- Macros are kept by name as well: their index shifts when macros are added or removed.
function Sets.Same(a, b)
	if a == nil or b == nil then
		return a == b
	end
	if a.type ~= b.type then
		return false
	end
	if a.type == "macro" and a.name and b.name then
		return a.name == b.name
	end
	return a.id == b.id
end

-- The first action slot of each Edit Mode bar but the main bar, which pages
-- through several. Every bar has 12 slots.
Sets.BAR_FIRST_SLOT = {
	Bar2 = 61, -- bottom left
	Bar3 = 49, -- bottom right
	Bar4 = 25, -- right
	Bar5 = 37, -- right 2
	Bar6 = 145,
	Bar7 = 157,
	Bar8 = 169,
}

-- The slots of the named bars as a set ({ [slot] = true }); unknown names are skipped.
function Sets.BarSlots(bars)
	local slots = {}
	for _, bar in ipairs(bars or {}) do
		local first = Sets.BAR_FIRST_SLOT[bar]
		if first then
			for slot = first, first + 11 do
				slots[slot] = true
			end
		end
	end
	return slots
end

-- The slots whose content differs between `current` and `wanted`, ascending.
-- A slot missing from `wanted` is to be emptied. Slots in `keep` (a set as
-- returned by Sets.BarSlots) are left as they are.
function Sets.Changes(current, wanted, keep)
	keep = keep or {}
	local changes = {}
	for slot = 1, Sets.MAX_SLOT do
		if not keep[slot] and not Sets.Same(current[slot], wanted[slot]) then
			changes[#changes + 1] = { slot = slot, action = wanted[slot] }
		end
	end
	return changes
end

-- Index of the set after `current`, wrapping around.
function Sets.Next(current, count)
	if count < 1 then
		return nil
	end
	return (current or 0) % count + 1
end

-- Index of the set before `current`, wrapping around.
function Sets.Previous(current, count)
	if count < 1 then
		return nil
	end
	return (current - 2) % count + 1
end

-- Index of a set given by number or (case-insensitive) name, nil if unknown.
function Sets.Find(names, query)
	local number = tonumber(query)
	if number and names[number] then
		return number
	end
	query = tostring(query or ""):lower()
	for index, name in ipairs(names) do
		if name:lower() == query then
			return index
		end
	end
	return nil
end
