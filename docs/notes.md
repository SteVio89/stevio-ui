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
