# Players (#74)

The player database: everything about the players you group with, in one
module (`Modules/Players`) and one account-wide table (`StevioUIPlayers`).
Opened by a button in the notch island, `/sui players [name]` or "Player
info" in the chat's name menu. It started as the players tab of the notes
(#44, #45); at the first login after #74 the players saved in
`StevioUINotes.players` move over once, and the options keepUnratedDays,
rejoinGrace, popupAfterGroup, popupMaxPlayers, joinReminder, blockedGuilds and
blockWarnings move from the Notes page to the Players page (showInTooltip is
copied, both modules have one).

Since #86 the window is a database to open in a quiet moment: statistics over
everyone, who to play with again and who to avoid. The design references are
three images (detail, overview, marked & avoided) the user keeps outside the
repo (`debug-screens/`, not committed: 18 MB).

## Names (#86)

Every name from the game goes through one function, `Store.NormalizeName`,
and players are stored as "Name" on your realm, else "Name-Realm" (spaces and
hyphens taken out of the realm, like Ambiguate(..., "none") for chat names).

The cause of the doubled players ("Linadilar-Sakuranbo" with sessions and
rating, "Linadilar Sakuranbo" without): WoW Forever names characters
"First Last" (#42), and each source spells that differently. The group roster
(`UnitName`) gives "First-Last", the loot history (roll results, `AddRoll` /
`AddWin`) "First Last", chat events "First Last-OwnRealm". Each was stored as
it came. Now all three become "First-Last"; at login, entries stored under
another spelling are merged into one (sessions in order, rolls added, wins,
notes joined, the earlier mark, verdict (avoid wins), tags; first seen is the
earlier, last seen the later). Whisper and invite send "First Last" again,
which is what the server takes (#42). `/sui players First Last` takes the
whole name.

## Sessions

Every group is recorded, guild members and friends included.

- **Session:** one stretch of being in the same group with a player. It starts
  when they join (or you join them) and ends when either of you leaves. A
  player who rejoins within a few minutes (`rejoinGrace`, e.g. a disconnect)
  continues the same session.
  Logging out ends the open sessions at that moment, so time offline doesn't
  count; after a `/reload` in the same group they continue.
- Each session records the date, the **role** the game assigned (Tank, Healer,
  DPS; changeable), an optional **1–5 star rating**, an optional comment and
  the **place**.
- **Place:** what *you* did while grouped. Every instance entered during the
  session ("Deadmines, Stockades"), or else the open-world zone where most of
  the session was spent ("Westfall · open world"). Zone changes fire an event
  whether you walk through a portal or get ported, and `GetInstanceInfo()`
  says whether that is a dungeon or raid.
- One general **note** per player, with the time it was last edited
  (`noteTime`).
- A **verdict** (#86) apart from the stars: play again (`like`), neutral
  (none) or avoid (`avoid`).
- **Tags** (#86): short free texts ("Needs on everything", "Good healer"), at
  most 24 characters, the same tag in another case only once. Suggestions are
  the tags used most recently anywhere in the database (`recentTags`, 20).
- **Average:** the mean of the rated sessions only, overall and per role.
  Unrated sessions never count.
- **Clean-up:** at login, players last seen more than `keepUnratedDays` (90)
  ago are deleted when they have no rated session, note, verdict, tag or
  mark. The others stay forever, with all their sessions.
- **After leaving a group** a small popup lists the players of that group with
  role, stars, a comment field and the verdict switch, and a "Later" button.
  Larger groups than `popupMaxPlayers` get a chat line instead.
- **Shown:** the player's tooltip (verdict and tags, e.g. `Avoid · Needs on
  everything, Rage quit`, then `★ 3.8 · Healer 4.3 (3) · DPS 2.0 (1)` and the
  note), a chat line when a player with a rating, note, verdict or tags joins
  your group (red for avoided players, like marked ones), and "Player info"
  in the chat name menu.

## Bosses and group stats

- **Bosses:** `ENCOUNTER_END` adds a kill (by boss name) or a wipe to every
  open session. Hovering a session's date and place lists its bosses, wipes
  and the items won.
- **Stats** on the player's page: groups together, time together (open
  sessions up to now), bosses killed and wipes.

## Loot

- Every decided group loot roll of the roll history (`Modules/Rolls`) is
  passed once per drop (not again when the loot history repeats it after a
  reload) to the player database. Your own roll is left out.
- **Rolls:** each player's choices are counted as Need (main and off spec),
  Greed, Transmog and Pass, shown as shares: `Need 40% · Greed 50% · Pass 10%
  (20 rolls)`.
- **Wins:** item link, boss, instance, time and the choice it was won with
  (`need`, `greed`, `transmog`) for each drop a player won. Wins saved before
  #86 get their choice from the roll history once, when it still has the
  drop. The history on their page lists them under the session (hover for
  the item, shift-click links it; a win up to `rejoinGrace` after the session
  still counts for it).
- The tooltip line `Won 5 items · Need 40% ...` (`lootInTooltip`).
- Loot keeps nobody from the clean-up: only ratings, notes and blocked marks
  do.

## Blocked guilds (#45)

Players from guilds you never want to play with get a lasting mark in the
players list. Nothing goes on Blizzard's ignore list: its entries vanish, and
the mark should stay when the player leaves the guild.

- **Patterns:** `blockedGuilds` in the Players options, a list of Lua patterns
  matched case-insensitively against the guild name, e.g. `alternative f`.
  Empty by default. A pattern that isn't valid Lua is matched as plain text.
- **Checked:** group members (on every roster change), your target, the unit
  under the mouse (and its tooltip) and nameplates. The game only tells the
  guild of units it can see; a whisper doesn't say it, and addons can't run
  `/who` on their own. So a whisperer is recognised only after being seen once.
- **Mark:** `player.blocked = { guild, pattern, time }`, added once and kept
  for good (no clean-up). `player.guild` is the guild they were last seen in,
  for every player in the database, so the reason reads "guild <X> (matches "x"),
  since seen in <Y>" when they moved on.
- **Warnings** (`blockWarnings`, red): a chat line when a player is marked, when
  a marked player joins your group, and a line under each of their whispers in
  the whisper channel (also for whispers read after a chat lockdown). The
  tooltip shows "Marked: ..." and the list shows a red "!".
- **Unmark:** "Remove mark" in the red bar on the player's page removes a
  false match (a plain click now, the bar asks for nothing else); being seen
  in a matching guild again marks them again.

## The window (#86)

`window.width`/`height` (1150 × 860) set its size; it is moved by its title
bar and remembers where (`StevioUIPlayers.window`). The title bar counts the
entries, rated and marked players; the gear opens the Players options page.

**List (left):** a search over name, guild, note and tags; filter chips with
counts (All, Rated, Play again, Avoid, Note, Marked); sort by last seen,
rating, time together or name; a role filter (the role of the latest groups
that had one). "Overview" comes first. Sorted by last seen, the players stand
under TODAY, YESTERDAY, THIS WEEK (the last 7 days), THIS MONTH (the last 30)
and OLDER. A row: the initial in a circle in class color, name, role and
place of the latest group, average (red at 2 or less, "–" unrated), the time
(today), weekday (this week) or date, and icons for marked and noted. Only
the rows in view are built, so long lists scroll smoothly. Up/down step
through the players; typing a letter goes to the search. Out of combat the
window takes the keyboard while it is open (so movement keys type into the
search); in combat it leaves the keys alone.

**Overview** (`Store:Overview`, period 7 days, 30 days or everything):
- A bar when groups of the last 7 days have unrated players; "Rate now" opens
  the rating popup for each of those groups in turn ("Later" moves on).
- Tiles: players (new in the period), groups (dungeons among them), time in
  groups (average per group), bosses (wipes), rated players (average stars).
  Sessions whose times overlap are one group; a group's bosses count once.
  Rated players, their average and the distribution cover all time.
- Your ratings: players per rounded average. Roll behaviour of everyone: the
  shares of all rolls, and the Need outliers (`Store.NeedOutlier`: from 10
  rolls, Need at least 1.5 times the average).
- Most time with (top 5 of the period) and Careful (marked, avoided, average
  2 or less; marked and avoided first).
- Groups per day: one column per day (90 days for "everything").

**Player page:** the circle, name, class and guild, first and last seen;
Whisper, Invite (a click only) and "..." (copy the name, forget); the average
with stars and the verdict switch; the red bar when marked; tags (✕ removes,
suggestions with +, an own tag in a small input); tiles for groups, time
together, bosses, wipes and items (how many with Need); rating by role; roll
behaviour (with the Need warning against everyone's average, or an empty
state); the note, edited in place, with its date; the history, one card per
group, newest first, filtered by all, with loot, unrated: date, place,
duration, role (click to change), bosses killed (green), wipes (red), the
items won with their choice, the comment and the stars. Last, the players
most often in the same groups (`Store:Partners`: how many of their sessions
overlap the player's), each opening their page.

## Check in game

- Players saved in the notes before #74 show up in the players window after
  the first login, and the notes window has only the Items and Notes tabs.
- Options set on the Notes page (e.g. blockedGuilds) show up on the Players
  page.
- `GetInstanceInfo()` names dungeons and raids, so sessions show them as place.
- `ENCOUNTER_END` in Molten Core adds kills (with the boss name) and wipes to
  the sessions; check whether the name is secret right then (it is then
  counted as "?").
- A group loot roll adds the winner's item and everyone's choices; names of
  players from other realms match their sessions ("Name-Realm").
- Tooltip lines appear on player tooltips (rating, loot, note, marked).
- The popup after leaving a group, the notch button and "Player info" in the
  chat name menu.
- The redesigned window (#86): see docs/remaining-issues.md, "Players window".
- Blocked guilds: `GetGuildInfo()` gives the guild for group members, target,
  mouseover and nameplates (and isn't secret outside instances); the red lines
  appear on marking, on joining, under whispers and in the tooltip; Unmark and
  the `blockedGuilds` list in the options panel work.
