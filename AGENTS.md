# AGENTS.md — PaTiRota

**Read the suite rules first: [`../../PaTiAdmin/AGENTS.md`](../../PaTiAdmin/AGENTS.md).** They apply here in full.
Addon facts: `../../PaTiAdmin/docs/ARCHITECTURE.md` · open issues: `../../PaTiAdmin/docs/FOLLOW_UPS.md`.

## This addon
- Purpose: **your own skill priority** — up to ten slots in your order, their cooldown states, the next ready skill
  highlighted, one fixed cast button per slot. **Never casts by itself.** Never: auto-cast, cast sequences, a "next
  skill" button whose spell changes, spell changes in combat, rotation rules/DSL, resource/buff engines, talent logic.
- Files: `Logic.lua` (settings, slots, cooldown states, recommendation, slot attributes — pure, tested) ·
  `SpellBook.lua` (spell/spellbook/cooldown/cursor adapters, guarded; small copy of PaTiHeal's) · `Settings.lua`
  (settings modal, slot editing) · `PaTiRota.lua` (window, secure slot buttons, painting, commands, events) ·
  `Bindings.xml` · `Locales/` · `Shared/` (synced, never edit).
- SavedVariables: `PaTiRotaDB` (per character), schema 1 — see `Logic.DEFAULTS`; `slots` = 10 spell IDs, 0 = empty.
  Any shape change: bump `Logic.SCHEMA`, add a migration step and a test.
- Secure: `PaTiRotaSlot1..10` (SecureActionButtonTemplate), slot N = button N (key bindings point at them). Only
  `applySlots()` writes their attributes (`Logic.SlotAttributes`), position and visibility — out of combat; in combat
  `slotsPending` waits for PLAYER_REGEN_ENABLED. Painting (texts, icons, border) uses the bound spell of each button.
- Slash: `/prota`, `/patirota`.

## Checks
`bash ../../PaTiAdmin/tools/check.sh .` before every commit. Manual WoW tests: `INGAME_TESTING.md`.
