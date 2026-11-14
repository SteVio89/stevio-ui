-- Run with: lua tests/notes_store_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")
local ns = loadAddonFile("Modules/Notes/Store.lua")
local Store = ns.NotesStore

local DAY = 24 * 60 * 60

-- New fills in a missing or partial saved table.
local store = Store.New(nil)
check(store.db.version == 1 and next(store.db.players) == nil, "fresh table")
local saved = { players = { Bob = { name = "Bob", sessions = {} } } }
store = Store.New(saved)
check(store.db == saved and store:Player("Bob") and store.db.items and store.db.notes, "existing table kept")
print("new ok")

-- Sessions: open, place, close.
store = Store.New(nil, { rejoinGrace = 300 })
local session, isNew = store:Open("Bob", { class = "PRIEST", role = "HEALER", place = "Westfall" }, 1000)
check(isNew and session.open and session.role == "HEALER", "new session with role")
check(store:Player("Bob").class == "PRIEST", "class kept")
local again, againNew = store:Open("Bob", { role = "TANK" }, 1010)
check(again == session and not againNew, "same session while still grouped")
check(session.role == "HEALER", "role is not overwritten")
check(#store:OpenNames() == 1 and store:OpenNames()[1] == "Bob", "open names")

store:Visit("Deadmines", true, 1100)
store:Visit("Westfall", false, 1900)
store:Visit("The Stockade", true, 2000)
store:Visit("Deadmines", true, 2100)
local closed = store:Close("Bob", 2500)
check(closed == session and not session.open and session.stop == 2500, "closed")
check(session.where == "Deadmines, The Stockade" and session.instance, "instances in order, once each")
check(session.at == nil and session.since == nil, "current place dropped")
check(store:Close("Bob", 2600) == nil, "nothing open to close")
check(#store:OpenNames() == 0, "no open names")

-- Without an instance, the zone with the most time wins.
store:Open("Ann", { place = "Elwynn Forest" }, 0)
store:Visit("Westfall", false, 100)
store:Visit("Elwynn Forest", false, 400)
store:Close("Ann", 450)
local ann = store:Player("Ann").sessions[1]
check(ann.where == "Westfall" and not ann.instance, "zone with most time")
check(ann.role == nil, "no role assigned")
store:Open("Cid", { role = "NONE" }, 0)
check(store:Player("Cid").sessions[1].role == nil, "NONE is no role")
check(store:Close("Cid", 10).where == nil, "unknown place")
print("sessions ok")

-- Rejoining within the grace time continues the session.
local bob = store:Player("Bob")
store:Open("Bob", { place = "Duskwood" }, 2700)
check(#bob.sessions == 1 and bob.sessions[1].open, "rejoin continues")
store:Close("Bob", 2800)
check(bob.sessions[1].where == "Deadmines, The Stockade", "earlier instances kept after rejoin")
store:Open("Bob", { place = "Duskwood" }, 2800 + 301)
check(#bob.sessions == 2, "after the grace time a new session")
store:Close("Bob", 4000)
print("rejoin ok")

-- Ratings and averages: unrated sessions don't count.
Store.Rate(bob.sessions[1], 5)
Store.Rate(bob.sessions[2], 2)
bob.sessions[2].role = "DAMAGER"
bob.sessions[3] = { start = 5000, stop = 6000, role = "HEALER" } -- unrated
bob.sessions[4] = { start = 7000, stop = 8000, role = "HEALER", stars = 4 }
local summary = Store.Summary(bob)
check(summary.overall.count == 3 and math.abs(summary.overall.average - 11 / 3) < 1e-9, "overall")
check(summary.HEALER.count == 2 and summary.HEALER.average == 4.5, "per role")
check(summary.DAMAGER.average == 2 and summary.TANK == nil, "other roles")
check(Store.Summary(store:Player("Ann")).overall == nil, "nothing rated")
Store.Rate(bob.sessions[4], nil)
check(bob.sessions[4].stars == nil, "rating cleared")
Store.Rate(bob.sessions[4], 9)
check(bob.sessions[4].stars == 5, "clamped to 5")
Store.Rate(bob.sessions[4], 0)
check(bob.sessions[4].stars == 1, "clamped to 1")
check(Store.FormatAverage(11 / 3) == "3.7" and Store.FormatAverage(4) == "4.0", "format")
check(Store.FormatAverage(4.25) == "4.3", "rounds half up")
print("ratings ok")

-- Roles cycle through none, tank, healer, DPS.
check(Store.NextRole(nil) == "TANK" and Store.NextRole("TANK") == "HEALER", "cycle")
check(Store.NextRole("HEALER") == "DAMAGER" and Store.NextRole("DAMAGER") == nil, "cycle back to none")

-- Comments and notes are trimmed; empty means none.
Store.SetComment(bob.sessions[1], "  great heals ")
check(bob.sessions[1].comment == "great heals", "comment trimmed")
Store.SetComment(bob.sessions[1], "   ")
check(bob.sessions[1].comment == nil, "empty comment")
store:SetPlayerNote("Dan", "ninja", 100)
check(store:Player("Dan").note == "ninja" and #store:Player("Dan").sessions == 0, "note creates the player")
print("notes on players ok")

-- Prune: only old players without a rating or note go.
store = Store.New(nil)
local now = 200 * DAY
store:Ensure("Old", nil, now - 91 * DAY)
store:Ensure("Recent", nil, now - 10 * DAY)
store:SetPlayerNote("Noted", "nice", now - 300 * DAY)
local rated = store:Ensure("Rated", nil, now - 300 * DAY)
rated.sessions[1] = { start = 0, stop = 1, stars = 3 }
local unrated = store:Ensure("Unrated", nil, now - 300 * DAY)
unrated.sessions[1] = { start = 0, stop = 1 }
store:Open("Grouped", {}, now - 100 * DAY)
check(store:Prune(now, 90) == 2, "two removed")
check(not store:Player("Old") and not store:Player("Unrated"), "old unrated players removed")
check(store:Player("Recent") and store:Player("Noted") and store:Player("Rated"), "others stay")
check(store:Player("Grouped"), "open session stays")
print("prune ok")

-- Player list: filter and sort.
store = Store.New(nil)
local a = store:Ensure("Alpha", nil, 10)
a.sessions[1] = { stars = 2 }
local b = store:Ensure("Bravo", nil, 30)
b.sessions[1] = { stars = 5 }
store:Ensure("Charlie", nil, 20).note = "Good Tank"
local function names(list)
	local result = {}
	for i, player in ipairs(list) do
		result[i] = player.name
	end
	return table.concat(result, ",")
end
check(names(store:Players()) == "Bravo,Charlie,Alpha", "recent first")
check(names(store:Players(nil, "name")) == "Alpha,Bravo,Charlie", "by name")
check(names(store:Players(nil, "rating")) == "Bravo,Alpha,Charlie", "best first, unrated last")
check(names(store:Players("tank")) == "Charlie", "filter by note")
check(names(store:Players("BR")) == "Bravo", "filter by name, any case")
print("list ok")

-- Item notes.
store:SetItemNote(2589, " 90 pieces for 1s each ", 100)
store:SetItemNote(2592, "wool", 200)
check(store:ItemNote(2589) == "90 pieces for 1s each", "item note")
check(table.concat(store:ItemIDs(), ",") == "2592,2589", "newest first")
store:SetItemNote(2589, "", 300)
check(store:ItemNote(2589) == nil and #store:ItemIDs() == 1, "empty removes")
print("items ok")

-- General notes.
local first = store:AddNote(100)
Store.SetNoteText(first, "Shopping\nlinen", 100)
local second = store:AddNote(200)
Store.SetNoteText(second, "Quest chain", 200)
local list = store:Notes()
check(list[1] == second and list[2] == first, "newest first")
check(#store:Notes("LINEN") == 1, "filter")
check(Store.Title(first.text) == "Shopping", "title is the first line")
check(Store.Title("\n  Title  \nrest") == "Title" and Store.Title("") == "", "title trimmed")
check(store:RemoveNote(first) and #store:Notes() == 1, "removed")
check(not store:RemoveNote(first), "not there twice")
print("general notes ok")

print("notes store tests passed")
