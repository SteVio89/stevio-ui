-- Run with: lua tests/players_store_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")
local ns = loadAddonFile("Modules/Players/Store.lua")
local Store = ns.PlayersStore

local DAY = 24 * 60 * 60

-- New fills in a missing or partial saved table.
local store = Store.New(nil)
check(store.db.version == 2 and next(store.db.players) == nil and not store.upgradedFrom, "fresh table")
local saved = { players = { Bob = { name = "Bob", sessions = {} } } }
store = Store.New(saved)
check(store.db == saved and store:Player("Bob"), "existing table kept")
print("new ok")

-- #86: one spelling per player, duplicates merged at load.
check(Store.NormalizeName("Lina-Sakuranbo") == "Lina-Sakuranbo", "full name kept")
check(Store.NormalizeName("Lina Sakuranbo") == "Lina-Sakuranbo", "space")
check(Store.NormalizeName(" Lina - Die Aldor ") == "Lina-DieAldor", "realm with a space")
check(Store.NormalizeName("Lina (Azjol-Nerub)") == "Lina-AzjolNerub", "brackets and hyphen")
check(Store.NormalizeName("Lina-Home", "Home") == "Lina" and Store.NormalizeName("Lina", "Home") == "Lina", "own realm")
check(Store.NormalizeName("") == nil and Store.NormalizeName(nil) == nil, "no name")
-- WoW Forever's "First Last" from the roster, loot history and chat (#42).
local own = "CAMWOWEU4Realm10RP"
check(Store.NormalizeName("Jubylee-Signatory", own) == "Jubylee-Signatory", "roster spelling")
check(Store.NormalizeName("Jubylee Signatory", own) == "Jubylee-Signatory", "loot history spelling")
check(Store.NormalizeName("Jubylee Signatory-" .. own, own) == "Jubylee-Signatory", "chat spelling")
check(Store.NormalizeName("Bob-" .. own, own) == "Bob", "own realm dropped")
check(Store.SendName("Jubylee-Signatory") == "Jubylee Signatory" and Store.SendName("Bob") == "Bob", "send name")

saved = {
	version = 1,
	players = {
		["Lina-Sakuranbo"] = {
			name = "Lina-Sakuranbo",
			class = "DRUID",
			firstSeen = 200,
			lastSeen = 900,
			note = "nice",
			sessions = { { start = 300, stop = 400, stars = 5 }, { start = 800, stop = 900 } },
			rolls = { need = 1 },
		},
		["Lina Sakuranbo"] = {
			name = "Lina Sakuranbo",
			firstSeen = 100,
			lastSeen = 1000,
			guild = "Later Guild",
			note = "greedy",
			sessions = { { start = 500, stop = 600 } },
			rolls = { need = 2, greed = 1 },
			wins = { { link = "[B]", time = 550 } },
			blocked = { guild = "Bad", pattern = "bad", time = 120 },
		},
		["Lina-Home"] = { name = "Lina-Home", sessions = {}, firstSeen = 1, lastSeen = 2 },
	},
}
store = Store.New(saved, { ownRealm = "Home" })
local lina = store:Player("Lina Sakuranbo")
check(lina == saved.players["Lina-Sakuranbo"] and saved.players["Lina Sakuranbo"] == nil, "merged into one")
check(#lina.sessions == 3 and lina.sessions[2].start == 500, "sessions merged in order")
check(lina.rolls.need == 3 and lina.rolls.greed == 1 and #lina.wins == 1, "rolls and wins merged")
check(lina.note == "nice\ngreedy" and lina.blocked.guild == "Bad", "note and mark merged")
check(lina.firstSeen == 100 and lina.lastSeen == 1000 and lina.guild == "Later Guild", "times and guild")
check(lina.class == "DRUID" and lina.name == "Lina-Sakuranbo", "class and name")
check(saved.players.Lina and saved.players.Lina.name == "Lina" and not saved.players["Lina-Home"], "own realm renamed")
check(store:Ensure("Lina (Sakuranbo)", nil, 5) == lina, "lookups normalize too")
print("names ok")

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

-- Blocked guilds: case-insensitive patterns, a mark that outlives the guild.
local patterns = { "", "alternative f", "[bad" }
check(Store.MatchGuild("Alternative für Dingsbums", patterns) == "alternative f", "pattern matches any case")
check(Store.MatchGuild("ALTERNATIVE FUER D", patterns) == "alternative f", "upper case")
check(Store.MatchGuild("The [bad guild", patterns) == "[bad", "invalid pattern matched as plain text")
check(Store.MatchGuild("Nice People", patterns) == nil, "no match")
check(Store.MatchGuild(nil, patterns) == nil and Store.MatchGuild("", patterns) == nil, "no guild")
check(Store.MatchGuild("Alternative f", nil) == nil, "no patterns")
check(Store.MatchGuild("Nazgul", { "^naz" }) == "^naz", "anchored pattern")

store = Store.New(nil)
local player, marked = store:SeeGuild("Stranger", "Nice People", "MAGE", patterns, 100)
check(player == nil and not marked and store:Player("Stranger") == nil, "strangers in other guilds aren't stored")
player, marked = store:SeeGuild("Troll", "Alternative für D", "ROGUE", patterns, 200)
check(marked and player == store:Player("Troll") and player.class == "ROGUE", "matching player is added")
check(player.guild == "Alternative für D" and player.blocked.guild == "Alternative für D", "guild recorded")
check(player.blocked.pattern == "alternative f" and player.blocked.time == 200, "reason recorded")
local _, again2 = store:SeeGuild("Troll", "Alternative für D", nil, patterns, 300)
check(not again2 and player.blocked.time == 200, "marked only once")
store:SeeGuild("Troll", "Harmless Name", nil, patterns, 400)
check(player.guild == "Harmless Name" and player.blocked.guild == "Alternative für D", "mark stays after leaving")
store:SeeGuild("Troll", nil, nil, patterns, 500)
check(player.guild == nil and player.blocked, "guildless now, still marked")
check(#store:Players("alternative") == 1 and #store:Players("harmless") == 0, "filter finds the blocked guild")
store:Open("Friend", { place = "Westfall" }, 100)
store:SeeGuild("Friend", "Nice People", nil, patterns, 100)
check(store:Player("Friend").guild == "Nice People" and not store:Player("Friend").blocked, "known player's guild")
store:Close("Friend", 150)
check(store:Prune(100 + 200 * DAY, 90) == 1, "blocked players aren't pruned")
check(store:Player("Troll") and store:Player("Friend") == nil, "only the unmarked one went")
store:Unblock("Troll")
check(store:Player("Troll").blocked == nil, "unblocked")
store:Unblock("Nobody")
print("blocked guilds ok")

-- Bosses: kills and wipes go into the open sessions only.
store = Store.New(nil)
store:Open("Tank", { place = "Molten Core", isInstance = true }, 0)
store:Open("Gone", { place = "Molten Core", isInstance = true }, 0)
store:Close("Gone", 10)
store:Encounter("Lucifron", true)
store:Encounter("Magmadar", false)
store:Encounter(nil, true)
local tankSession = store:Player("Tank").sessions[1]
check(table.concat(tankSession.kills, ",") == "Lucifron,?", "kills by name, unknown as ?")
check(tankSession.wipes == 1, "wipe counted")
check(store:Player("Gone").sessions[1].kills == nil, "closed sessions get nothing")
print("bosses ok")

-- Loot: rolls by choice, wins, and the wins of a session.
store = Store.New(nil, { rejoinGrace = 300 })
store:Open("Rogue", { class = "ROGUE" }, 1000)
store:AddRoll("Rogue", nil, "need", 1100)
store:AddRoll("Rogue", nil, "need", 1200)
store:AddRoll("Rogue", nil, "greed", 1300)
store:AddRoll("Rogue", nil, "pass", 1400)
store:AddWin("Rogue", nil, { link = "[Sash]", encounter = "Lucifron", time = 1200 }, 1200)
store:Close("Rogue", 2000)
store:AddWin("Rogue", nil, { link = "[Late]", time = 2100 }, 2100)
store:Open("Rogue", {}, 5000)
store:AddWin("Rogue", nil, { link = "[Next]", time = 5100 }, 5100)
local rogue = store:Player("Rogue")
check(rogue.class == "ROGUE" and rogue.rolls.need == 2 and rogue.rolls.greed == 1, "rolls counted")
local first2, second2 = rogue.sessions[1], rogue.sessions[2]
local function links(list)
	local result = {}
	for i, win in ipairs(list) do
		result[i] = win.link
	end
	return table.concat(result, ",")
end
check(links(store:SessionWins(rogue, first2)) == "[Sash],[Late]", "wins in the session and just after it")
check(links(store:SessionWins(rogue, second2)) == "[Next]", "open session's wins")
store:AddRoll("Stranger", "MAGE", "transmog", 100)
check(store:Player("Stranger").class == "MAGE" and store:Player("Stranger").rolls.transmog == 1, "roll adds the player")
print("loot ok")

-- Stats: groups, time together, bosses, wins and roll shares.
local stats = Store.Stats(rogue, 5600)
check(stats.groups == 2 and stats.seconds == 1000 + 600, "groups and time, the open one until now")
check(stats.wins == 3 and stats.rollCount == 4, "wins and rolls")
check(stats.rolls.need == 2 and stats.rolls.transmog == 0, "rolls by choice")
check(Store.Percent(2, 4) == 50 and Store.Percent(1, 3) == 33 and Store.Percent(0, 0) == 0, "percent")
check(Store.FormatDuration(30) == "<1m" and Store.FormatDuration(45 * 60) == "45m", "short durations")
check(Store.FormatDuration(3 * 3600 + 20 * 60) == "3h 20m", "hours")
check(Store.FormatDuration(3 * 3600 + 5 * 60) == "3h 05m", "minutes padded")
rogue.wins[1].choice, rogue.wins[2].choice = "need", "greed"
check(Store.Stats(rogue, 5600).winsNeed == 1, "wins with Need")
local empty = Store.Stats({ sessions = {} }, 0)
check(empty.groups == 0 and empty.seconds == 0 and empty.wins == 0 and empty.rollCount == 0, "nothing yet")
print("stats ok")

-- #86 migration: version 1 tables move to 2 and keep everything.
saved = {
	version = 1,
	players = {
		Old = {
			name = "Old",
			note = "hi",
			sessions = { { start = 1, stop = 2, stars = 4 } },
			wins = { { link = "[A]", time = 5 }, { link = "[B]", time = 6, choice = "greed" } },
		},
	},
}
store = Store.New(saved)
check(store.upgradedFrom == 1 and saved.version == 2 and saved.recentTags, "upgraded to 2")
local old = store:Player("Old")
check(old.note == "hi" and old.sessions[1].stars == 4, "data kept")
local filled = store:FillWinChoices(function(name, win)
	return name == "Old" and win.link == "[A]" and "need" or nil
end)
check(filled == 1 and old.wins[1].choice == "need" and old.wins[2].choice == "greed", "win choices filled")
check(Store.New(saved).upgradedFrom == nil, "upgraded once")
check(Store.New({ players = {} }).upgradedFrom == 1, "no version is version 1")
print("migration ok")

-- Verdict, note time, tags.
store = Store.New(nil)
store:SetVerdict("Vex", "avoid", 10)
check(store:Player("Vex").verdict == "avoid", "verdict set")
store:SetVerdict("Vex", "bogus", 11)
check(store:Player("Vex").verdict == nil, "unknown verdict is neutral")
store:SetPlayerNote("Vex", "rude", 20)
check(store:Player("Vex").noteTime == 20, "note time")
store:SetPlayerNote("Vex", " rude ", 30)
check(store:Player("Vex").noteTime == 20, "unchanged note keeps its time")
store:SetPlayerNote("Vex", "", 40)
check(store:Player("Vex").noteTime == nil, "no note, no time")

check(Store.CleanTag("  Rage-Quit  ") == "Rage-Quit" and Store.CleanTag("  ") == nil, "tag trimmed")
check(Store.CleanTag("Need  on\tall") == "Need on all", "inner spaces collapsed")
check(Store.CleanTag(("x"):rep(30)) == ("x"):rep(24), "cut to 24")
check(Store.CleanTag(("ä"):rep(30)) == ("ä"):rep(24), "umlauts count as one character")
check(store:AddTag("Vex", "Rage-Quit", 50) == "Rage-Quit", "tag added")
check(store:AddTag("Vex", "rage-quit", 51) == nil, "duplicate in any case")
store:AddTag("Vex", "Ninja", 52)
store:AddTag("Ann", "Guter Heiler", 53)
local vex = store:Player("Vex")
check(table.concat(vex.tags, ",") == "Rage-Quit,Ninja", "tags in order")
check(table.concat(store.db.recentTags, ",") == "Guter Heiler,Ninja,Rage-Quit", "most recent first")
check(table.concat(store:TagSuggestions(vex, 5), ",") == "Guter Heiler", "suggestions skip own tags")
store:AddTag("Ann", "ninja", 54)
check(store.db.recentTags[1] == "ninja" and #store.db.recentTags == 3, "reused tag moves up once")
check(names(store:Players("ninj")) == "Ann,Vex", "search finds tags")
store:RemoveTag("Vex", "NINJA")
store:RemoveTag("Vex", "rage-quit")
check(vex.tags == nil, "tags removed")

-- Verdict and tags keep players from the clean-up.
store = Store.New(nil)
now = 400 * DAY
store:SetVerdict("Liked", "like", 0)
store:AddTag("Tagged", "nice", 0)
store:Ensure("Plain", nil, 0)
check(store:Prune(now, 90) == 1 and store:Player("Liked") and store:Player("Tagged"), "verdict and tags stay")
store:Forget("Liked")
check(store:Player("Liked") == nil, "forgotten")

-- Merging keeps verdict, tags and note time.
local into = { name = "A", sessions = {}, verdict = "like", tags = { "Nice" }, noteTime = 5 }
Store.MergeInto(into, { sessions = {}, verdict = "avoid", tags = { "nice", "Rude" }, noteTime = 9 })
check(into.verdict == "avoid" and table.concat(into.tags, ",") == "Nice,Rude" and into.noteTime == 9, "merged")
print("verdict and tags ok")

print("players store tests passed")
