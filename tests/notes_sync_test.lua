-- Run with: lua tests/notes_sync_test.lua  (from the repo root)
-- Modules/Notes/Notes.lua against a fake group: sessions open and close with
-- the roster, the popup after leaving, and sessions left open at logout.
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
	return member and member.name
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
	NotesPopup = {
		Show = function(entries)
			popups[#popups + 1] = entries
		end,
	},
	NotesWidgets = {
		ClassColored = function(name)
			return name
		end,
		SummaryText = function() end,
		BlockReason = function() end,
	},
}
loadAddonFile("Modules/Notes/Config.lua", ns)
loadAddonFile("Modules/Notes/Store.lua", ns)
loadAddonFile("Modules/Notes/Notes.lua", ns)

local function Fire(event, ...)
	handlers[event](event, ...)
end

-- Logging in solo with nothing saved.
_G.StevioUINotes = nil
module:OnEnable()
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
_G.StevioUINotes = saved
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
_G.StevioUINotes = store.db
module:OnEnable()
store = module.store
local cid = store:Player("Cid")
check(#cid.sessions == 1 and cid.sessions[1].open, "reload continues the session")
check(#popups == 0, "no popup after a reload in the group")
print("reload ok")

print("notes sync tests passed")
