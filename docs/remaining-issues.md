# Remaining issues

Every issue the cleanup of #31 left open was resolved in #32 (branch
`stevio-ui-32-finish-clenup`). The unit tests cover the pure parts. What they
can't cover is listed here: changes to how the addon talks to the client, which
need a check in game.

## Check in game

### Saved settings (first login after updating)
- Saved values for config keys that no longer exist are dropped from
  `StevioUIConfig.values` for good (stale options vanish from the panel).
- Chat history above `historyLimit` is trimmed at login and is gone for good.
- Migrations run once (recorded in `StevioUIConfig.migrations`):
  - `config/actionbars/...` → `config/actionBars/...`
  - `config/notch/colors/restedAlpha` → `config/notch/restedAlpha`
  - saved `layout/targetAuras/x` and `layout/focus/x` become offsets from the
    group grid's edge (old value ∓ 331)
  - a saved `layout/actionBars` list gets `bar = "MainBar"`, `"Bar2"`, `"Bar3"`
- Saved overrides of `config/actionBars/bars` and of the fixed chat channels'
  `label` are dropped, since those options no longer exist.

### Chat
- `/who`, `/roll` etc. typed into the channel view open Blizzard's input box
  pre-filled. Afterwards `/dump issecurevariable(hash_SlashCmdList, "/WHO")`
  should be `true`. `/p hi`, `/w Name hi`, `/dance` and `/sui` still run
  directly.
- `/w Firstname Lastname hi` (a Battle.net friend's name) and `/w Name hi`
  typed into the channel view send the whisper, also after Blizzard's own
  input box was used once; `/p hi` speaks in the party.
- A whisper that doesn't go out (#41) gets a grey line in its channel after
  three seconds: `Whisper to Name-Realm was not sent (...)`, naming any error,
  a blocked call (`blocked by the client: ...`), the chat lockdown or a realm
  that restricts addon chat. With none of them it says `no answer from the
  server`. A whisper that does go out adds no such line.
- Whispers (#42) go to "First Last" without the realm: writing in a whisper
  channel (opened by a received whisper or a click on a name), `/w First Last
  hi` for someone with a whisper channel, `/r hi`, and Invite in the name's
  right-click menu. `/w` with a name that has no whisper channel yet still
  takes only the first word as the name.
- Blizzard's hidden chat windows, tabs and input box don't catch clicks or the
  mouse wheel, also after opening a temporary window (pet battle log, popped-out
  whisper). Blizzard's chat is now re-hidden only when the visibility changes,
  with hooks on `EnableMouse` / `EnableMouseWheel` keeping it so in between.
- A Battle.net whisper from someone without account info lands in a channel
  labelled "Battle.net".

### Units and group
- Target auras and the focus frame sit where they did at the default spacing,
  and move with the grid when `group.spacing` changes.
- Removing player, target, pet or targettarget in the options panel loads
  without errors. The cast bars then sit under the unit's own frame, and the
  minimap uses the default target width.
- Group cells refresh once per roster change on the next frame instead of
  per cell; check a 40-player raid while people join and leave.
- Your own cell stays at full alpha in combat in a raid.
- The target auras and the group cells' auras still show and update (both are
  now built by `ns.CreateAuraContainer`, in the same call order as before).
- Blizzard's party frame is now hidden by the group grid, not the unit frames.

### Other
- The action bars are styled and placed from `ns.layout.actionBars` alone.
- A channel's cast bar stays visible when it turns interruptible or not.
- `/sui loot`, `/sui notch` and `/sui test` say the module is off while it is.

### Action sets (#33)
- Switching to a set that can't place everything lists each missing action with
  its slot and name instead of only a count. `/sui bars missing` lists them
  again, `/sui bars forget` drops them; the next switch then reports nothing.
- Spells a talent replaces (e.g. a healing spell whose slot shows the upgraded
  version) are placed via the spell they replace instead of being reported as
  missing. Check that such a slot shows and casts the upgraded spell.

### Minimap shape (#62)
- The map is square and north up again after a login and after a `/reload`,
  even though the strip experiment (#60) left the saved `rotateMinimap` CVar
  on. Turning "Rotate Minimap" on in Edit Mode is undone and the map stays
  square. Unverified: the exact name `CVAR_UPDATE` passes for the CVar, and
  whether 0.2 s after the change is late enough for the mask.

### Mark toolbar (#52)
- The toolbar sits on top of the minimap, right aligned (#56); on narrow
  screens, where the map is less wide than the toolbar, it reaches past the
  map's left edge. Check it doesn't touch the right edge bars or the target
  auras. Tooltips, including the toolbar's own, open above it.
- The chat is back at the top edge. A chat position saved in the options
  panel keeps its old y (30 units lower); reset it there.
- Left click on a symbol marks the target, again takes the mark off; it also
  works in combat. The target's symbol is outlined, also when another player
  sets it. Clear unmarks the target.

### Code validation against Blizzard's UI (#71)
- Cast bar: pressing another spell during a cast ("Another action is in
  progress") no longer hides the bar; stops now need the cast's own castID,
  like Blizzard's casting bar. Check on target/focus in combat too (castIDs
  may be secret there; then every stop hides the bar as before).
- Group cells reread their auras when a token is handed out again (party3
  becomes party2 after someone leaves): no stale debuffs or HoTs.
- A typo in an aura filter in the options (e.g. `HARMFUL|RAD`) reports an
  error and leaves that one aura group empty; the cells keep working.
- Health bars take the class color as soon as a member's name arrives.
- Ctrl/Alt+click on a player name in the chat view whispers through
  Blizzard's input box instead of raising an error.
- Writing in a chat channel (e.g. Trade) after a relog goes to the channel's
  current number, also before anyone said something there.
- An AFK/DND reply with `%s` or `%%` shows as typed; Battle.net broadcasts
  stay on one line.
- The loot ticker shows currency icons (was always the question mark).
- The Notes item tab names an item that wasn't cached yet once it loads.
- Options panel: "Add binding" works while in combat; "Set" with an empty
  CVar value does nothing.
- Main bar: the page arrows (left of the main bar) no longer react to clicks;
  Edit Mode's "hide bar scrolling" is now set in our layout.
- Combo points follow the target: switching targets shows that target's
  points (WoW Forever keeps them on the target).
- The objective tracker is made invisible at login, but really hidden only
  after our Edit Mode layout is applied. Check `/console taintLog 1` shows no
  blocked action for the right-side action bars.
- Edit Mode: with five account layouts already, a chat line asks to delete
  one instead of saving a sixth. Our layout is saved only once Blizzard has
  the layouts (`EditModeManagerFrame:IsInitialized()` at entering the world).
- Chat: lines Blizzard keeps in the cinematic letterbox stay out of the chat;
  Guild Discord users' names aren't links; `{star}`/`{rt1}` show as raid icons
  where Blizzard shows them, and `{tags}` are sent language-independent.
  Our whispers no longer set Blizzard's "last told" target: the re-whisper
  key only offers whispers from Blizzard's own input box (and received ones).
- Flight list: a list taller than the map scrolls (Blizzard's scroll box with
  a minimal scroll bar that shows only when needed); free flights show no cost.
- Players: sessions open at logout end at the logout; after a `/reload` in the
  same group they continue, after a later login alone the rating popup shows.
- Settings: `GxApi` and the resolution CVars are no longer set from the
  profile; saved overrides of them are dropped at login.

### Loot ticker and roll cards (#72)
- Loot ticker: only your own loot; no lines for other players or rolls. Loot,
  currency and gold from a boss fight (chat lockdown) appear once the fight
  is over, not before and not twice.
- Blizzard's Need/Greed/Pass popup no longer opens; our card does (top
  center, below the notch). `/console taintLog 1` shows nothing blocked after
  rolling. Bind-on-pickup items still ask for confirmation (Blizzard's
  dialog).
- Need/Greed/Transmog/Pass on the card really roll; greyed-out buttons show
  the reason on hover. Transmog replaces Greed for items that allow it.
- The answered card fills in the rolls and winner; it matches the right
  drop when the boss drops two of the same item.
- Not answering: the card turns into a dimmed "passed" card when the timer
  runs out.
- Hovering the notch while cards are open (#84): the island stays down and
  the cards stay put, also for `/sui roll` cards; it comes up again once the
  last card has faded. With the island already open when a roll starts, the
  cards slide below it and back up when it closes.
- Which parts of `GetLootRollItemInfo` are secret during a fight (the card
  then shows what it can, buttons still work), and whether trash rolls
  appear in the loot history at all (without it the answered card shows no
  winner and fades after `resultTimeout`).
- History: entries survive a relog, aren't doubled after a `/reload`,
  group under the right boss and instance, and drops decided during a fight
  are added once it is over. Search, "Mine" and Clear work; Esc closes it;
  the loot ticker comes back when it closes.
- `replaceBlizzardRolls = false` + `/reload`: Blizzard's popup is back and
  our card appears after rolling there.
- `/sui roll 3` (#82): three cards with different bag items; the made-up
  players' choices show up within a few seconds, a click on Need/Greed/Pass
  shrinks the card (no real roll, no error), and the numbers and the winner
  appear once everyone chose; not answering passes after 30 s. The cards
  fade like real ones. `/sui roll history` lists the drops under
  "Simulated drops"; closing it brings the real history back, and nothing
  of it is in the saved history after a `/reload`.

### Players window (#86)
- First login after the update: the doubled players ("First-Last" and
  "First Last") are one entry with all sessions, rolls, wins and the note;
  `StevioUIPlayers.version` is 2. Old wins show their choice where the roll
  history still had the drop.
- Name spellings: a group member, the same player in the loot history and
  "Player info" from the chat name menu all open the same entry. This rests on
  the roster giving "First-Last" and chat "First Last-Realm" on WoW Forever
  (worked out from #42 and the doubled entries, not seen directly). If
  `GetNormalizedRealmName()` differs from the realm in chat names, chat lookups
  make a third spelling.
- Whisper opens the chat input to "First Last"; Invite invites them.
- Window with an empty database and with a big one (200+ players): scrolling
  the list stays smooth, search and chips update, the sections and times are
  right, the selected row has the tint and the accent stripe, up/down and
  typing work, Escape closes, movement keys work again once it is closed and
  in combat. The window is moved by its title bar and is back there after a
  `/reload`; the gear opens the Players options page.
- Fonts: `‹›`, `„“`, `–`, `…` and `×` render (the standard font may lack one).
- Circles (initials, dots) are round (`Interface\Masks\CircleMaskScalable`),
  the star icon is readable at 10 px.
- Overview in 7 days, 30 days and everything; the columns' tooltips; names
  open the player; "Rate now" walks through the unrated groups of the week
  and "Later" moves on.
- Player page: verdict switch, tags (add, suggestions, remove), note editing
  (the date updates, more lines push the history down), history filters,
  role chip, stars, comments, item tooltips and shift-click linking, partners.
  Long boss lists wrap.
- Tooltip line with verdict and tags; the red chat line when an avoided
  player joins; the verdict switch in the popup after a group.

Left out or simplified:
- Tag suggestions are only tags used before; there is no built-in list.
- THIS WEEK and THIS MONTH are the last 7 and 30 days, not calendar weeks.
- The window keeps its configured size; there is no resize grip.
- Suggestion chips are drawn with a plain border, not a dashed one.

### New design (#76, themes Dusk and Night violet)
Go through each with `style.theme = "dusk"` and once more with `"violet"`
(`/reload` after switching).
- Fonts: the chat header's `›`, the date line's `——` and the money squares
  render (the standard font may lack a glyph; then it shows as a box).
- Unit frames: shade and tinted missing health visible, text readable; no Lua
  errors (`/sui errors`) with a hostile player targeted outside the group in
  combat (secret health and class colors on the bar and its background).
- Cast bar in the accent; not interruptible stays grey.
- Action buttons: hover edge, pushed, checked (accent tint and edge, also on
  the active stance), cooldown, red keybinding out of range, empty slots only
  a hint. The keybinding keeps Blizzard's grey instead of `textMuted`, so the
  range tint keeps working.
- Set switcher: the dots follow the set.
- `/sui test 5`, `20`, `40`: name, role, debuffs and HoTs don't overlap; dead,
  out of range, aggro (inner edge) and target (2 px outside) look right.
  Damage dealers show no role icon (Blizzard's role delegate is handed an
  empty texture for them).
- Real group in combat: dispellable debuffs with a blue edge on the right,
  other debuffs continue to their left (the second aura container is anchored
  to the first, which sizes itself to its icons; check it closes up when there
  is no dispellable debuff). At most 2 dispellable + 1 other show. No taint.
  Not built: an extra blue inner edge on the cell while a dispellable debuff is
  up, as that can't be read safely in combat; the icon edge has to do.
- Keyboard healing cursor still visible with and without a target (its
  colors are unchanged, violet).
- Chat: headings and zone groups, pills, `✕` only on hover (also while the
  cursor moves onto the `✕`), accent marker, scrolling with many channels,
  date line; headings and channels evenly spaced; no light line inside the
  chat's or the mark bar's black border.
- Chat headings (#78): a click on "Log", "General" or "Channels" shows all lines
  of its channels by time with their tag, marks the heading like a row, reads
  their unread counts, takes new lines live (date line included) and keeps the
  input on "Only /commands here"; a click on a zone tag opens that channel;
  "Copy" copies the merged lines; a `/sui` reply while "Log" is open stays there.
- Chat fixes (#79): a long message (several wrapped lines, also with item
  links) shows in full as a preview while the chat is hidden; several long
  ones stay within the chat's area, the oldest dropping out; a click and the
  hover hold still work on each wrapped line. Text in the input line
  (Ä, g, y, item links) isn't cut off at the box's top or bottom edge.
- Group cells in a real group (#80): class-colored health, name and power
  instead of plain white cells. If `/sui errors` lists an error from an aura
  container, the cells still paint; only that debuff or HoT group stays
  empty (the error points at the actual aura problem).
- Group cells in a real group (#81): class-colored health, name and power
  instead of black cells, also right after joining, after a `/reload` in the
  group and after someone leaves or joins. If they stay black, `/sui errors`
  should now list why (heal bars or an aura container failing to build).
- Notch island: round corners (Media/Corner.tga), no shadow or light rim, grid with and
  without rested XP and reputation, many addon buttons muted until hovered,
  accent edge on the notes/players/rolls button while its window is open;
  also without a notch (fallback).
- Minimap: zone and time update; the tracking icon sits above the fade, the
  mail icon now at the lower right; `,` still hides the corner with the fade.
- Micro menu and bags: muted icons light up on hover and stay muted after
  Blizzard swaps a micro button's atlas; the panels sit behind both rows and
  hide with the corner. Micro buttons moved to the vehicle bar leave their
  (then empty) panel behind.
- Mark toolbar: panel with padding; the tooltip still sits above it.
- Tooltip: panel color and black border on every tooltip kind
  (`themedBackdrop` turns it off if it causes trouble).
- Different UI scales (0.64, 0.8, 1.0): 1 px edges stay sharp.

Left out on purpose:
- The buffs and debuffs at the top right (Blizzard's aura buttons) are
  unchanged: restyling them from addon code risks taint while auras are secret.
- The Inter font (optional in the spec) is not bundled; the standard font stays.
- No free bag slot count next to the bags (`showFreeSlots`, optional).
- The mana color stays Blizzard's.
