# DynamicPartyBuff

> A **World of Warcraft Classic TBC** addon that dynamically buffs your party members out of combat using a single smart button. The button automatically detects who needs a buff, picks the correct spell based on your class and priority, and updates in real time.

---

## Features

- **One-button buffing** - Click once to cast the highest-priority missing buff on the correct target
- **Smart targeting** - Auto-selects party members who need buffs; no manual targeting required
- **Class-aware** - Only shows spells your class can cast (Druid, Priest, Mage, Paladin, Warlock supported)
- **Priority system** - Buffs are applied in a configurable priority order (group buffs first)
- **Real-time scanning** - Updates instantly when auras change, party composition changes, or you leave combat
- **Out-of-combat only** - Fully respects WoW's combat lockdown; safe to use
- **Draggable button** - Reposition the button anywhere on screen by dragging it
- **Saved position** - Button remembers its location across sessions via `SavedVariables`
- **Cooldown display** - Shows real spell cooldown swipe animation on the button
- **Rich tooltip** - Hover to see the spell name, rank, and target; left-click to cast
- **Slash commands** - Toggle, reset position, hide/show via `/dpb`
- **Startup validation** - Warns in chat if any spell table entries have missing fields

---

## Supported Classes & Buffs

| Class | Buffs |
|---------|-------|
| Druid | Gift of the Wild / Mark of the Wild, Thorns |
| Priest | Prayer of Fortitude / Power Word: Fortitude, Prayer of Shadow Protection, Divine Spirit |
| Mage | Arcane Brilliance / Arcane Intellect |
| Paladin | Greater Blessing of Kings, Might, Wisdom, Salvation |
| Warlock | Detect Invisibility |

> Group buffs (Gift of the Wild, Prayer of Fortitude, etc.) are prioritized and cast party-wide. Single-target fallbacks are used automatically when you don't have the group rank.

---

## Installation

1. Download or clone this repository
2. Place the `DynamicPartyBuff` folder into your WoW addons directory:
   ```
   World of Warcraft/_classic_tbc_/Interface/AddOns/
   ```
3. Launch WoW and enable the addon in the AddOns menu
4. The button appears on screen immediately. Drag it to your preferred position.

---

## Usage

| Action | Result |
|--------|--------|
| **Left-click** | Casts the next needed buff on the correct target |
| **Hover** | Shows tooltip with spell name, rank, and target |
| **Drag** | Repositions the button (out of combat only) |
| `/dpb` | Toggles button visibility |
| `/dpb reset` | Moves button back to default center position |

---

## How It Works

1. On login, the addon reads your class and sorts the spell table by priority
2. After each combat exit, aura change, or party roster change, it scans all party members
3. For each spell in priority order, it checks if any eligible party member is missing that buff
4. The button is updated with the next spell to cast and who it targets
5. One click casts the buff using WoW's secure action system (no taint risk)
6. The scan repeats until all buffs are up, then the button dims and shows "All Up!"

---

## Changelog

### v1.3.0 - Code Review Release
- **[R1]** Removed redundant `table.sort()` from `ScanBuffs()` — spell table is now sorted once at `PLAYER_LOGIN`
- **[R2]** `playerClass` is set only at `PLAYER_LOGIN` — no longer incorrectly re-set on zone transitions
- **[R3]** `UNIT_AURA` handler now uses `unit:match()` instead of `string.find()` for idiomatic Lua
- **[R4]** Added `ValidateSpells()` — warns in chat at startup if any spell entry has missing required fields
- **[R5]** `ScanBuffs()` now safely guards against a nil or empty `DPB_Spells` table
- **[R6]** Cooldown frame is now wired to actual spell cooldown via `GetSpellCooldown()` — swipe animation works
- **[R7]** Spell name label truncation now uses `#string` length and `string.sub()` for safe character capping
- **[R8]** Tooltip shows spell rank from `GetSpellInfo()` for full context
- **[R9]** Tooltip target name has proper nil-guard on `UnitName()` result
- **[R10]** All `buffName` values verified against actual TBC aura names returned by `UnitBuff()`
- **[R11]** Added single-target fallback spells (Mark of the Wild, Arcane Intellect, Power Word: Fortitude)
- **[R12]** Paladin blessing `targetClass` lists audited for TBC accuracy
- Added Warlock `Detect Invisibility` support

### v1.2.0 - Bug Fix Release
- **[Bug 1]** Guard `DPB:SetButtonReady()` call so it doesn't crash before `Button.lua` loads
- **[Bug 2]** Merged `PLAYER_LOGIN` handling so `RestorePosition()` fires before `ScanBuffs()`
- **[Bug 3]** Replaced deprecated `GetNumPartyMembers()` with `GetNumGroupMembers()` (TBC API)
- **[Bug 4]** Group buffs no longer set a `unit` attribute — the spell's AoE handles targeting
- **[Bug 5]** `SavePosition()` uses pixel math instead of `GetPoint(1)` to avoid stale anchor data

### v1.1.0
- Added `SavedVariables` position persistence
- Button position saved across sessions

### v1.0.0
- Initial release
- Dynamic buff button with class-aware spell scanning
- Druid, Priest, Mage, Paladin support

---

## Requirements

- World of Warcraft Classic: The Burning Crusade (Interface version 20504)
- Works with all TBC-compatible clients

---

## License

Free to use, modify, and share. Credit appreciated but not required.
