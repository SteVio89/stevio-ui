# Loot ticker and roll widget (#72)

Decisions from the brainstorm in #72. Nothing here is built yet.

## Loot ticker: personal only

Keeps:
- own items of every quality (grey included, `minQuality = 0`): looted,
  pushed, created, bonus roll, refunds
- own currency, money on one line, repeats merged ("x3")
- position, rows, fading and sliding as they are; click-through

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

Active card (roll open, from `START_LOOT_ROLL` / `GetLootRollItemInfo`):
- icon, name in quality color, count, timer bar
- three text buttons like Blizzard's frame: **Need · Greed/Transmog · Pass**.
  Transmog takes Greed's place when `canTransmog` (never both); no
  Disenchant button (Blizzard shows none). `RollOnLoot` types: 0 pass,
  1 need, 2 greed, 4 transmog.
- Unavailable buttons are greyed out with `LOOT_ROLL_INELIGIBLE_REASON<n>`
  as tooltip.
- The bind-on-pickup confirmation stays Blizzard's static popup.

Compact card (after you chose; dimmed after Pass, but still shows the
winner):
- the top 3 rolls plus your own, filled in live from `C_LootHistory`, then
  the winner highlighted
- ✕ closes it; it fades out ~15 s after the winner is known; hovering keeps
  it open

Replaces Blizzard's group loot popup (`GroupLootFrame` /
`GroupLootContainer`). A profile switch (`replaceBlizzardRolls`) brings
Blizzard's popup back if this ever causes taint.

### History window
- Own window in the loot ticker's place at the bottom left (same column and
  height); the ticker is hidden while it is open and comes back on close.
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
- Boss name from `C_LootHistory.GetInfoForEncounter`, instance from
  `GetInstanceInfo()` when the drop is recorded, date from the time recorded.

### Preview
- `/sui loot` stays the ticker preview.
- `/sui rolls` shows two made-up cards (one open, one decided) and the
  history with sample entries.

## Still open
- Card colors and opacity, gap below the notch, row height of the history.
