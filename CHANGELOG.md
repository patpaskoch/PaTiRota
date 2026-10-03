# Changelog

Format: `## [Unreleased]` / `## [x.y.z] - YYYY-MM-DD` with Added, Changed, Fixed, Removed, Known Issues.

## [Unreleased] — 0.1.0
### Added
- Cooldown clock on each skill icon (Settings → "Cooldown clock on icons", on by default): the owner's Forever client
  has only `C_Spell.GetSpellCooldown` (no legacy `GetSpellCooldown`) and keeps its values secret in combat, so the
  text shows "unreadable in combat". WoW's own Cooldown widget may still show them: the values go straight from the
  API into the widget (duration object if the client has it, else `SetCooldown`), PaTiRota never reads them. No
  bypass, no recommendation from secret values, no secure change; a refused call only clears the clock.
  With the clock the icon is no longer greyed out by PaTiRota: the clock's dark swipe shows the cooldown and the icon is
  in full colour again the moment it ends (like a Blizzard action bar; `Logic.IconGrey`). Not learned / not usable stay grey.
- Themes (owner wish 2026-10-03): Settings → Window → Theme — Default (the PaTi look as before), WoForever (warm brown, gold/bronze) or Dracula (dark, purple/pink/cyan accents). Colours only; layout, secure buttons and behaviour are unchanged. Saved per character in this addon (`theme`, unknown values → Default); Restore Defaults returns to Default. PaTiSuite can switch all PaTi windows at once.
- New addon PaTiRota (owner wish 2026-10-02): your own skill priority. Up to ten slots (slot 1 = highest priority),
  each with one spell — typed as name or ID, or dragged from the spellbook; Up/Down reorder; a spell is never in two
  slots. Per skill: icon, name and state READY / remaining cooldown / GCD / not usable / not learned / unclear.
- Recommendation (`Logic.Recommend`, display only): the highest-priority skill that is READY or only on the GCD (so
  the pick never jumps during the global cooldown); nothing ready → the cooldown that ends first; unreadable,
  unusable and unknown skills are never recommended. Highlight + "Next: …" line.
- Cooldown adapter (`SpellBook.lua`): `C_Spell.GetSpellCooldown` or `GetSpellCooldown`, usable state from
  `C_Spell.IsSpellUsable` / `IsUsableSpell`, GCD reference spell 61304 (fallback: a cooldown ≤ 1.5 s counts as GCD).
  Secret values are checked first — unreadable → "unclear", never a false READY.
- Fixed secure cast buttons `PaTiRotaSlot1..10` (SecureActionButtonTemplate, `type1=spell`, `spell1=<name>`): one
  per slot, attributes, position and visibility only out of combat; in combat only the highlight moves. No auto-cast,
  no cast chain, no "next skill" button. Key bindings per slot in WoW's menu (`Bindings.xml`); nothing is bound by
  PaTiRota.
- `PaTiRotaDB`, schema 1: position, locked, collapsed, scale, language, opacity, `slots` (10 spell IDs, 0 = empty;
  broken values and duplicates repaired on login). Restore Defaults keeps your slots and position.
- Settings, Collapse, Test Mode (four example skills), `/prota`, `/patirota` with show, hide, toggle, test, lock,
  unlock, reset, settings, debug, version. English texts, German translation. MIT license.
- Icon (owner-provided 2026-10-02, PaTiSuite style: rotation arrows around a skill list, blue and gold):
  `Media/icon.tga` for the AddOns list, platform images in `assets/`.
### Changed
- Diagnostics (hardening 2026-10-02): errors that are caught so the addon keeps running are no longer silent — the debug command shows the last caught error per source (no chat spam, nothing saved).
### Fixed
- In combat every known skill showed "unclear" and "Next: nothing ready that can be read" (owner, Forever client
  2026-10-03, Blitzschlag 403 / Erdschock 8042). The cooldown adapter took C_Spell.GetSpellCooldown's table as soon as
  one came back — also with unreadable values — and never asked GetSpellCooldown. Now `Logic.ReadCooldown` checks
  each source for readable numbers (secret values are only detected, never read) and the first readable one wins:
  modern, then legacy. If WoW keeps the cooldown secret in every source, the state says "unreadable in combat"
  (tooltip explains; plain "unclear" stays for a missing API) and nothing is recommended from it. `/prota debug`
  shows per slot the source used and per API: call ok, start/duration readable | secret | missing. The fixed
  buttons are unchanged (owner-verified: they cast in combat).
- Hardening: a broken SavedVariables save (not a table, a broken schema or scale) no longer breaks the login; only the broken value is replaced, every valid setting (also `false`) stays, and the migration is idempotent (tests/robustness_spec.lua).
### Known Issues
- Not tested in game yet (`INGAME_TESTING.md`): cooldown API, GCD reference, secure casting, key bindings on hidden
  buttons and drag & drop from the spellbook are unconfirmed in the Forever client.
