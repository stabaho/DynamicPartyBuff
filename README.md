# DynamicPartyBuff

> A **World of Warcraft Classic TBC** addon that dynamically buffs your party members out of combat using a single smart button. The button automatically detects who needs a buff, picks the correct spell based on your class and priority, and updates in real time.

---

## Features

- **One-button buffing** — Click once to cast the highest-priority missing buff on the correct target
- **Smart targeting** — Auto-selects party members who need buffs; no manual targeting required
- **Class-aware** — Only shows spells your class can cast (Druid, Priest, Mage, Paladin supported)
- **Priority system** — Buffs are applied in a configurable priority order (group buffs first)
- **Real-time scanning** — Updates instantly when auras change, party composition changes, or you leave combat
- **Out-of-combat only** — Fully respects WoW's combat lockdown; safe to use
- **Draggable button** — Reposition the button anywhere on screen by dragging it
- **Saved position** — Button remembers its location across sessions via `SavedVariables`
- **Tooltip** — Hover to see what spell will be cast and on whom
- **Slash commands** — Toggle, reset position, hide/show via `/dpb`

---

## Installation

1. Download or clone this repository
2. Copy the `DynamicPartyBuff` folder into:
   ```
   World of Warcraft/_classic_tbc_/Interface/AddOns/
   ```
3. Launch WoW and enable the addon in the **AddOns** menu on the character select screen
4. Log in — the button appears at your last saved position and begins scanning immediately

---

## File Structure

```
DynamicPartyBuff/
├── DynamicPartyBuff.toc   # Addon manifest (interface version, SavedVariables, load order)
├── Spells.lua             # Spell & buff data table (add/edit spells here)
├── Core.lua               # Buff scanner, party loop, event handling
├── Button.lua             # Secure dynamic button, visuals, tooltip, position saving
├── LICENSE
└── README.md
```

---

## Supported Classes & Buffs

| Class | Spell | Buff Detected | Type |
|-------|-------|--------------|------|
| Druid | Gift of the Wild | Mark of the Wild | Group |
| Druid | Thorns | Thorns | Single |
| Priest | Prayer of Fortitude | Power Word: Fortitude | Group |
| Priest | Prayer of Shadow Protection | Shadow Protection | Group |
| Priest | Divine Spirit | Divine Spirit | Single |
| Mage | Arcane Brilliance | Arcane Intellect | Group |
| Paladin | Greater Blessing of Kings | Blessing of Kings | Single |
| Paladin | Greater Blessing of Might | Blessing of Might | Single (melee) |
| Paladin | Greater Blessing of Wisdom | Blessing of Wisdom | Single (casters) |
| Paladin | Greater Blessing of Salvation | Blessing of Salvation | Single |

---

## How It Works

1. On load and whenever auras/party changes, `Core.lua` scans all party members
2. It walks through `DPB_Spells` (sorted by priority) and finds the first missing buff
3. It sets `DPB.nextSpell` and `DPB.nextTarget` then calls `DPB:UpdateButton()`
4. `Button.lua` updates the button icon, labels, and secure attributes (`spell` + `unit`)
5. Left-clicking the button casts the spell on the correct target via the protected action system
6. After the cast, `UNIT_AURA` fires, triggering a re-scan for the next needed buff

---

## Saved Button Position

The button's screen position and visibility are saved automatically to `DPB_SavedVars` (stored in `WTF/Account/.../SavedVariables/DynamicPartyBuff.lua`).

| Event | What happens |
|---|---|
| Drag and release | Position saved immediately via `DPB:SavePosition()` |
| `/dpb` (hide/show) | Visibility state saved immediately |
| `/dpb reset` | Position reset to screen center; saved |
| Next login | `PLAYER_LOGIN` fires after WoW loads SavedVars; `DPB:RestorePosition()` re-anchors the button |

On first install (no saved data), the button defaults to screen center with a -200px vertical offset.

---

## Adding or Editing Spells

Open `Spells.lua` and add a new entry to the `DPB_Spells` table:

```lua
{
  spellName   = "Mark of the Wild",   -- Exact spell name to cast
  buffName    = "Mark of the Wild",   -- Aura name to check on the unit
  icon        = "Interface\\Icons\\Spell_Nature_Regeneration",
  class       = "DRUID",              -- Only show for this class
  targetClass = nil,                  -- nil = all, or { "WARRIOR", "ROGUE" }
  priority    = 1,                    -- Lower = cast sooner
  isGroupBuff = false,                -- true = AoE cast on self targets group
},
```

---

## Slash Commands

| Command | Action |
|---------|--------|
| `/dpb` | Toggle button visibility (state is saved) |
| `/dpb reset` | Move button back to default center position |

---

## Roadmap

- [x] Saved button position across sessions
- [ ] Per-spec buff profiles (e.g. Ret Paladin vs Holy Paladin blessing priority)
- [ ] Minimap button
- [ ] Raid group support (raid1 .. raid40)
- [ ] Manual buff override (right-click menu to pick a specific buff)
- [ ] Sound alert when all buffs are up

---

## License

MIT — see [LICENSE](LICENSE)
