# Compass (issue 57) – spec

Status: **agreed with the author, not implemented yet.** API names are checked
against Blizzard's live UI source (`Blizzard_APIDocumentationGenerated`); that
they exist in the WoW Forever client (interface 16001) still needs a check in
game.

## Idea

A horizontal compass like the one in Elder Scrolls Online. It shows the
directions and the markers that lie ahead of you. The marker in the centre
also shows its name and distance.

The compass is a black band hanging right below the notch, as if the notch
grew downward. Its centre line is under the middle of the notch.

```
        ██████ notch ██████
  ██ NW  ·  ◆  N  ★  ·  NE ██
  ██         Grimfang 124 m██
```

## Markers

| Marker | Source (API) |
| --- | --- |
| Your map pin (Ctrl+click on the world map) | `C_Map.GetUserWaypoint()` |
| Tracked quest: objective area or next step (portal, flight path, ...) | `C_SuperTrack.GetSuperTrackedQuestID()`, `C_QuestLog.GetNextWaypoint()` |
| Other quests in the zone | `C_QuestLog.GetQuestsOnMap(mapID)` |
| Rares, treasures, events (the minimap's star and chest icons) | `C_VignetteInfo.GetVignettes()`, `C_VignetteInfo.GetVignettePosition()` |
| Group members, in class colour | `UnitPosition()` |
| Your corpse while you're a ghost | `C_DeathInfo.GetCorpseMapPosition()` |

Not shown: herb and ore nodes, NPC dots, quest givers' "!" and tracked
vendors/trainers. The minimap draws them itself and no API gives addons their
positions. Learning node spots the way GatherMate does was considered and
dropped.

Icons are Blizzard's own map atlases (the vignette's `atlasName`, the quest
and pin icons of the world map), so they look the same as on the minimap.

## Behaviour

- **Facing:** `GetPlayerFacing()`. There is no API for the camera's own
  direction, so the compass follows the **character**, like a rotating
  minimap. While you hold the right mouse button, the character and the camera
  face the same way.
- **Arc:** the band covers 180° (`fov`). A marker at its end is 90° to your left
  or right. Markers outside the arc are hidden (ESO style).
- **Range:** no limit. Everything in the current zone is shown
  (`maxDistance = nil`).
- **Focus:** among the markers within ±5° (`focusAngle`) of the centre, the
  tracked quest and the map pin win, then the one closest to the centre line.
  Only that marker gets a label under the band: name and distance. No other
  marker shows a distance.
- **Distance:** in yards, the game's unit, labelled "m" (`124 m`), as most
  addons do. It is computed with `C_Map.GetWorldPosFromMapPos()`.
- **Look:**
  - N is highlighted in colour; E, S, W, NE, ... are white.
  - Small ticks every 15° between the letters.
  - Letters, ticks and markers fade towards the ends of the band.
  - Markers further away are drawn smaller and dimmer than close ones. Tracked
    quest and pin are always full size.
- **Mouse:** none. The band lets clicks and camera dragging pass through.
- **Notch island:** when the island opens, it covers the compass. The compass
  comes back when the island closes.
- **Instances:** inside dungeons, raids, battlegrounds and arenas the game
  returns no facing or positions to addons. The compass hides there, and the
  notch looks like a plain notch.
- **No notch** (external display, windowed): the band hangs from the top edge
  at the same place, using the notch module's `fallback` size.
- **Updates:** the facing is read every frame, which is cheap. The marker list
  is rebuilt on events (zone change, quest, super-track, vignette, waypoint and
  group changes, death and resurrection) and every 0.5 s for moving things
  (group members, the player's own position for distances).

## Module

`Modules/Compass/`:

- `Config.lua`: `enabled`, `fov = 180`, `focusAngle = 5`, `maxDistance`,
  band width (e.g. 480 px) and height, tick step (15°), fade and
  distance-dimming strength, colours (background like the notch's black, N
  highlight), and one switch per marker kind.
- `Geometry.lua`: pure functions, unit-tested like `Minimap/Geometry.lua`.
  They cover the bearing from the player to a point, the angle relative to the
  facing, the x on the band (or hidden), the distance, the fade and size
  factors and the focus pick.
- `Markers.lua`: collects the markers from the APIs above into a plain list
  (kind, name, atlas, world position, priority).
- `Compass.lua`: the frame below the notch, drawing, events, and hiding while
  the island is open (a small hook into the notch module) and in instances.

Its position comes from the notch (anchored below it), so `Core/Layout.lua`
only needs an optional offset (`compass`).

Tests: `tests/compass_geometry_test.lua`. A test also pins the API and
atlas names the module uses (see the check-the-source rule).
