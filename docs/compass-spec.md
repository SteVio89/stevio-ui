# Compass (issue 57) – draft spec

Status: **draft for discussion**, nothing is implemented yet. Questions that
are still open are marked **Q**.

## Idea

A horizontal compass strip like the one in Elder Scrolls Online. It shows the
directions and the markers that lie ahead of you. The marker closest to the
centre of the strip also shows its name and distance.

```
   NW        ·        N        ·        NE
  ───────────┴────────┼────────┴───────────
        ◆           ★ |              ●
                 Rare: Grimfang
                     124 m
```

## What the game lets an addon see

Checked against Blizzard's UI source (`Blizzard_APIDocumentationGenerated`).

**Not available:** most of what the minimap draws. Herb and ore nodes,
tracked NPCs (vendors, trainers, mailboxes), quest-giver "!" marks and the
yellow dots of enemies and NPCs are drawn by the engine, and no API returns
their positions. So the compass **cannot simply mirror the minimap**. It shows
the subset below, which is roughly what ESO's compass shows anyway (quests,
points of interest, group, waypoints).

| Marker | Source (API) | Notes |
| --- | --- | --- |
| N / E / S / W, ticks | `GetPlayerFacing()` | No API for the camera's own direction, so the compass follows the **character** (as a rotating minimap does). While you hold the right mouse button the two are the same. |
| Your map pin (waypoint) | `C_Map.GetUserWaypoint()` | The pin set with Ctrl+click on the world map. |
| Tracked quest | `C_SuperTrack.GetSuperTrackedQuestID()`, `C_QuestLog.GetNextWaypoint()` | Points to the objective area or the next step (portal, flight path, ...). |
| Other quests in the zone | `C_QuestLog.GetQuestsOnMap(mapID)` | Shown smaller and dimmer. |
| Rares, treasures, events | `C_VignetteInfo.GetVignettes()`, `GetVignettePosition()` | The star and chest icons on the minimap; these do work. |
| Zone points of interest | `C_AreaPoiInfo.GetAreaPOIForMap()`, `C_TaxiMap.GetTaxiNodesForMap()` | Events, flight masters. **Q:** wanted, or too much clutter? |
| Group members | `UnitPosition()` | In class colour. |
| Corpse | `C_DeathInfo.GetCorpseMapPosition()` | While you're a ghost. |

Distances come from converting map positions to world positions
(`C_Map.GetWorldPosFromMapPos`). The game's unit is the **yard** (1 yd =
0.914 m). **Q:** show yards labelled "m" like most addons do, convert to real
metres, or label them "yd"?

**Limitation:** inside dungeons, raids, battlegrounds and arenas the game
returns no facing or positions to addons. The compass then hides itself (or
shows only a "–"). **Q:** hide or keep an empty strip?

## Behaviour

- **Field of view:** the strip covers 180° (`fov`), so a marker at its edge
  is 90° to your left or right. Markers outside are not shown (ESO style).
  **Q:** or pin them to the edge as small arrows so you know which way to turn?
- **Focus:** the marker within ±5° (`focusAngle`) of the centre, nearest
  first, gets its name and distance under the strip. Tracked quest and map
  pin win over everything else when both are in the focus range.
- **Distance on markers:** only the focused one shows its distance. **Q:**
  should the tracked quest / map pin always show theirs?
- **Range:** markers further away than `maxDistance` (e.g. 1000 yd) are
  hidden, except the tracked quest and the map pin.
- **Fading:** markers get dimmer towards the edges of the strip.
- **Updates:** the facing is read every frame (cheap); the marker list is
  rebuilt on events (zone change, quest/vignette/waypoint changes) and every
  0.5 s for moving things (group members).
- **Interaction:** none; the strip lets clicks pass through to the world.
  **Q:** hovering a marker for a tooltip would mean it catches the mouse.

## Placement and look

- **Q: where?** The top centre (as in ESO) is where the notch island opens
  when the cursor touches the top edge. Options:
  1. top centre, just below the notch, hidden while the island is open;
  2. bottom centre, above the action bar cluster (keeps "everything that
     matters in one cluster at the bottom");
  3. merged into the notch: the notch itself becomes the compass.
- Look follows the rest of the UI: thin, borderless, dark backdrop with low
  alpha, white letters, N highlighted. Width e.g. 480 px, height ~24 px plus a
  line for the focus label. Position in `Core/Layout.lua` (`compass`).

## Module

`Modules/Compass/` with `Config.lua` (options above: `enabled`, `fov`,
`focusAngle`, `maxDistance`, which marker kinds are shown), `Geometry.lua`
(pure functions: bearing from player to target, angle relative to facing,
x on the strip, distance; unit-tested like `Minimap/Geometry.lua`),
`Markers.lua` (collecting markers from the APIs) and `Compass.lua` (frame,
drawing, events). New tests in `tests/compass_geometry_test.lua`.
