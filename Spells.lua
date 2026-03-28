-- Spells.lua
-- DynamicPartyBuff: Spell and buff data table
-- Each entry defines a buff the addon will check and cast.
-- Priority determines cast order (lower number = higher priority).
-- targetClass = nil means the buff applies to all classes.
--
-- v1.4.0: DPB_Spells global renamed to DPB.Spells to reduce namespace pollution.
--   [R10] Verified all buffName values match the actual aura name as returned by UnitBuff().
--   [R11] Added Mark of the Wild (single-target rank) as Druid fallback after Gift of the Wild.
--   [R12] Paladin blessing targetClass lists audited for TBC accuracy.
-- v1.6.0:
--   [R6]  Removed debug print() at file load -- it was spamming red text to all users' chat.
--   [R7]  Greater Blessing of Salvation: restricted targetClass to casters/healers only;
--         moved to priority 20. Warriors, bears and other tank specs typically decline
--         Salvation as it reduces their threat. Paladins in most TBC groups do not cast
--         it on melee/tanks without explicit consent.
--
-- Spells.lua loads before Core.lua, so ensure the DPB namespace table exists.
DPB = DPB or {}

DPB.Spells = {

  -- ===== DRUID =====
  {
    spellName   = "Gift of the Wild",         -- Group buff: all party members at once
    buffName    = "Mark of the Wild",         -- [R10] Aura name = "Mark of the Wild" for all ranks
    icon        = "Interface\\Icons\\Spell_Nature_Regeneration",
    class       = "DRUID",
    targetClass = nil,                        -- nil = all classes
    priority    = 1,
    isGroupBuff = true,
  },
  {
    spellName   = "Mark of the Wild",         -- [R11] Single-target fallback (solo or small group)
    buffName    = "Mark of the Wild",
    icon        = "Interface\\Icons\\Spell_Nature_Regeneration",
    class       = "DRUID",
    targetClass = nil,
    priority    = 2,
    isGroupBuff = false,
  },
  {
    spellName   = "Thorns",
    buffName    = "Thorns",
    icon        = "Interface\\Icons\\Spell_Nature_Thorns",
    class       = "DRUID",
    targetClass = nil,
    priority    = 10,
    isGroupBuff = false,
  },

  -- ===== PRIEST =====
  {
    spellName   = "Prayer of Fortitude",      -- Group buff: stamina for all
    buffName    = "Power Word: Fortitude",    -- [R10] Aura is "Power Word: Fortitude" for all ranks
    icon        = "Interface\\Icons\\Spell_Holy_WordFortitude",
    class       = "PRIEST",
    targetClass = nil,
    priority    = 1,
    isGroupBuff = true,
  },
  {
    spellName   = "Power Word: Fortitude",    -- Single-target fallback
    buffName    = "Power Word: Fortitude",
    icon        = "Interface\\Icons\\Spell_Holy_WordFortitude",
    class       = "PRIEST",
    targetClass = nil,
    priority    = 2,
    isGroupBuff = false,
  },
  {
    spellName   = "Prayer of Shadow Protection",
    buffName    = "Shadow Protection",        -- [R10] Aura is "Shadow Protection"
    icon        = "Interface\\Icons\\Spell_Shadow_AntiShadow",
    class       = "PRIEST",
    targetClass = nil,
    priority    = 3,
    isGroupBuff = true,
  },
  {
    spellName   = "Divine Spirit",            -- [R10] Single-target spirit buff
    buffName    = "Divine Spirit",
    icon        = "Interface\\Icons\\Spell_Holy_Prayerofspirit",
    class       = "PRIEST",
    targetClass = nil,
    priority    = 4,
    isGroupBuff = false,
  },

  -- ===== MAGE =====
  {
    spellName   = "Arcane Brilliance",        -- Group intellect buff
    buffName    = "Arcane Intellect",         -- [R10] Aura = "Arcane Intellect" for both single & group
    icon        = "Interface\\Icons\\Spell_Holy_MagicalSentry",
    class       = "MAGE",
    targetClass = nil,
    priority    = 1,
    isGroupBuff = true,
  },
  {
    spellName   = "Arcane Intellect",         -- Single-target fallback
    buffName    = "Arcane Intellect",
    icon        = "Interface\\Icons\\Spell_Holy_MagicalSentry",
    class       = "MAGE",
    targetClass = nil,
    priority    = 2,
    isGroupBuff = false,
  },

  -- ===== PALADIN =====
  -- [R12] Greater Blessings are single-target (class-specific) in TBC.
  -- The buff aura name is the regular Blessing name (without "Greater").
  {
    spellName   = "Greater Blessing of Kings",
    buffName    = "Blessing of Kings",        -- [R10] Aura = "Blessing of Kings"
    icon        = "Interface\\Icons\\Spell_Magic_GreaterBlessingofKings",
    class       = "PALADIN",
    targetClass = nil,                        -- Kings goes on everyone
    priority    = 1,
    isGroupBuff = false,
  },
  {
    spellName   = "Greater Blessing of Might",
    buffName    = "Blessing of Might",        -- [R10] Aura = "Blessing of Might"
    icon        = "Interface\\Icons\\Spell_Holy_FistofJustice",
    class       = "PALADIN",
    -- [R12] Might targets physical DPS and melee classes in TBC
    targetClass = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "SHAMAN", "DRUID" },
    priority    = 2,
    isGroupBuff = false,
  },
  {
    spellName   = "Greater Blessing of Wisdom",
    buffName    = "Blessing of Wisdom",       -- [R10] Aura = "Blessing of Wisdom"
    icon        = "Interface\\Icons\\Spell_Holy_SealofWisdom",
    class       = "PALADIN",
    -- [R12] Wisdom targets mana users in TBC
    targetClass = { "PRIEST", "MAGE", "WARLOCK", "DRUID", "SHAMAN", "PALADIN" },
    priority    = 3,
    isGroupBuff = false,
  },
  {
    spellName   = "Greater Blessing of Salvation",
    buffName    = "Blessing of Salvation",    -- [R10] Aura = "Blessing of Salvation"
    icon        = "Interface\\Icons\\Spell_Holy_SealofSalvation",
    class       = "PALADIN",
    -- [R7] Salvation is NOT appropriate for tanks (reduces threat generation).
    -- Restricted to casters and healers only. Warriors and bears should never
    -- receive this without explicit consent from their tank.
    targetClass = { "PRIEST", "MAGE", "WARLOCK", "HUNTER" },
    priority    = 20,                         -- Low priority; only after all other blessings
    isGroupBuff = false,
  },

  -- ===== WARLOCK =====
  {
    spellName   = "Detect Invisibility",
    buffName    = "Detect Invisibility",
    icon        = "Interface\\Icons\\Spell_Shadow_DetectInvisibility",
    class       = "WARLOCK",
    targetClass = nil,
    priority    = 5,
    isGroupBuff = false,
  },

  -- ===== SHAMAN =====
  -- Shaman buffs are primarily totem-based (cast-and-forget, not UnitBuff detectable).
  -- Weapon buffs (Windfury Weapon, Flametongue Weapon) are self-only and not scannable.
  -- Water Shield / Lightning Shield are self-buffs managed by the Shaman manually.
  -- No entries needed here; leave as reminder comment.
}
