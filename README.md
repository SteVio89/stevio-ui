<div align="center">

<img src="Media/Icon.png" alt="stevio-ui" width="128">

# stevio-ui

A minimalist total-conversion UI for **WoW Forever** (interface 16001)

</div>

The goal is to see as much of the game world as possible: everything that
matters sits in one cluster at the bottom centre, everything else stays hidden
until it is needed, and as much as possible can be done from the keyboard.

> **This is an all-or-nothing UI.** On first load it asks for permission to
> overwrite your **keybindings, graphics/interface settings (CVars), action bars
> and Edit Mode layout** account-wide. Your previous settings are backed up first;
> `/sui restore` brings them back and disables the addon. Declining disables the
> addon right away.

## Features

- **Unit frames** – player, target, pet and target-of-target as slim bars with
  own cast bars and combo point segments.
- **Group grid** – up to 40 players; class colours, the name as a faint
  watermark, resource, incoming heals and absorb shields, dispellable debuffs,
  your own HoTs and buffs along the top, role, range, death, aggro and target highlight.
- **Keyboard healing** – the arrow keys move a cursor over the group grid and set
  your real target, so heals can be cast without a mouse. Works in combat.
- **Quickjump** – two-letter labels on dialogs, gossip, quest windows, flight
  maps and other panels; type the letters to click. Shift on the first letter
  right-clicks.
- **Action bars, menu and bags** – Blizzard's secure buttons, stripped down and
  placed via a dedicated Edit Mode layout named `stevio-ui`.
- **Minimap** – square, borderless, mouse-wheel zoom, size derived from the
  screen.
- **Channel chat and objective tracker** – chat is organised in channels like
  Slack/Teams, with a persistent per-character history and a date line before
  the first message of each day (`dateFormat`):
  - party, raid and instance; guild (with officer chat, Guild Discord and the
    message of the day); one channel per community stream; one per whisper
    partner; say (including emotes such as `/e` and `/dance`), yell and the chat
    channels listed in `publicChannels`, e.g. General and Trade;
  - "Other" collects every other chat channel read-only, each line naming its
    channel before the sender;
  - "NPC" collects NPC and boss speech, "Loot & Progress" loot (also other
    players'), money, currencies, XP, honor, reputation, skill-ups,
    achievements and level-ups, and "System" everything else Blizzard's chat
    shows (players coming online or going offline, AFK replies, channel
    notices, ...) together with addon output: `/sui` replies open that
    channel, other addons' output only counts as unread. These three are read-only and coloured like Blizzard's chat.

  `x` deletes any channel but guild with its history. Say, emotes, yell, chat
  and community channels, NPC, Loot & Progress and System only count as unread and don't pop
  up the chat. Hidden by default, toggled by key, with edge
  badges that light up on new whispers, party or guild messages; it opens on
  the channel with the latest activity. Slash commands typed into the channel
  view's own input run there (`/w Bob hi`, `/p`, `/dance`, `/sui`, ...);
  protected ones such as `/cast` or `/target`, which Blizzard only runs from its
  own input, are handed to that input pre-filled, and Enter runs them.
  Blizzard's chat stays hidden; only its
  input box (Enter, slash commands) is used, shown right under the channel view
  and hidden together with it. Blizzard's chat toasts (e.g. a Battle.net friend
  coming online) pop up right under that input box.
- **Loot ticker** – your last 24 looted items, currencies and gold above the
  bags, with icon, name in quality colour and count; gold is shown with coin
  icons on one line. Other group members' loot from rare quality up
  (`groupMinQuality`) appears as "Name: item" with the name in class colour,
  and every group loot roll message (selections, rolls, winners) is listed
  too; lines about other players are dimmed. New loot enters at the bottom
  and pushes older lines up; when all rows are taken the oldest drops out,
  and every line fades out slowly after a few seconds. Looting more of
  something still listed adds to that line.
- **Quest rewards** – marks the choice with the highest vendor value.
- **Auras** – Blizzard's own, compacted to two rows of buffs and two rows of debuffs in the top right corner, with the objective tracker below them. Blizzard's damage meter is turned
  off (`damageMeterEnabled` in the profile); its slot stays free.

## Assumptions

stevio-ui is built for one setup and is configured in code, not through options:

- **German keyboard layout** – Quickjump letters and some keys are chosen for
  it (`Y`/`Z` are swapped compared to US).
- **UI scale around 0.8** (≈ 960 UI units screen height). At higher scales the
  40-player grid overlaps the free damage meter slot at the bottom left.
- **The bundled keybinding and graphics profile is the author's own.** Change
  `Modules/Settings/Profile.lua` (or generate your own with `/sui export`) to make
  it yours.

## Installation

Install from CurseForge, or copy the `stevio-ui` folder into the
`Interface/AddOns/` folder of your WoW Forever client. Accept the dialog on
first login.

## Keys

| Key | Action |
| --- | --- |
| Arrow keys | Move the group grid cursor (sets your target) |
| `,` | Quickjump: show labels / next window |
| `J` / `K` | Quickjump: scroll |
| `.` | Toggle chat |
| *(unbound)* | Chat: write message, next / previous channel (`Tab` / `Shift-Tab` in the input) |
| `-` | Toggle objective tracker |

## Commands

| Command | Action |
| --- | --- |
| `/sui test 5\|10\|25\|40` | Preview the group grid |
| `/sui loot` | Preview the loot ticker with a few items from your bags |
| `/sui chat` | List the chat channels with message and unread counts |
| `/sui qj` | List the current Quickjump targets |
| `/sui export` | Export your current bindings and settings as a profile |
| `/sui apply` | Re-apply the profile |
| `/sui restore` | Restore the settings from before stevio-ui and disable it |

## Configuration

Every module has a `Config.lua` (`enabled = false` turns it off), the global
look lives in `Core/Config.lua` and all positions in `Core/Layout.lua`. Edit and
`/reload`.

## License

[MIT](LICENSE)
