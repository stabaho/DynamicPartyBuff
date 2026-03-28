# DynamicPartyBuff

> A **World of Warcraft Classic TBC** addon that dynamically buffs your party members out of combat using a single smart button. The button automatically detects who needs a buff, picks the correct spell based on your class and priority, and updates in real time.

---

## Features

- **One-button buffing** - Click once to cast the highest-priority missing buff on the correct target
- **Smart targeting** - Auto-selects party members who need buffs; no manual targeting required
- **Class-aware** - Only shows spells your class can cast (Druid, Priest, Mage, Paladin, Warlock supported)
- **Priority system** - Buffs are applied in a configurable priority order (group buffs first)
- **Real-time scanning** - Updates instantly when auras change, party composition changes, or you leave combat
- **UNIT_AURA debounce** - Rapid aura events are coalesced into a single scan to prevent frame hitching
- **Out-of-combat only** - Fully respects WoW's combat lockdown; safe to use
- **Draggable button** - Reposition the button anywhere on screen by dragging it
- **Saved position** - Button remembers its location across sessions via `SavedVariables`
- **Cooldown display** - Shows real spell cooldown swipe animation on the button
- **Rich tooltip** - Hover to see the spell name, rank, and target; left-click to cast
- **Debug mode** - `/dpb debug` toggles verbose scan output to chat for troubleshooting
- **Event debug mode** - `/dpb debugevents` logs every registered event to chat
- **Slash commands** - Toggle, reset position, hide/show, debug, and help via `/dpb`
- **Startup validation** - Warns in chat if any spell table entries have missing fields
- **Clean namespace** - All state stored under the `DPB` table; no loose globals

---

## Supported Classes & Buffs

| Class | Buffs |
|---------|-------|
| Druid | Gift of the Wild / Mark of the Wild, Thorns |
| Priest | Prayer of Fortitude / Power Word: Fortitude, Prayer of Shadow Protection, Divine Spirit |
| Mage | Arcane Brilliance / Arcane Intellect |
| Paladin | Greater Blessing of Kings, Might, Wisdom, Salvation (casters only) |
| Warlock | Detect Invisibility |

> Group buffs (Gift of the Wild, Prayer of Fortitude, etc.) are prioritized and cast party-wide. Single-target fallbacks are used automatically when you don't have the group rank.

> **Paladin note:** Greater Blessing of Salvation is restricted to casters (Priest, Mage, Warlock, Hunter) and set to low priority, since it reduces threat generation and should not be cast on tanks without consent.

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
| `/dpb debug` | Toggles verbose scan output to chat (for troubleshooting) |
| `/dpb debugevents` | Toggles per-event logging to chat |
| `/dpb help` | Shows all available slash commands |

---

## How It Works

1. On login, the addon reads your class and sorts the spell table by priority
2. After each combat exit, aura change, or party roster change, it scans all party members
3. For each spell in priority order, it checks if any eligible party member is missing that buff
4. The button is updated with the next spell to cast and who it targets
5. One click casts the buff using WoW's secure action system (no taint risk)
6. The scan repeats until all buffs are up, then the button shows "All Up!"

---

## Changelog

### v1.6.0 - Code Review Release
- **[R1]** `GetPartyUnits()` now prefers `GetNumGroupMembers()` (correct TBC API) and falls back to the deprecated `GetNumPartyMembers()` — fixes silent party-scan failure on some clients
- **[R2]** `UNIT_AURA` events are now debounced (0.2 s) via `ScheduleScan()` — prevents frame hitching when many aura events fire rapidly in combat or on login
- **[R3]** `DeferredScan()` OnUpdate fallback reuses a single persistent frame instead of creating a new one on each call — eliminates multiple simultaneous `ScanBuffs()` callbacks
- **[R4]** `PE()` diagnostic helper is now gated on `DPB.debug` — diagnostic output no longer floods chat for non-debug users
- **[R5]** `PLAYER_ENTERING_WORLD` no longer unconditionally overwrites `playerClass` — class is set at `PLAYER_LOGIN` and only re-fetched as a safety net if still nil
- **[R6]** Removed load-time `print()` debug statements from `Button.lua` and `Spells.lua` that were spamming red text to chat on every login
- **[R7]** `Greater Blessing of Salvation` restricted to casters only (`PRIEST`, `MAGE`, `WARLOCK`, `HUNTER`) and moved to priority 20 — prevents accidentally casting it on tanks
- **[Fix D]** `UpdateButton()` All Up branch now correctly calls `SetButtonReady(true)` — previously called `false`, which dimmed the button and overwrote the icon immediately after setting it

### v1.5.x - Diagnostic Build Series
- Added full `[DPB-DIAG]` diagnostic logging throughout scan and event paths
- Fixed syntax error in `OnEvent` multi-line `elseif` chain that prevented the addon from loading
- Fixed `.toc` load order (was `Core → Button`; corrected to `Spells → Button → Core`)
- Added `C_Timer.After(0, ...)` deferred scan on `PLAYER_ENTERING_WORLD` with `OnUpdate` fallback
- Added `/dpb debugevents` slash command to toggle per-event logging
- Wired `DPB.debugEvents` flag into `OnEvent` handler

### v1.4.0 - Senior Review Release
- **Namespace cleanup**: `DPB_Spells` global renamed to `DPB.Spells` — all state lives inside the `DPB` table, reducing global pollution
- **Debug mode**: `/dpb debug` toggles `DPB.debug` flag; when enabled, `ScanBuffs()` prints each decision to chat (class, units scanned, spells skipped/found)
- **`/dpb help`**: New slash command that lists all available `/dpb` commands in chat
- **Skipped spell logging**: When debug is on, spells not in the player's spellbook are explicitly noted in output
- **`DPBPrint()` helper**: Centralized colored chat print function used consistently throughout Core.lua

### v1.3.0 - Code Review Release
- **[R1]** Removed redundant `table.sort()` from `ScanBuffs()` — spell table is now sorted once at `PLAYER_LOGIN`
- **[R2]** `playerClass` is set only at `PLAYER_LOGIN` — no longer incorrectly re-set on zone transitions
- **[R3]** `UNIT_AURA` handler uses `unit:match("^party")` anchored to start of string for precision
- **[R4]** Added `ValidateSpells()` — warns in chat at startup if any spell entry has missing required fields
- **[R5]** `ScanBuffs()` now safely guards against a nil or empty `DPB.Spells` table
- **[R6]** Cooldown frame is now wired to actual spell cooldown via `GetSpellCooldown()` — swipe animation works
- **[R7]** Spell name label truncation now uses `#string` length and `string.sub()` for safe character capping
- **[R8]** Tooltip shows spell rank from `GetSpellInfo()` for full context
- **[R9]** Tooltip target name has proper nil-guard on `UnitName()` result
- **[R10]** All `buffName` values verified against actual TBC aura names returned by `UnitBuff()`
- **[R11]** Added single-target fallback spells (Mark of the Wild, Arcane Intellect, Power Word: Fortitude)
- **[R12]** Paladin blessing `targetClass` lists audited for TBC accuracy
- Added Warlock `Detect Invisibility` support
- Removed unconditional `button:Show()` at file load to eliminate login flicker

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
