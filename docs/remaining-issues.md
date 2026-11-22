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
  points (WoW Forever keeps them on the target; detected through Blizzard's
  `TargetBoundComboPointBarMixin`). Check that `COMBO_TARGET_CHANGED` exists
  there (registering an unknown event would error at login).
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
- Notes: sessions open at logout end at the logout; after a `/reload` in the
  same group they continue, after a later login alone the rating popup shows.
- Settings: `GxApi` and the resolution CVars are no longer set from the
  profile; saved overrides of them are dropped at login.
