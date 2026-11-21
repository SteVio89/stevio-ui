# Minimap strip (issue 60) – spec

Status: **implemented** in `Modules/Minimap/` (issue 60), not yet tested in
game. Replaces the compass from issues 57 and 58.

## Idea

The compass didn't work out. Instead, a strip of the minimap hangs below the
notch. It shows only what lies **ahead** of the character: the map rotates
with you, and your arrow sits at the bottom centre of the strip. The ','
key switches between this strip and the usual square map in the corner.

```
            ██████ notch ██████
  ░░▒▒▓▓ NW · · N · · NE ▓▓▒▒░░     ← letters along the top edge
  ░░▒▒▓▓   minimap ahead   ▓▓▒▒░░     88 px high, 640 px wide
  ░░▒▒▓▓        ▲          ▓▓▒▒░░     ← you, at the bottom centre
```

## Facts and limits

- WoW has a single `Minimap` frame, and addons can't render a second copy.
  The strip **is** the real minimap, moved and masked. Strip and corner map
  never show at the same time.
- Rotation comes from Blizzard's `rotateMinimap` CVar (set by
  `MinimapClusterMixin:SetRotateMinimap` in the live UI source). With it on,
  "up" on the map is the character's facing.
- The strip's shape comes from `Minimap:SetMaskTexture()` with a mask texture
  shipped in `Media/`: a square map, with only an 88 px band right above its
  centre visible, fading out towards the left and right ends. A mask is a
  file, made by `tools/strip_mask.py` for the default sizes; other `width`,
  `height`, `behind` or `maskFade` values need a new one. The band also clips
  its children (`SetClipsChildren`), so frames on the map (other addons' pins)
  are cut to the strip, and the map too if the game clips it.
- Unverified until tested in game: whether blips at the map's edge (quest
  arrows, group members) are cut by the mask or stick out at the square's
  edge, and whether rotation works inside instances.

## Behaviour

- **Switch:** the new binding `STEVIOUI_TOGGLE_MAP`, default key ','. It
  toggles between the views, and the choice is kept across reloads
  (`StevioUIState`). ',' no longer is the quick-jump leader in the profile;
  quick jumps and the dialog labels keep their binding without a default key
  until quick jumps are removed.
- **Strip view:**
  - Below the notch, centred on it (from the top edge without a notch),
    640 × 88 px, black background like the notch, the map fading into it at
    both ends.
  - Rotates with the character; the map shows the area ahead only.
  - Zoom: the widest one (0). The corner view's zoom is remembered and
    restored when you switch back.
  - Direction letters (N highlighted, E, S, W, NE, ...) and 15° ticks along
    the top edge. A direction sits where its ray from your arrow leaves the
    strip's top edge (x = height · tan(angle)). Directions further than about
    74° to the side, which would leave through the sides, aren't shown.
  - Mouse: none. Clicks and camera dragging pass through.
  - Mail, tracking and the group-finder queue icon are hidden.
  - Notch island: covers the strip while open, as with the compass.
  - Instances: the strip stays and the letters hide, as `GetPlayerFacing()`
    returns nothing there.
- **Edit Mode** sets the rotation from its layout (north up in ours), so the
  strip applies it again after `UpdateSystemSettingRotateMinimap`.
- **Combat:** if something protected sits on the map, the switch waits for
  the end of combat.
- **Corner view:** exactly today's minimap (bottom right, north up, its own
  zoom, icons, mouse wheel). The mark toolbar and vehicle leave button stay
  where they are in both views: they and the tooltip anchor to
  `StevioUI_MinimapCorner`, a stand-in at the corner map's position and size.

## Removed

The compass markers (quests, vignettes, map pin, group, corpse), their focus
labels with names and distances, `Modules/Compass/Markers.lua`, the
compass's tests for these and `docs/compass-spec.md`. They are in git
history.

## Module

The strip is a second view of the minimap, so it lives in `Modules/Minimap/`:

- `Config.lua`: a `strip` table with `width = 640`, `height = 88`, the mask,
  letter and tick settings and colours (from the compass config).
- `Geometry.lua`: adds the pure functions for the letter positions (angle to
  the facing, x on the top edge, fade), unit-tested.
- `Strip.lua`: the band, the letters, moving the map in, and the island and
  instance handling.
- `Minimap.lua`: the switch (`ns.ToggleMinimapView`), the saved view, the
  CVar, zoom, mask, icons and mouse per view.
- `Modules/Compass/` goes away.
