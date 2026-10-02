# PaTiRota

Your own skill priority for World of Warcraft: Forever (Interface 16001). You put up to ten skills in your order;
PaTiRota shows which one is ready next and when the others come back. Every skill has its own fixed button you
can click — **PaTiRota never casts by itself**: no auto-cast, no cast chains, no button that changes its spell in combat.

> Status: in development, not yet released. Not yet tested in game.

```
┌ PaTiRota                         ••• ┐
│ Next: Stormstrike · READY            │
│ [■] Stormstrike           READY      │  ← highlighted (your next skill)
│ [■] Flame Shock           3.2 s      │
│ [■] Lava Lash             6.8 s      │
│ [■] Earth Shock           READY      │
└──────────────────────────────────────┘
```

## Features
- Up to ten skill slots; slot 1 has the highest priority. Type a spell name or ID, or drag a spell from your
  spellbook onto a slot; Up/Down change the order
- Per skill: icon, name, READY / remaining cooldown / GCD / not usable / not learned / unclear
- **Next skill:** the highest-priority skill that is ready is highlighted. During the global cooldown the pick does
  not jump down the list. Nothing ready: the cooldown that ends first. Unreadable cooldowns are never recommended
- **Fixed cast buttons:** clicking a skill casts exactly that skill on your current target — one click, one cast.
  The spell of a button is set out of combat only; in combat the highlight moves, the buttons do not
- Optional key binding per slot in WoW's key binding menu (**ESC > Key Bindings > PaTiRota**); PaTiRota never sets a key
- ••• menu: Settings, Lock, Collapse, Test Mode, Hide. Settings: language, scale, lock, panel opacity, the skill slots.
  Languages: English, Deutsch (others fall back to English)

Not part of PaTiRota (on purpose, V1): rotation rules, resources/buffs/debuffs logic, talent builds, simulations,
anything that decides or casts for you.

## PaTiSuite

This addon is part of the **PaTiSuite** — a collection of small addons for World of Warcraft: Forever.
Each one is installed on its own and works on its own; none of them is needed by another.

- [PaTiSuite](https://github.com/patpaskoch/PaTiSuite) – optional control panel to show and hide the PaTi windows
- [PaTiHeal](https://github.com/patpaskoch/PaTiHeal) – healing: party frames, heal target, click casting, HoTs, dispels
- [PaTiAuras](https://github.com/patpaskoch/PaTiAuras) – buffs, procs, tracking, group buffs and weapon imbues
- [PaTiTank](https://github.com/patpaskoch/PaTiTank) – tank HUD and aggro monitor
- **PaTiRota** – your own skill priority with cooldowns and fixed cast buttons *(this addon)*
- [PaTiGroup](https://github.com/patpaskoch/PaTiGroup) – party awareness: tank, healer, roles and the tank's target
- [PaTiLead](https://github.com/patpaskoch/PaTiLead) – lead the group: raid markers, ready check and pull timer
- [PaTiQuest](https://github.com/patpaskoch/PaTiQuest) – selected quest and its objectives
- [PaTiDungeon](https://github.com/patpaskoch/PaTiDungeon) – instance, group and combat status
- [PaTiSocial](https://github.com/patpaskoch/PaTiSocial) – "Party Social": quick emote and message buttons
- [PaTiAlerts](https://github.com/patpaskoch/PaTiAlerts) – one window for open problems

### Goes well with (optional)

- [PaTiAuras](https://github.com/patpaskoch/PaTiAuras) – your buffs, procs and weapon imbues next to your skills
- [PaTiSuite](https://github.com/patpaskoch/PaTiSuite) – shows and hides this window together with the other PaTi windows

## Installation
1. Download the release zip (`PaTiRota-<version>.zip`).
2. Unpack it and copy the folder `PaTiRota` into `World of Warcraft/<client>/Interface/AddOns/`.
3. Start WoW and enable PaTiRota in the AddOns list.

## First steps
- `/prota settings` → put your skills into the slots in your order
- `/prota test` shows example skills

## Commands
`/prota` or `/patirota` — alone or `toggle`: show/hide · `settings` · `test` · `show` · `hide` · `lock` · `unlock` ·
`reset` (position) · `debug` · `version`

The window cannot be shown, hidden or collapsed in combat (it has secure buttons). Slot changes in combat are saved
and applied after combat.

## Known limitations
- Not tested in game yet. Which cooldown API the Forever client answers, and whether it knows the global-cooldown
  reference spell (61304), is unconfirmed — `/prota debug` shows both. Without it, a cooldown up to 1.5 s counts as GCD.
- No AddOns-list icon yet: the PaTiRota artwork (rotation arrows with skill icons) still has to be added
  (`Media/icon.tga`).
- Skills are cast with your highest known rank.

## Development

Architecture, tests and engineering rules of the suite: [PaTiAdmin](https://github.com/patpaskoch/PaTiAdmin). PaTiAdmin is not a WoW addon — players do not install it. The shared UI code (PaTiShared) is already embedded in this addon's `Shared/` folder; there is nothing extra to install.

## License
MIT — see [LICENSE](LICENSE). Copyright (c) 2026 Patrick Koch.
