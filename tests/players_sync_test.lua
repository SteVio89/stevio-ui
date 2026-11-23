-- Run with: lua tests/players_sync_test.lua  (from the repo root)
-- Modules/Players/Players.lua against a fake group: sessions open and close
-- with the roster, the popup after leaving, sessions left open at logout,
-- bosses, the roll history's loot and players moved over from the notes.
local check, loadAddonFile = dofile("tests/helpers.lua")

local now = 1000
local party, inGroup = {}, false
local zone = "Westfall"
_G.time = function()
	return now
end
_G.issecretvalue = function()
	return false
end
_G.Ambiguate = function(name)
	return name
end
_G.GetNormalizedRealmName = function()
	return "Home"
end
_G.UNKNOWNOBJECT = "Unknown"
_G.IsInGroup = function()
	return inGroup
end
_G.IsInRaid = function()
	return false
end
_G.GetNumSubgroupMembers = function()
	return #party
end
local function Member(unit)
	return party[tonumber(unit:match("^party(%d+)$") or 0)]
end
_G.UnitExists = function(unit)
	return unit == "player" or Member(unit) ~= nil
end
_G.UnitName = function(unit)
	if unit == "player" then
		return "Me"
	end
	local member = Member(unit)
	if member then
		return member.name, member.realm
	end
end
_G.UnitIsPlayer = function(unit)
	return UnitExists(unit)
end
_G.UnitClass = function()
	return "Priest", "PRIEST"
end
_G.UnitGroupRolesAssigned = function(unit)
	local member = Member(unit)
	return member and member.role or "NONE"
end
_G.GetGuildInfo = function() end
_G.GetInstanceInfo = function()
	return zone, "none"
end
_G.GetRealZoneText = function()
	return zone
end
_G.hooksecurefunc = function() end
_G.TooltipDataProcessor = { AddTooltipPostCall = function() end }
_G.Enum = { TooltipDataType = { Unit = 2 } }

local handlers, module = {}, nil
local popups, printed = {}, {}
local ns = {
	config = {},
	T = function(english)
		return english
	end,
	RegisterModule = function(name, table)
		table.name = name
		module = table
		return table
	end,
	RegisterModuleCommand = function() end,
	RegisterEvent = function(event, handler)
		handlers[event] = handler
	end,
	Print = function(text)
		printed[#printed + 1] = text
	end,
	PlayersPopup = {
		Show = function(entries)
			popups[#popups + 1] = entries
		end,
	},
	PlayersWindow = { Refresh = function() end },
	NotesWidgets = {
		ClassColored = function(name)
			return name
		end,
	},
	PlayerWidgets = {
		SummaryText = function() end,
		BlockReason = function() end,
		VerdictText = function(player)
			return player.verdict
		end,
	},
}
loadAddonFile("Modules/Players/Config.lua", ns)
loadAddonFile("Modules/Players/Store.lua", ns)
loadAddonFile("Modules/Rolls/Logic.lua", ns)
loadAddonFile("Modules/Players/Players.lua", ns)

local function Fire(event, ...)
	handlers[event](event, ...)
end

-- Logging in solo with nothing saved.
_G.StevioUIPlayers = nil
module:OnEnable()
module.active = true
local store = module.store
check(#store:OpenNames() == 0, "nothing open")

-- Bob joins: a session with his role.
inGroup, party = true, { { name = "Bob", role = "HEALER" } }
now = 1100
Fire("GROUP_ROSTER_UPDATE")
local bob = store:Player("Bob")
check(bob and bob.sessions[1].open and bob.sessions[1].role == "HEALER", "session opened with the role")

-- A member whose name isn't known yet keeps everyone's sessions.
party = { { name = nil } }
now = 1200
Fire("GROUP_ROSTER_UPDATE")
check(bob.sessions[1].open, "unknown roster keeps sessions")

-- Leaving the group: Bob's session ends and the popup offers to rate him.
inGroup, party = false, {}
now = 1300
Fire("GROUP_ROSTER_UPDATE")
check(not bob.sessions[1].open and bob.sessions[1].stop == 1300, "session closed on leaving")
check(#popups == 1 and popups[1][1].name == "Bob", "popup after leaving")
print("roster ok")

-- #86: a player you avoid joins: a red line, also without rating or note.
bob.verdict = "avoid"
printed = {}
inGroup, party = true, { { name = "Bob", role = "HEALER" } }
now = 1900
Fire("GROUP_ROSTER_UPDATE")
check(#printed == 1 and printed[1]:find("^|cffff5050In your group: Bob") and printed[1]:find("avoid"), "red line")
bob.verdict = "like"
inGroup, party, popups = false, {}, {}
now = 1950
Fire("GROUP_ROSTER_UPDATE")
inGroup, party = true, { { name = "Bob", role = "HEALER" } }
now = 1950 + 400 -- after the rejoin grace: a new session
printed = {}
Fire("GROUP_ROSTER_UPDATE")
check(#printed == 1 and not printed[1]:find("|cffff5050", 1, true), "plain line for a liked player")
inGroup, party, popups = false, {}, {}
now = 1950 + 500
Fire("GROUP_ROSTER_UPDATE")
bob.verdict = nil
popups = {}
print("verdict ok")

-- Logging out in a group, back a day later alone: the session ends at the
-- logout, so the day offline isn't counted.
inGroup, party = true, { { name = "Ann", role = "TANK" } }
now = 2000
Fire("GROUP_ROSTER_UPDATE")
now = 2600
Fire("PLAYER_LOGOUT")
local saved = store.db
check(saved.loggedOut == 2600, "logout time saved")

inGroup, party, popups = false, {}, {}
now = 2600 + 86400
_G.StevioUIPlayers = saved
module:OnEnable()
store = module.store
local ann = store:Player("Ann")
check(not ann.sessions[1].open and ann.sessions[1].stop == 2600, "ended at the logout")
check(ann.lastSeen == 2600, "last seen at the logout")
check(ann.sessions[1].zones.Westfall == 600, "only the time before the logout counts")
check(store.db.loggedOut == nil, "logout time used once")
check(#popups == 1 and popups[1][1].name == "Ann", "popup for the group left by logging out")
print("logout ok")

-- A /reload in the same group continues the session.
inGroup, party, popups = true, { { name = "Cid", role = "DAMAGER" } }, {}
now = 100000
Fire("GROUP_ROSTER_UPDATE")
now = 100060
Fire("PLAYER_LOGOUT")
now = 100070
_G.StevioUIPlayers = store.db
module:OnEnable()
store = module.store
local cid = store:Player("Cid")
check(#cid.sessions == 1 and cid.sessions[1].open, "reload continues the session")
check(#popups == 0, "no popup after a reload in the group")
print("reload ok")

-- A boss kill and a wipe go into Cid's open session.
Fire("ENCOUNTER_END", 663, "Lucifron", 9, 40, 1)
Fire("ENCOUNTER_END", 664, "Magmadar", 9, 40, 0)
check(cid.sessions[1].kills[1] == "Lucifron" and cid.sessions[1].wipes == 1, "kill and wipe recorded")
print("bosses ok")

-- A decided roll: everyone's choice is counted, the winner gets the item,
-- your own roll is left out.
local State = ns.RollLogic.State
ns.PlayersRecordLoot({
	link = "[Choker of Enlightenment]",
	encounter = "Lucifron",
	instance = "Molten Core",
	time = 100100,
	winner = { name = "Cid", fullName = "Cid", class = "PRIEST", state = State.NeedMainSpec, roll = 98 },
	rolls = {
		{ name = "Cid", fullName = "Cid", class = "PRIEST", state = State.NeedMainSpec, roll = 98 },
		{ name = "Dan", fullName = "Dan-Firemaw", class = "MAGE", state = State.Greed, roll = 40 },
		{ name = "You", isSelf = true, state = State.Pass },
	},
})
check(cid.rolls.need == 1 and #cid.wins == 1, "winner's roll and win")
check(cid.wins[1].link == "[Choker of Enlightenment]" and cid.wins[1].encounter == "Lucifron", "win recorded")
check(cid.wins[1].choice == "need", "won with Need")
local dan = store:Player("Dan-Firemaw")
check(dan and dan.rolls.greed == 1 and dan.class == "MAGE" and dan.wins == nil, "other roller under the full name")
check(store:Player("You") == nil, "own roll left out")
print("loot ok")

-- #86: a player from another realm grouped (UnitName gives the realm apart)
-- and then named by the loot history with a space: one entry.
inGroup, party = true, { { name = "Lina", realm = "Sakuranbo", role = "HEALER" } }
now = 100200
Fire("GROUP_ROSTER_UPDATE")
local lina = store:Player("Lina-Sakuranbo")
check(lina and lina.sessions[1].open, "grouped under Name-Realm")
ns.PlayersRecordLoot({
	link = "[Robe]",
	time = 100300,
	winner = { name = "Lina", fullName = "Lina Sakuranbo", class = "DRUID", state = State.Greed },
	rolls = { { name = "Lina", fullName = "Lina Sakuranbo", class = "DRUID", state = State.Greed } },
})
check(store.db.players["Lina Sakuranbo"] == nil, "no second entry with a space")
check(lina.rolls.greed == 1 and #lina.wins == 1, "loot on the grouped entry")
-- Players of your own realm are stored without it.
ns.PlayersRecordLoot({ link = "[Ring]", time = 100400, winner = { name = "Cid", fullName = "Cid-Home" } })
check(#cid.wins == 2 and store.db.players["Cid-Home"] == nil, "own realm left out")
inGroup, party = false, {}
Fire("GROUP_ROSTER_UPDATE")
print("names ok")

-- Players saved in the notes before #74 move over once.
_G.StevioUINotes = {
	items = {},
	players = { Eve = { name = "Eve", sessions = {} }, Cid = { name = "Cid", sessions = {} } },
	loggedOut = 5,
}
_G.StevioUIPlayers = store.db
module:OnEnable()
store = module.store
check(store:Player("Eve") and store:Player("Cid") == cid, "moved over, existing entries win")
check(StevioUINotes.players == nil and StevioUINotes.loggedOut == nil and StevioUINotes.items, "notes keep the rest")
-- Into a new table, with the logout time for their open sessions.
_G.StevioUINotes = {
	players = { Fay = { name = "Fay", sessions = { { start = 10, open = true, zones = {}, instances = {} } } } },
	loggedOut = 50,
}
_G.StevioUIPlayers = nil
module:OnEnable()
local fay = module.store:Player("Fay")
check(fay and not fay.sessions[1].open and fay.sessions[1].stop == 50, "open session ended at the old logout")
print("take over ok")

-- #86: wins saved by version 1 get their choice from the roll history.
_G.StevioUINotes = nil
_G.StevioUIRollHistory = {
	records = {
		{ link = "[Old]", time = 70, winner = { name = "Gus", fullName = "Gus Faraway", state = State.Transmog } },
		{ link = "[Mine]", time = 80, winner = { name = "Me", isSelf = true, state = State.Greed } },
	},
}
_G.StevioUIPlayers = {
	version = 1,
	players = {
		["Gus-Faraway"] = { name = "Gus-Faraway", sessions = {}, wins = { { link = "[Old]", time = 70 } } },
		["Gus Faraway"] = { name = "Gus Faraway", sessions = {}, wins = { { link = "[Other]", time = 71 } } },
	},
}
module:OnEnable()
local gus = module.store:Player("Gus-Faraway")
check(StevioUIPlayers.version == 2 and #gus.wins == 2, "upgraded and merged")
check(gus.wins[1].choice == "transmog" and gus.wins[2].choice == nil, "choice from the roll history")
print("upgrade ok")

print("players sync tests passed")
