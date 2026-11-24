# Settings window (#92)

stevio-ui has its own settings window instead of a page tree in Blizzard's
Options → AddOns. It opens with `/sui config`, `/sui` alone, the gear in the
notch island and the button on stevio-ui's slim entry in Blizzard's menu. The
window is 1150 × 860 by default, can be moved (title bar) and resized (bottom
right corner), remembers both (`StevioUIConfig.settingsWindow`), and closes
with Escape. Every change is saved account-wide right away
(`StevioUIConfig`, see `Core/Overrides.lua`).

## Layout

- **Title bar**: "Settings", `/sui config`, close.
- **Navigation** (left, 260 wide): search (Ctrl/Cmd+F), Start, Appearance, the
  module pages by category (combat & units, bars & auras, communication, loot,
  map & travel), then System (keybindings, graphics & game, profile & backup).
  A pill counts the values of a page that differ from the code; modules that
  are off are dimmed and marked "off". Version and "saved account-wide" at the
  bottom.
- **Reload bar** (bottom): as soon as values that only take effect after a
  reload were changed in this session, "N changes take effect after a reload",
  their names (several of one module as "Chat (2)"), "Later" (hides it until the
  next change) and "Reload now". A value changed back to where it started drops
  out again. Keys and game settings are applied at once and never show here.

## Pages

| Page | File | What it shows |
| --- | --- | --- |
| Start | `PageStart.lua` | Welcome, the two colour themes as cards, a tile per module (switch, changes, filter all/changed/off), profile and backup status, the `/sui` commands (`Help.lua`). There is no CHANGELOG, so "What's new" is left out. |
| Module / Appearance | `PageModule.lua` | Breadcrumb, title, description, "Active" switch, ⋯ menu (reset module, asks first), chips that jump to the sections, the sections of `Pages.lua`, "Advanced" folded at the end. The group grid has a live preview (four cells from `Modules/Group/Preview.lua`, rebuilt when its config changes) and "Try in the game" buttons (`/sui test 5|10|25|40`); rolls and the loot ticker have their test commands. Appearance has the theme cards, the active theme's colours, text and edge badges. |
| Search | `PageSearch.lua` | Shown while the search box holds text: "N matches for “x” in M areas", a chip per module, matches grouped by module with their section, the term highlighted, the control right in the row and a link to the page. Advanced settings are found too and marked. Escape empties the search. |
| Keybindings | `PageBindings.lua` | Profile and own bindings by Blizzard's categories; search, filters all/own/conflicts/not bound, dot colour profile vs own. "+" waits for a key ("Press a key … Esc cancels"); a key chip can be bound anew or removed; an own key that the profile gives to another action shows a warning under the row. Keyboard healing's arrow keys are listed but locked. "Export as profile" runs `/sui export`. |
| Graphics & game | `PageCVars.lua` | The profile's CVars with names, explanations and controls from `CVarInfo.lua`, by group (graphics, game, accessibility, other); technical names on request; own values with "Profile: x · Back to the profile". "Same values in raids" (`settings.mirrorRaidCVars`, on by default) makes the 28 `RAID…` variants follow their base CVar; off, they get their own "Raid" group. |
| Profile & backup | `PageProfileBackup.lua` | Profile card (agreed / last applied, bars, keys, game settings, apply again, what is set), backup card (date, contents, restore with a question), your deviations (options, keys, CVars, each with a reset), sharing settings as text, the profile module's own options (console key) and "Reset everything" (the old `STEVIOUI_RESET_CONFIG` dialog; the backup stays). |

## Files

Pure logic, tested in `tests/` without the game:

| File | Purpose | Test |
| --- | --- | --- |
| `Pages.lua` | Modules in sidebar order: category, description, sections (title, subtitle), Layout.lua positions, test commands, preview | `settings_pages_test.lua` |
| `Meta.lua` | Metadata per config path, derived controls, the items of a page, formatting | `settings_meta_test.lua` |
| `Labels.lua` | Labels and help texts per key and per path | `settings_labels_test.lua`, `settings_meta_test.lua` |
| `Search.lua` | The search | `settings_search_test.lua` |
| `Keys.lua` | Key names, filters, conflicts, locked keys | `settings_keys_test.lua` |
| `CVarInfo.lua` | CVar names, groups, controls, raid mirroring | `settings_cvars_test.lua` |
| `Deviations.lua` | The deviations list | `settings_deviations_test.lua` |
| `Share.lua` | Serializer, Base64, export and import checks | `settings_share_test.lua` |
| `Help.lua` | The `/sui` commands with explanations | `settings_help_test.lua` |

In-game parts: `UI.lua` (writing values and overrides, the reload list, cached
items), `Controls.lua` (controls and the setting row), `Window.lua` (frame,
navigation, reload bar, page routing, notch button), the `Page*.lua` files and
`Panel.lua` (Blizzard's slim entry, the reset dialog). `tests/settings_window_test.lua`
builds and renders all of them with faked frames, changes values through the
rows and checks the results; looks and behaviour still need the game.

## Metadata

`ns.ConfigMeta` in `Meta.lua` describes a value by its path: below
`ns.config` without the `config` root, below `ns.layout` with a `layout.`
prefix, joined by dots, list entries as `*`:

```lua
M["group.nameFontSize"] = { section = "layout", control = "slider", min = 8, max = 16, step = 1, unit = "px" }
M["units.frames.*.width"] = { section = "frames", control = "slider", min = 60, max = 400, step = 2, unit = "px" }
M["group.dispellableFilter"] = { advanced = true }
```

Fields: `section` (a section key of the page, inherited by everything below a
table), `control` (`switch`, `slider`, `stepper`, `segmented`, `select`,
`color`, `text`, `list`, `flags` for a table of switches, `position` for a
Layout.lua point), `min`/`max`/`step`, `unit` (`px`, `%`, `s`), `percent`
(a 0–1 value shown in %), `options` (`{ { value, { english, german } } }`),
`advanced` (only under "Advanced", inherited), `live` (takes effect at once, no
reload bar) and `hidden` (never shown).

Without metadata the control is derived: boolean → switch, colour (3–4
numbers 0–1) → colour, number → stepper, text → text, list → list, list of
tables → one group per entry, a table with point/x/y → position, other table →
its values with the table's name above them. A value without a section goes
into the page's first section, Layout.lua positions into "Position",
technical values (filter strings, thresholds, poll intervals, the chat's event
tables) are `advanced`.

Help texts live in `Labels.lua`: the 3rd and 4th entry of a key's label, or a
path entry in `pathLabels` (`"units.castBar.gap"`, `"layout.group"`,
`"style.themes.*.panel"`) where the key alone is too vague. Every visible,
non-advanced setting needs one (the meta test lists those without).

## Adding a module

1. Its `Config.lua` and positions in `Core/Layout.lua` as usual.
2. An entry in `Pages.MODULES`: key, `category`, `description` (one sentence,
   English and German), `sections` in page order (`S(key, en, de, subEn,
   subDe)`; add `POSITION` when it places something), `layout` with its
   positions, optionally `tests` (buttons running `/sui` commands) and
   `preview`.
3. Metadata in `Meta.lua` for its values: section, control and range;
   technical ones `advanced`.
4. Labels and help texts in `Labels.lua`.
5. `tests/run.sh`: the meta test names every visible value without help or
   section, metadata for paths that don't exist, and defaults outside their
   range; the pages test checks titles, categories and positions.
6. New `/sui` commands go into `Help.lua` (its test finds missing ones).

## Sharing

"Share settings" turns your overrides into one line: `!SUI1!` followed by the
Base64 of a small serialized table `{ v = 1, values, bindings?, cvars? }`
(keys and game settings only when ticked). The serializer is stevio-ui's own
(tables, strings, numbers, booleans); imported text is parsed, never run.
Base64 comes from `C_EncodingUtil` when the client has it, else from
`Share.lua`; both write standard Base64.

An import checks the prefix and version, decodes, and takes only values whose
path exists in the code, whose kind fits the default (colours with 3 or 4
components between 0 and 1, lists of the same kind of entries), and that
aren't hidden (the profile, the settings module's `enabled`). Keys need a text
key and a command (or `false` for unbound), CVars a valid name, a text value,
not ignored and known to the client. Everything else is skipped and listed in
the preview. "Take over" writes the options as overrides (reload bar), keys
and game settings are applied at once.

## Saved state

- `StevioUIState.consentTime` (new): when the takeover was accepted.
- `StevioUIState.lastApplied` (new): when the profile was last applied.
- `StevioUIState.backup.time` (new): when the backup was taken.

Older saved states have none of them; the profile page then says "unknown".
