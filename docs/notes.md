# Notes (#44)

A notes window for three kinds of notes, opened by a button in the notch
island (or `/sui notes`). All notes are account-wide (`StevioUINotes`).

## Players

Every group is recorded, guild members and friends included.

- **Session:** one stretch of being in the same group with a player. It starts
  when they join (or you join them) and ends when either of you leaves. A
  player who rejoins within a few minutes (`rejoinGrace`, e.g. a disconnect)
  continues the same session.
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
  "Note" in the chat name menu.

## Blocked guilds (#45)

Players from guilds you never want to play with get a lasting mark in the
players list. Nothing goes on Blizzard's ignore list: its entries vanish, and
the mark should stay when the player leaves the guild.

- **Patterns:** `blockedGuilds` in the Notes options, a list of Lua patterns
  matched case-insensitively against the guild name, e.g. `alternative f`.
  Empty by default. A pattern that isn't valid Lua is matched as plain text.
- **Checked:** group members (on every roster change), your target, the unit
  under the mouse (and its tooltip) and nameplates. The game only tells the
  guild of units it can see; a whisper doesn't say it, and addons can't run
  `/who` on their own. So a whisperer is recognised only after being seen once.
- **Mark:** `player.blocked = { guild, pattern, time }`, added once and kept
  for good (no clean-up). `player.guild` is the guild they were last seen in,
  for every player in the notes, so the reason reads "guild <X> (matches "x"),
  since seen in <Y>" when they moved on.
- **Warnings** (`blockWarnings`, red): a chat line when a player is marked, when
  a marked player joins your group, and a line under each of their whispers in
  the whisper channel (also for whispers read after a chat lockdown). The
  tooltip shows "Marked: ..." and the list shows a red "!".
- **Unmark:** shift-click Unmark on the player's page removes a false match;
  being seen in a matching guild again marks them again.

## Items

Free text per item type (item ID), nothing automatic. Alt+right-click an item
(bags, bank, chat links) to edit; Save, or Remove (saving empty text removes it
too). Shown as a line in the item tooltip. The Items tab lists all item notes;
dropping an item on it adds one.

## General notes

A plain list of free texts; the first line is the title.

## Check in game

- Alt+right-click on bag and bank items opens the item note box and does not
  use the item.
- `GetInstanceInfo()` names dungeons and raids, so sessions show them as place.
- Tooltip lines appear on player and item tooltips.
- The popup after leaving a group, and the notch button.
- Blocked guilds: `GetGuildInfo()` gives the guild for group members, target,
  mouseover and nameplates (and isn't secret outside instances); the red lines
  appear on marking, on joining, under whispers and in the tooltip; Unmark and
  the `blockedGuilds` list in the options panel work.
