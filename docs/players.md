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
- One general **note** per player.
- **Average:** the mean of the rated sessions only, overall and per role.
  Unrated sessions never count.
- **Clean-up:** at login, players last seen more than `keepUnratedDays` (90)
  ago are deleted when they have no rated session and no note. Rated or noted
  players stay forever, with all their sessions.
- **After leaving a group** a small popup lists the players of that group with
  role, stars and a comment field, and a "Later" button. Larger groups than
  `popupMaxPlayers` get a chat line instead.
- **Shown:** the player's tooltip (`★ 3.8 · Healer 4.3 (3) · DPS 2.0 (1)` and
  the note), a chat line when a rated or noted player joins your group, and
  "Player info" in the chat name menu.

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
- **Wins:** item link, boss, instance and time for each drop a player won.
  The "Items won" view on their page lists them (hover for the item,
  shift-click links it); the "Groups together" view counts them per session
  (a win up to `rejoinGrace` after the session still counts for it).
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
- **Unmark:** shift-click Unmark on the player's page removes a false match;
  being seen in a matching guild again marks them again.

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
- Blocked guilds: `GetGuildInfo()` gives the guild for group members, target,
  mouseover and nameplates (and isn't secret outside instances); the red lines
  appear on marking, on joining, under whispers and in the tooltip; Unmark and
  the `blockedGuilds` list in the options panel work.
