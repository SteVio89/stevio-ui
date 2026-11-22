local _, ns = ...

-- Game-independent part of the roll cards and the roll history: reading loot
-- history drops, ordering rolls and cards, card fading, history records and
-- the rows of the history window.
local Logic = {}
ns.RollLogic = Logic

-- Roll states of C_LootHistory (Enum.EncounterLootDropRollState).
Logic.State = { NeedMainSpec = 0, NeedOffSpec = 1, Transmog = 2, Greed = 3, NoRoll = 4, Pass = 5 }
local State = Logic.State

-- RollOnLoot's roll types, by the state they lead to.
Logic.RollType = { Pass = 0, Need = 1, Greed = 2, Transmog = 4 }

-- The loot history state a click on RollOnLoot type `rollType` stands for,
-- shown on the card until the loot history has the real one.
function Logic.StateOfRollType(rollType)
	local states = { [0] = State.Pass, [1] = State.NeedMainSpec, [2] = State.Greed, [4] = State.Transmog }
	return states[rollType]
end

-- The RollOnLoot type that leads to loot history state `state`.
function Logic.RollTypeOfState(state)
	local types = {
		[State.NeedMainSpec] = 1,
		[State.NeedOffSpec] = 1,
		[State.Greed] = 2,
		[State.Transmog] = 4,
		[State.Pass] = 0,
	}
	return types[state]
end

-- A player name without its realm ("Bob-Realm" -> "Bob").
function Logic.ShortName(name)
	return name and (name:match("^([^-]+)-") or name)
end

-- The item ID of an item link, to match a roll with its loot history drop.
function Logic.ItemID(link)
	return link and tonumber(link:match("|Hitem:(%d+)"))
end

local function RollOf(info)
	return {
		name = Logic.ShortName(info.playerName),
		class = info.playerClass,
		isSelf = info.isSelf and true or false,
		state = info.state,
		roll = info.roll,
	}
end

-- Rolls that count, best first: numbers high to low, then choices without a
-- number yet, passes last.
local function Before(a, b)
	local aPass, bPass = a.state == State.Pass, b.state == State.Pass
	if aPass ~= bPass then
		return bPass
	end
	if (a.roll ~= nil) ~= (b.roll ~= nil) then
		return a.roll ~= nil
	end
	if a.roll and a.roll ~= b.roll then
		return a.roll > b.roll
	end
	if a.state ~= b.state then
		return a.state < b.state
	end
	return (a.name or "") < (b.name or "")
end

function Logic.SortRolls(rolls)
	table.sort(rolls, Before)
	return rolls
end

-- The parts of a loot history drop (C_LootHistory.GetSortedInfoForDrop) the
-- cards and the history show: every choice made (`rolls`, best first, the
-- winner on top), the winner, the player's own choice (`mine`, nil before
-- they chose), whether all passed and whether the roll is still open.
function Logic.Summary(drop)
	local summary = { link = drop.itemHyperlink, allPassed = drop.allPassed and true or false, rolls = {} }
	if drop.winner then
		summary.winner = RollOf(drop.winner)
	end
	for _, info in ipairs(drop.rollInfos or {}) do
		if info.state ~= State.NoRoll then
			local roll = RollOf(info)
			summary.rolls[#summary.rolls + 1] = roll
			if roll.isSelf then
				summary.mine = roll
			end
		end
	end
	Logic.SortRolls(summary.rolls)
	local winner = summary.winner
	if winner then
		for i, roll in ipairs(summary.rolls) do
			if roll.name == winner.name and i > 1 then
				table.remove(summary.rolls, i)
				table.insert(summary.rolls, 1, roll)
				break
			end
		end
	end
	if not summary.mine and drop.playerRollState and drop.playerRollState ~= State.NoRoll then
		summary.mine = { isSelf = true, state = drop.playerRollState }
	end
	summary.pending = not winner and not summary.allPassed
	return summary
end

-- The `count` best rolls of other players, plus the player's own where it
-- ranks (or last, while it has no number yet).
function Logic.TopRolls(summary, count)
	local top, others, haveMine = {}, 0, false
	for _, roll in ipairs(summary.rolls) do
		if roll.isSelf then
			top[#top + 1] = roll
			haveMine = true
		elseif others < count then
			top[#top + 1] = roll
			others = others + 1
		end
	end
	if not haveMine and summary.mine then
		top[#top + 1] = summary.mine
	end
	return top
end

-- "Need 87", or just "Need" before the number is rolled; `labels` names the
-- roll states.
function Logic.RollText(roll, labels)
	local text = labels[roll.state] or ""
	if roll.roll then
		text = text .. " " .. roll.roll
	end
	return text
end

-- One roll with its player: "Bob Need 98", "you Greed 45". `L.you` names the
-- player, `classColored(name, class)` colors other names.
function Logic.RollEntry(roll, L, labels, classColored)
	local name = roll.isSelf and L.you or classColored(roll.name or "?", roll.class)
	return name .. " |cffaaaaaa" .. Logic.RollText(roll, labels) .. "|r"
end

-- The line of a compact card listing the rolls: "Bob Need 98 · Ann Greed 71".
function Logic.RollsLine(rolls, L, labels, classColored)
	local parts = {}
	for i, roll in ipairs(rolls) do
		parts[i] = Logic.RollEntry(roll, L, labels, classColored)
	end
	return table.concat(parts, " · ")
end

-- The result of a roll: "Bob wins", "You win" (green), "All passed", or
-- "rolling…" while it is open.
function Logic.ResultText(summary, L, classColored)
	if not summary then
		return "|cffaaaaaa" .. L.rolling .. "|r"
	end
	if summary.allPassed then
		return "|cffaaaaaa" .. L.allPassed .. "|r"
	end
	local winner = summary.winner
	if not winner then
		return "|cffaaaaaa" .. L.rolling .. "|r"
	end
	if winner.isSelf then
		return "|cff40ff40" .. L.youWin .. "|r"
	end
	return L.wins:format(classColored(winner.name or "?", winner.class))
end

-- The open card without a drop yet that a loot history drop of `link`
-- belongs to: same item, the one that started first.
function Logic.MatchCard(cards, link)
	local itemID = Logic.ItemID(link)
	local match
	for _, card in ipairs(cards) do
		if not card.dropKey and not card.preview and card.link then
			local same = card.link == link or (itemID and Logic.ItemID(card.link) == itemID)
			if same and (not match or card.started < match.started) then
				match = card
			end
		end
	end
	return match
end

-- Cards top to bottom: rolls still to answer first, then the answered ones,
-- each in the order they started.
function Logic.SortCards(cards)
	table.sort(cards, function(a, b)
		local aOpen, bOpen = a.choice == nil, b.choice == nil
		if aOpen ~= bOpen then
			return aOpen
		end
		if a.started ~= b.started then
			return a.started < b.started
		end
		return (a.rollID or 0) < (b.rollID or 0)
	end)
	return cards
end

-- Opacity of a card at `now`: fully shown until `fadeAt` (unset while the
-- roll goes on), then fading out over options.fadeOutTime; nil once gone.
function Logic.CardAlpha(card, now, options)
	if not card.fadeAt or now <= card.fadeAt then
		return 1
	end
	local age = now - card.fadeAt
	if age >= options.fadeOutTime then
		return nil
	end
	return 1 - age / options.fadeOutTime
end

-- Seconds left of a roll that started at `started` and lasts `duration`.
function Logic.TimeLeft(card, now)
	return math.max(0, card.started + card.duration - now)
end

-- History ------------------------------------------------------------------

-- A saved history entry for a decided drop: the encounter it belongs to
-- (`fight`: encounterID and when the fight started, as seconds since the
-- epoch, which groups the drops under one header), the item, the winner and
-- every choice.
function Logic.Record(summary, fight, lootListKey, now)
	local mine = summary.mine
	return {
		encounterID = fight.encounterID,
		encounter = fight.name,
		instance = fight.instance,
		fightTime = fight.time,
		lootListKey = lootListKey,
		time = now,
		link = summary.link,
		allPassed = summary.allPassed or nil,
		winner = summary.winner,
		rolls = summary.rolls,
		mine = (mine and mine.state ~= State.Pass) or (summary.winner and summary.winner.isSelf) or nil,
	}
end

-- The index of the saved record of this drop, looking back over the newest
-- records only (the loot history repeats drops after a reload). Fight times
-- may differ by a second or two, since they are worked out from the
-- client's clock.
function Logic.FindRecord(records, encounterID, lootListKey, fightTime)
	for i = #records, math.max(1, #records - 200), -1 do
		local record = records[i]
		if
			record.encounterID == encounterID
			and record.lootListKey == lootListKey
			and math.abs((record.fightTime or 0) - fightTime) <= 5
		then
			return i
		end
	end
end

-- Adds a record, or replaces the one of the same drop. Returns its index.
function Logic.SaveRecord(records, record)
	local index = Logic.FindRecord(records, record.encounterID, record.lootListKey, record.fightTime)
	if index then
		records[index] = record
		return index
	end
	records[#records + 1] = record
	return #records
end

local function Contains(text, search)
	return text and text:lower():find(search, 1, true) ~= nil
end

-- Whether a record is listed: with `mineOnly` only drops the player rolled
-- on or won; `search` (lower case) matches the item, the boss or a player.
function Logic.Matches(record, search, mineOnly, linkName)
	if mineOnly and not record.mine then
		return false
	end
	if not search or search == "" then
		return true
	end
	if Contains(linkName(record.link), search) or Contains(record.encounter, search) then
		return true
	end
	for _, roll in ipairs(record.rolls or {}) do
		if Contains(roll.name, search) then
			return true
		end
	end
	return false
end

local function GroupKey(record)
	return ("%s:%s"):format(tostring(record.encounterID), tostring(record.fightTime))
end

-- The rows of the history window, newest first: a header per fight, a row
-- per drop, and under an expanded drop (`expanded[record]`) a row per roll.
-- Records are saved oldest first.
function Logic.HistoryRows(records, filter, expanded, linkName)
	local rows, lastGroup = {}, nil
	for i = #records, 1, -1 do
		local record = records[i]
		if Logic.Matches(record, filter.search, filter.mineOnly, linkName) then
			local group = GroupKey(record)
			if group ~= lastGroup then
				rows[#rows + 1] = { kind = "header", record = record }
				lastGroup = group
			end
			rows[#rows + 1] = { kind = "drop", record = record }
			if expanded[record] then
				for _, roll in ipairs(record.rolls or {}) do
					rows[#rows + 1] = { kind = "roll", record = record, roll = roll }
				end
			end
		end
	end
	return rows
end

-- "Fyrakk · Amirdrassil · 22.11. 21:40"; `formatDate(time)` gives the date.
function Logic.HeaderText(record, formatDate, unknown)
	local hasName = record.encounter and record.encounter ~= ""
	local parts = { hasName and record.encounter or unknown }
	if record.instance and record.instance ~= "" and record.instance ~= record.encounter then
		parts[#parts + 1] = record.instance
	end
	parts[#parts + 1] = formatDate(record.fightTime or record.time)
	return table.concat(parts, " · ")
end
