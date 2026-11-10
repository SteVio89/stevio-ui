# Remaining issues

What the cleanup of issue #31 (branch `stevio-ui-31-cleanup`) found but left
unchanged, because that cleanup had to keep behaviour exactly as it was. Every
entry says what is wrong, where it is, a proposed fix and **what the fix
changes or breaks**. Line numbers refer to the end of that branch.

Severity: **high** = Lua error or a feature lost; **medium** = visibly wrong in
normal play; **low** = edge case or cosmetic.

## 1. Bugs

### 1.1 Tracker key errors with the tracker module off — high
- **Where:** `Modules/Tracker/Tracker.lua:29` (`ns.ToggleTracker`),
  `Modules/Settings/Profile.lua` (binds `-`).
- **Problem:** with `tracker.enabled = false` the `-` key still calls
  `ToggleTracker`. Before it errors on `badge.texture` (`badge` is nil), it has
  already set the tracker's alpha.
- **Fix:** return early from `ToggleTracker` while the badge doesn't exist.
- **Changes:** with the module off, `-` does nothing and raises no Lua error.
  With the module on, nothing changes.

### 1.2 One failing module stops all later ones, including `/sui restore` — high
- **Where:** `Core/Init.lua:144` (`EnableModules`).
- **Problem:** `OnEnable` runs without protection. An error in any module
  skips every module after it in the `.toc`. Settings is last, so the profile
  isn't applied and `/sui config`, `/sui export`, `/sui apply` and
  `/sui restore` never get registered. `ns.ApplyEditModeLayout()` doesn't run
  either.
- **Fix:** call each `OnEnable` through `ns.SafeCall`.
- **Changes:** after an error the other modules still load. The error still
  shows up in the error frame and `/sui errors`. A broken module may end up
  half set up instead of not at all.

### 1.3 Keyboard healing cursor can stay invisible after combat — medium
- **Where:** `Modules/KeyboardHealing/KeyboardHealing.lua:30`
  (`UpdateCursorState`).
- **Problem:** in combat `UnitIsUnit` returns a secret value, and the borders
  are driven by `SetAlphaFromBoolean`, which can leave an edge at alpha 0.
  Outside combat only `SetShown` is called, and that never resets the alpha.
  So after combat, targeting the cursor's player can show an invisible active
  border until the next secret evaluation.
- **Fix:** always use `Border:SetShownFromBoolean` /
  `Border:SetHiddenFromBoolean`. They reset the alpha in the non-secret case.
- **Changes:** the cursor border is always visible when it should be. There is
  no other visible difference.

### 1.4 Cast bar hides in the middle of a channel — medium
- **Where:** `Modules/Units/CastBar.lua:15-16`.
- **Problem:** `UNIT_SPELLCAST_INTERRUPTIBLE` and `NOT_INTERRUPTIBLE` are
  handled as a normal cast (`UnitCastingInfo`). During a channel that returns
  nil, so the bar hides.
- **Fix:** for these two events, check `UnitChannelInfo` first, then
  `UnitCastingInfo`.
- **Changes:** a channel's bar stays visible and changes colour when the
  channel turns interruptible or not.

### 1.5 "(unbind)" doesn't work for keys the profile binds — medium
- **Where:** `Modules/Settings/Model.lua:42` (`BindingOverride`), used from
  `Modules/Settings/Panel.lua:148`. `tests/settings_model_test.lua` pins the
  current behaviour.
- **Problem:** `profileCommand and false or nil` is always `nil` in Lua (the
  `and/or` idiom can't return `false`). No override is saved, so the profile's
  binding comes back at the next login.
- **Fix:** `if profileCommand then return false end return nil`, and update the
  test.
- **Changes:**
  - Unbinding a profile key in the options panel now sticks.
  - It is saved as `false` in `StevioUIConfig.bindings`, which
    `Settings.lua` already treats as "unbound".
  - Existing saved data is unaffected.

### 1.6 Removing a unit frame from the options panel errors — medium
- **Where:** `Modules/Units/Units.lua` (OnEnable, class power and cast bar
  anchoring), `Modules/Minimap/Minimap.lua` (`GetMapSize`), and
  `Modules/Minimap/Geometry.lua`.
- **Problem:**
  - The list editor allows removing entries from `units.frames`.
  - Without player, class power is created for nil.
  - Without pet or targettarget, the cast bars anchor to a nil frame.
  - Without target, the minimap size calculation does arithmetic on nil.
- **Fix:** skip the dependent parts when their unit is missing, and give the
  minimap a fallback width. Alternatively, stop the editor from removing these
  four entries.
- **Changes:** the UI loads with a reduced unit list instead of erroring. The
  minimap size uses the fallback when there is no target frame.

### 1.7 Chat: date lines push old messages out of the view — medium
- **Where:** `Modules/Chat/View.lua:160` (`SetMaxLines(config.historyLimit)`).
- **Problem:** the message frame also holds one date line per day. A full
  channel spanning several days loses its oldest messages from the view, while
  Copy still shows them.
- **Fix:** `SetMaxLines(config.historyLimit * 2)`, or count the day lines that
  `RenderMessages` adds.
- **Changes:** every stored message is visible again. The frame holds a few
  more lines (slightly more memory per channel view).

### 1.8 Chat: possible taint of Blizzard's slash command tables — medium (unverified)
- **Where:** `Modules/Chat/Commands.lua:88` (`ChatFrameUtil.ImportAllListsToHash()`).
- **Problem:** called from addon code, the first import fills
  `hash_SlashCmdList`, `hash_ChatTypeInfoList` and `hash_EmoteTokenList` from
  tainted code. Two consequences:
  - `issecurevariable(hash_SlashCmdList, …)` may then report Blizzard's own
    commands (`/who`, `/roll`) as insecure, and run them from addon code. That
    is what the comment in that file says it avoids.
  - It may taint Blizzard's later parsing.
- **Fix:** check in game first: `/dump issecurevariable(hash_SlashCmdList, "/WHO")`
  after typing a command into the chat view. If it is tainted, don't call the
  import. Instead, look commands up in `SlashCmdList` / `_G["SLASH_..."]`, or
  hand any unknown command to Blizzard's input.
- **Changes:** depends on the fix. At worst, a few commands that run directly
  in the channel view today would be handed to Blizzard's input box instead
  (one extra Enter).

### 1.9 `historyLimit` lowered: history only shrinks by one per message — low
- **Where:** `Modules/Chat/History.lua:339` (`Store:Add`).
- **Problem:** each new message drops only one old message, and saved
  channels are never trimmed when they load.
- **Fix:** trim to the limit on load (`History.New`) and with a `while` loop
  in `Add`.
- **Changes:** after the limit is lowered, saved history beyond it is deleted
  at the next login. **This loses data:** messages above the new limit are
  gone for good.

### 1.10 Chat: wrong channel with Shift-Tab in an edge case — low
- **Where:** `Modules/Chat/History.lua:266` (`NextIndex`),
  `tests/chat_flow_test.lua` pins it.
- **Problem:** when the selected channel isn't in the list, "previous" goes to
  the second-to-last channel instead of the last.
- **Fix:** treat an unknown selection as index 0 for "next" and as
  `#keys + 1` for "previous".
- **Changes:** Shift-Tab then lands on the last channel. Update the test.

### 1.11 Chat: Real ID name saved as a whisper channel label — low
- **Where:** `Modules/Chat/History.lua:225-235` (`Route`, Battle.net branch
  without account info).
- **Problem:** without account info, the channel label is the sender's Real
  ID name, and it is saved to `StevioUIChatHistory`. The comments say Real ID
  names are never saved.
- **Fix:** use a neutral label (e.g. "Battle.net") until account info is
  available.
- **Changes:** that whisper channel shows the neutral name. Already saved
  labels stay until the channel is deleted. Fixing those would need a
  migration.

### 1.12 Chat: community notices show the raw channel id — low
- **Where:** `Modules/Chat/Format.lua:95` (`noticeUser`).
- **Problem:** kick, ban and owner notices use the raw `channelName`
  ("Community:123:4"). The plain `notice` resolves it through
  `ChannelDisplayName`.
- **Fix:** resolve the name the same way in `noticeUser`.
- **Changes:** these notices show the community name.

### 1.13 Copied chat text keeps some escape codes — low
- **Where:** `Modules/Chat/History.lua:16` (`StripMarkup`).
- **Problem:**
  - `|K…|k` (Battle.net names), `|A…|a` (atlases), `|n` and `|cn…:` colours
    are not stripped.
  - An escaped `||c…` is read as a colour code.
- **Fix:** extend the patterns, and handle `||` before colour codes.
- **Changes:** the Copy window shows cleaner text. Nothing else.

### 1.14 `/sui errors` with entries that have no locals or stack — low (unverified)
- **Where:** `Core/ErrorLog.lua` (`IsOurs`, `Format`).
- **Problem:** `entry.stack:find` fails on a nil stack, and `%s` with a nil
  `entry.locals` fails in Lua 5.1. This only happens if Blizzard ever stores
  such entries.
- **Fix:** `tostring(entry.locals or "")` and `(entry.stack or "")`.
- **Changes:** `/sui errors` can't fail on such entries.

### 1.15 `/sui errors clear` hides repeating errors for the session — low (unverified)
- **Where:** `Core/ErrorLog.lua:13` (`firstSessionIndex`).
- **Problem:** clearing works by skipping old indices. If Blizzard counts a
  repeated error on its existing entry instead of adding a new one, an error
  that recurs after the clear is never shown again this session.
- **Fix:** remember the cleared entries' messages and counts instead of an
  index.
- **Changes:** errors that repeat after a clear show up again.

### 1.16 `GetMinimapShape` says "SQUARE" with the minimap module off — low
- **Where:** `Modules/Minimap/Minimap.lua:9`.
- **Problem:** the global is defined at load, before we know whether the
  module is enabled. Other addons (LibDBIcon) then place buttons for a square
  map on Blizzard's round one.
- **Fix:** define it in `OnEnable`.
- **Changes:** with the module off, other addons see Blizzard's default (round)
  shape. With the module on, nothing changes.

### 1.17 Loot ticker: cross-realm players lose their class colour — low
- **Where:** `Modules/LootTicker/LootTicker.lua:88` (`PlayerClass`).
- **Problem:**
  - The roster fallback compares the bare `UnitName` with a name that may
    include "-Realm".
  - The loop runs one index too far: `partyN` includes the player.
- **Fix:** compare `Ambiguate`d names and loop to `GetNumGroupMembers() - 1`
  in a party.
- **Changes:** cross-realm looters are shown in class colour.

### 1.18 Group cells: range fading differs in combat — low
- **Where:** `Modules/Group/Cell.lua:58-62`.
- **Problem:**
  - With secret values, `checkedRange` is ignored, so units whose range can't
    be checked are dimmed in combat but not outside it.
  - If `UnitIsUnit(unit, "player")` is secret, your own cell can be dimmed.
- **Fix:** combine both values without branching, e.g. compute the alpha from
  `inRange` only when the check applies, or always keep your own cell at 1.
- **Changes:** fading in combat matches fading outside combat.

### 1.19 Unit frames: level colour kept when the level is secret — low
- **Where:** `Modules/Units/Units.lua:56-62` (`LevelDisplay` and its caller).
- **Problem:** for a secret level the text is set but the colour is not, so
  the previous unit's difficulty colour stays.
- **Fix:** reset to a neutral colour for secret levels.
- **Changes:** secret levels show in white (or a chosen neutral colour).

### 1.20 Saved values for removed config keys are never dropped — low
- **Where:** `Core/Overrides.lua:128` (`Fits`); `tests/overrides_test.lua`
  ("new key kept") pins it.
- **Problem:** a saved value whose key no longer exists in the code's defaults
  is kept, applied and shown in the options panel (labelled from its key name)
  as long as its parent table exists.
- **Fix:** accept a value only if its key exists in the defaults.
- **Changes:** stale options disappear from the panel and are removed from
  `StevioUIConfig` at the next login. **Breaks** any intentional "extra key"
  workflow, and **deletes those saved values for good**.

### 1.21 `ns.RegisterEvent`: one failing handler skips the rest — low
- **Where:** `Core/Init.lua:31-35` (dispatcher).
- **Problem:** handlers run without protection. One error stops the remaining
  handlers for that event, for example the target auras refresh before keyboard
  healing's `UpdateCursorState` on `PLAYER_TARGET_CHANGED`.
- **Fix:** call each handler through `ns.SafeCall`.
- **Changes:** errors stay isolated. There is a small per-event cost (one
  `pcall` per handler).

## 2. Refactors skipped because they change timing or behaviour

### 2.1 Chat re-hides Blizzard's chat on every message
- **Where:** `Modules/Chat/Chat.lua:70` → `Modules/Chat/Blizzard.lua:101`
  (`ApplyBlizzardVisibility`).
- **Problem:** every chat event (Trade and General included) loops over all
  Blizzard chat frames, tabs and edit boxes.
- **Why it wasn't done:** `SetAlpha` is guarded by a hook, but `EnableMouse` is
  not. The repeated call is what switches mouse input off again whenever
  Blizzard switches it back on.
- **Fix:** hook `EnableMouse` the same way `SetAlpha` is hooked, then call
  `ApplyBlizzardVisibility` only when the visibility changes.
- **Changes:** less work per chat message. Risk: if a Blizzard path re-enables
  mouse input without going through `EnableMouse`, hidden chat frames would
  catch clicks again.

### 2.2 Group cells: one update pass per roster change
- **Where:** `Modules/Group/Cell.lua:120` (`GROUP_ROSTER_UPDATE`).
- **Problem:** every cell with a unit runs `UpdateAll` and schedules its own
  next-frame timer. That's up to 40 timers and 80 updates per roster event.
- **Why it wasn't done:** a single handler registered through the dispatcher
  runs at a different point in the frame than each cell's own handler, most
  likely after the secure headers have reassigned units. So it would update a
  different set of cells.
- **Changes:** fewer updates during raid roster changes. Cells might show
  outdated data for one frame in some orders; this needs testing in a 40-player
  raid.

### 2.3 Shared aura container builder
- **Where:** `Modules/Units/TargetAuras.lua:14`, `Modules/Group/Cell.lua:179`.
- **Why it wasn't done:** the two setups differ in parent, sizing, mouse
  handling and the order of `SetUnit` / `SetEnabled`, all on Blizzard's
  `CustomAuraContainerTemplate`. A shared builder would reorder calls on a
  template whose internals can't be checked here.
- **Changes:** less duplicate code. Risk: auras not showing or not updating if
  the template depends on the call order.

## 3. Renames and moves that would break saved settings

### 3.1 Config key `actionbars` vs layout/profile key `actionBars`
- **Where:** `Modules/ActionBars/Config.lua` (`ns.config.actionbars`),
  `Core/Layout.lua` and `Modules/Settings/Profile.lua` (`actionBars`).
- **Changes if renamed:** every saved override under `config/actionbars/...` in
  `StevioUIConfig.values` stops applying, so all action bar options go back to
  the defaults. **Needs a migration** that renames the saved paths at
  `ADDON_LOADED`.

### 3.2 `label` fields of the fixed chat channels
- **Where:** `Modules/Chat/Config.lua` (main, party, raid, guild, say, …);
  `Modules/Chat/Shared.lua` (`C.Label`) uses its own translations for these.
- **Problem:** the field is shown in the options panel, but changing it has no
  effect for these channels.
- **Changes if removed:** the option disappears from the panel. The labels
  stored in `StevioUIChatHistory` stay but are unused. Alternatively, make
  `C.Label` use a changed label: then the setting works, but breaks the German
  translation for anyone who changed it.

### 3.3 `notch.colors.restedAlpha` is a number among the colours
- **Where:** `Modules/Notch/Config.lua:53`.
- **Changes if moved:** a saved override at `config/notch/colors/restedAlpha`
  stops applying (back to 0.4). Needs a migration of that one path.

### 3.4 Group cell width is copied into the layout
- **Where:** `Core/Layout.lua:12` (a local `groupHalfWidth = 331`) copies the
  cell width from `Modules/Group/Cell.xml` (80) and `config.group.spacing` (3).
- **Problem:** changing `spacing` in the options panel doesn't move the target
  auras and the focus frame, which are placed relative to the grid's half width.
- **Changes if derived:**
  - `Core/Layout.lua` loads before the group config, so the value would have
    to be worked out later, when positions are applied.
  - Saved overrides of `layout/targetAuras/x` and `layout/focus/x` are absolute
    numbers. They would no longer follow a changed spacing, so they would need
    to become offsets.

### 3.5 The three action bar lists
- **Where:** `Modules/ActionBars/Config.lua` (`bars`),
  `Modules/ActionBars/ActionBars.lua:102` (`barSystemIndices`), `Core/Layout.lua`
  (`actionBars`).
- **Problem:** changing `bars` in the options panel only changes which bars
  get styled. Placement stays fixed to the main bar and bars 2 and 3.
- **Changes if made one list:** the options panel shows a different structure.
  Saved overrides for `bars` or `actionBars` need a migration.

## 4. Inconsistencies that may be intended

These need a decision before anything changes.

- **`/sui loot` and `/sui notch` exist only while their module is on**
  (`Modules/LootTicker/LootTicker.lua:405`, `Modules/Notch/Notch.lua:434`).
  `/sui test` and `/sui qj` are registered at load and always exist.
  - Option a: register all of them at load. Then the `/sui` list always shows
    them, and they do nothing (or print a hint) while the module is off.
  - Option b: register all of them in `OnEnable`. Then `test` and `qj`
    disappear from the list while their module is off.
- **Quickjump above 81 and 135 targets**
  (`Modules/Accessibility/Labels.lua`, `Generate`):
  - From target 82 on, the extra first letters are mixed in, so every label in
    that window changes as it grows past 81.
  - Above 135 targets the rest get no label.
  - Changing either changes the labels people have learned for big windows.
- **Party frame hidden by Units, raid frames by Group**
  (`Modules/Units/Units.lua:231`, `Modules/Group/Group.lua:127`). Moving it
  into Group would show Blizzard's party frame when only Group is off, or hide
  it when only Units is off.
- **`/sui qj` changes state** (`Modules/Accessibility/Panels.lua`,
  `DialogSources.lua`): its `IsOpen` checks reset the active panel or popup
  request, so running the diagnostic can change which window gets labels next.
  Fixing it means a side-effect-free `IsOpen` for the dump. Labels would then
  stay where they were after `/sui qj`.
- **`FCF_OpenTemporaryWindow` hook without a guard**
  (`Modules/Chat/Blizzard.lua:176`): if a client lacks this global, the chat
  module errors before it sets up its notices. With a guard, the chat would
  load without the hook, and temporary windows (pet battle log, …) would then
  not be hidden.
