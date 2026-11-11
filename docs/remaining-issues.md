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
- `/sui loot`, `/sui notch`, `/sui test` and `/sui qj` say the module is off
  while it is; `/sui qj` no longer changes which window gets labels next.
- Quickjump in windows with more than 81 targets: the first 81 labels stay as
  they were, and later targets get the extra first letters.

### Action sets (#33)
- Switching to a set that can't place everything lists each missing action with
  its slot and name instead of only a count. `/sui bars missing` lists them
  again, `/sui bars forget` drops them; the next switch then reports nothing.
- Spells a talent replaces (e.g. a healing spell whose slot shows the upgraded
  version) are placed via the spell they replace instead of being reported as
  missing. Check that such a slot shows and casts the upgraded spell.
