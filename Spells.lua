-- Spells.lua
-- DynamicPartyBuff: Spell and buff data table
-- Each entry defines a buff the addon will check and cast.
-- Priority determines cast order (lower = higher priority).
-- classes = nil means it can be cast on anyone.

DPB_Spells = {
  -- ===== DRUID =====
  {
    spellName   = "Gift of the Wild",         -- Group buff (rank 2 covers 60+)
    buffName    = "Mark of the Wild",          -- The aura name to detect on the unit
    icon        = "Interface\\Icons\\Spell_Nature_Regeneration",
    class       = "DRUID",                     -- Caster must be this class
    targetClass = nil,                         -- nil = all classes
    priority    = 1,
    isGroupBuff = true,                        -- Uses a group/party-wide cast
  },
  {
    spellName   = "Thorns",
    buffName    = "Thorns",
    icon        = "Interface\\Icons\\Spell_Nature_Thorns",
    class       = "DRUID",
    targetClass = nil,
    priority    = 5,
    isGroupBuff = false,
  },

  -- ===== PRIEST =====
  {
    spellName   = "Prayer of Fortitude",
    buffName    = "Power Word: Fortitude",
    icon        = "Interface\\Icons\\Spell_Holy_WordFortitude",
    class       = "PRIEST",
    targetClass = nil,
    priority    = 1,
    isGroupBuff = true,
  },
  {
    spellName   = "Prayer of Shadow Protection",
    buffName    = "Shadow Protection",
    icon        = "Interface\\Icons\\Spell_Shadow_AntiShadow",
    class       = "PRIEST",
    targetClass = nil,
    priority    = 2,
    isGroupBuff = true,
  },
  {
    spellName   = "Divine Spirit",
    buffName    = "Divine Spirit",
    icon        = "Interface\\Icons\\Spell_Holy_Prayerofspirit",
    class       = "PRIEST",
    targetClass = nil,
    priority    = 3,
    isGroupBuff = false,
  },

  -- ===== MAGE =====
  {
    spellName   = "Arcane Brilliance",
    buffName    = "Arcane Intellect",
    icon        = "Interface\\Icons\\Spell_Holy_MagicalSentry",
    class       = "MAGE",
    targetClass = nil,
    priority    = 1,
    isGroupBuff = true,
  },

  -- ===== PALADIN =====
  {
    spellName   = "Greater Blessing of Kings",
    buffName    = "Blessing of Kings",
    icon        = "Interface\\Icons\\Spell_Magic_GreaterBlessingofKings",
    class       = "PALADIN",
    targetClass = nil,
    priority    = 1,
    isGroupBuff = false,
  },
  {
    spellName   = "Greater Blessing of Might",
    buffName    = "Blessing of Might",
    icon        = "Interface\\Icons\\Spell_Holy_FistofJustice",
    class       = "PALADIN",
    targetClass = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "SHAMAN", "DRUID" },
    priority    = 2,
    isGroupBuff = false,
  },
  {
    spellName   = "Greater Blessing of Wisdom",
    buffName    = "Blessing of Wisdom",
    icon        = "Interface\\Icons\\Spell_Holy_SealofWisdom",
    class       = "PALADIN",
    targetClass = { "PRIEST", "MAGE", "WARLOCK", "DRUID", "SHAMAN", "PALADIN" },
    priority    = 3,
    isGroupBuff = false,
  },
  {
    spellName   = "Greater Blessing of Salvation",
    buffName    = "Blessing of Salvation",
    icon        = "Interface\\Icons\\Spell_Holy_SealofSalvation",
    class       = "PALADIN",
    targetClass = nil,
    priority    = 4,
    isGroupBuff = false,
  },

  -- ===== SHAMAN =====
  -- Shaman buffs are totem-based and handled separately.
  -- Add weapon buff targets here if desired.
}
