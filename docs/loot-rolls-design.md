# Loot ticker and roll widget (#72)

Decisions from the brainstorm in #72, built in `Modules/LootTicker` and
`Modules/Rolls`. What still needs a check in game is listed in
`docs/remaining-issues.md`.

How Blizzard's popup is replaced: Blizzard opens it from its game event
router (`GameEvent.HandleStartLootRoll` → `GroupLootContainer_AddRoll`), so
the module calls `GameEvent.UnregisterInternalEvent("START_LOOT_ROLL")`.
Blizzard's roll frames then never open, nothing of theirs is hidden or
hooked, and the bind-on-pickup confirmation (`CONFIRM_LOOT_ROLL`, its own
route) still comes from Blizzard.

## Loot ticker: personal only

Keeps:
- own items of every quality (grey included, `minQuality = 0`): looted,
  pushed, created, bonus roll, refunds
- own currency, money on one line, repeats merged ("x3")
- position, rows, fading and sliding as they are; click-through

Hidden loot (while the game's chat lockdown is on, e.g. boss encounters):
- Own loot, currency and money messages that arrive secret are no longer
  dropped. They are remembered by chat line id and read with
  `C_ChatInfo.GetChatLineText` once the lockdown ends (as the chat module
  does, `Modules/Chat/Receive.lua`), then shown and merged as usual, so a
  long lockdown ends in one burst of lines.

Removed:
- other group members' loot (`showGroupLoot`, `groupMinQuality`,
  `groupAlpha`, `groupHoldTime`) – gone entirely, not moved anywhere
- roll lines (`showRolls`, the loot history handling, `RollFor` /
  `TakeLoot`) – they move to the roll widget. An item you win shows up as a
  normal own loot line again.

## Roll widget

A separate `Rolls` module with its own settings page, on/off switch and
Layout.lua positions; the loot ticker stays small and personal.

### Cards (top center, below the notch)
- 320 px wide with the ticker's 14 pt font.
- Only drops you were offered a roll on get a card; the others go to the
  history only.
- One card per open roll, stacked downward when a boss drops several items.
- Style: lighter floating cards (slightly transparent dark), a small gap
  below the notch, visually separate from the notch island.
- When the notch island opens on hover, the stack slides down below it and
  back up when it closes.
- Clickable (unlike the ticker): item tooltip on hover, shift-click links it.
- Background: the UI's default style (`backgroundColor`, dark grey at 85 %)
  with a 2 px stripe on the left in the item's quality color.
- 6 px gap below the notch, 4 px between cards.
- All cards are shown, open rolls on top, compact ones below them.

Active card (roll open, from `START_LOOT_ROLL` / `GetLootRollItemInfo`):
- icon, name in quality color, count
- timer: 3 px bar in the item's quality color, shrinking to the left, with the
  seconds left next to it
- no ✕ while the roll is open: it has to be answered
- three text buttons like Blizzard's frame: **Need · Greed/Transmog · Pass**.
  Transmog takes Greed's place when `canTransmog` (never both); no
  Disenchant button (Blizzard shows none). `RollOnLoot` types: 0 pass,
  1 need, 2 greed, 4 transmog.
- Buttons are flat white text with a faint light background on hover.
- Unavailable buttons are greyed out with `LOOT_ROLL_INELIGIBLE_REASON<n>`
  as tooltip.
- The bind-on-pickup confirmation stays Blizzard's static popup.
- Hidden roll data (lockdown): our card is still shown with what the game
  lets us display (secret text can go into a font string, but can't be read
  or compared); the buttons still work. Quality color and stripe may be
  missing. Needs a check in game which parts of `GetLootRollItemInfo` are
  secret then.

Compact card (after you chose; dimmed after Pass, but still shows the
winner):
- the top 3 rolls plus your own, filled in live from `C_LootHistory`, then
  the winner: name in class color, "You" in green when you won; no glow or
  sound
- ✕ closes it; it fades out ~15 s after the winner is known; hovering keeps
  it open

Replaces Blizzard's group loot popup (`GroupLootFrame` /
`GroupLootContainer`). A profile switch (`replaceBlizzardRolls`) brings
Blizzard's popup back if this ever causes taint.

### History window
- Own window in the loot ticker's place at the bottom left (same column and
  height); the ticker is hidden while it is open and comes back on close.
- Background like the Notes window (`0.05` at 95 %); rows like the ticker
  (20 px icons, 14 pt font).
- Opened from a new button in the notch island; Esc closes it.
- One scrolling list, newest first, with a header per encounter
  (boss · instance · date). One row per drop: icon, item, winner and their
  roll. Clicking a drop expands everyone's choice and number.
- Records rolled drops only.
- Saved per character in SavedVariables, without a limit (~1–2 KB per raid
  drop).
- Extras: search box (item or player), "Mine" filter (drops you rolled on or
  won), clear history button with confirmation.

### Recording
- Drops whose names are secret are read again from `C_LootHistory` once the
  lockdown ends; the history keeps the encounter's drops.
- Boss name from `C_LootHistory.GetInfoForEncounter`, instance from
  `GetInstanceInfo()` when the drop is recorded, date from the time recorded.

### Preview
- `/sui loot` stays the ticker preview.
- `/sui rolls` shows two made-up cards (one open, one decided) and the
  history with sample entries.
