-- Core.lua
-- DynamicPartyBuff: Main addon logic
-- Scans party members for missing buffs out of combat and
-- updates the dynamic button with the next target + spell to cast.

-- ============================================================
-- Namespace & state
-- ============================================================
DPB = DPB or {}
DPB.nextSpell  = nil   -- spell name to cast next
DPB.nextTarget = nil   -- unit token ("player", "party1" .. "party4")
DPB.nextIcon   = nil   -- icon path for button texture
DPB.playerClass = nil  -- caster's class (e.g. "DRUID")

-- ============================================================
-- Helpers
-- ============================================================

-- Check if a unit currently has a specific buff by name.
local function UnitHasBuff(unit, buffName)
  local i = 1
  while true do
    local name = UnitBuff(unit, i)
    if not name then break end
    if name == buffName then return true end
    i = i + 1
  end
  return false
end

-- Check if the player knows a given spell.
local function PlayerKnowsSpell(spellName)
  return GetSpellInfo(spellName) ~= nil
end

-- Check if a unit's class matches a targetClass whitelist (nil = any class).
local function ClassMatches(unit, targetClassList)
  if not targetClassList then return true end
  local _, unitClass = UnitClass(unit)
  for _, c in ipairs(targetClassList) do
    if c == unitClass then return true end
  end
  return false
end

-- Returns a list of all relevant units (player + party members).
local function GetPartyUnits()
  local units = { "player" }
  local count = GetNumPartyMembers and GetNumPartyMembers() or 0
  for i = 1, count do
    table.insert(units, "party" .. i)
  end
  return units
end

-- ============================================================
-- Core Scan: find the highest-priority missing buff
-- ============================================================
function DPB:ScanBuffs()
  -- Only act out of combat
  if InCombatLockdown() then
    DPB:SetButtonReady(false, "In Combat")
    return
  end

  local playerClass = DPB.playerClass
  local units       = GetPartyUnits()

  -- Sort spell list by priority (lowest number first)
  table.sort(DPB_Spells, function(a, b) return a.priority < b.priority end)

  for _, spell in ipairs(DPB_Spells) do
    -- Skip spells the player's class cannot cast
    if spell.class == playerClass and PlayerKnowsSpell(spell.spellName) then

      if spell.isGroupBuff then
        -- Group buffs: just check if ANY party member is missing it.
        -- We cast on "player" and the spell hits the whole party/raid.
        for _, unit in ipairs(units) do
          if UnitExists(unit) and not UnitIsDead(unit) then
            if ClassMatches(unit, spell.targetClass) then
              if not UnitHasBuff(unit, spell.buffName) then
                DPB.nextSpell  = spell.spellName
                DPB.nextTarget = "player"  -- AoE buff cast on self hits group
                DPB.nextIcon   = spell.icon
                DPB:UpdateButton()
                return
              end
            end
          end
        end
      else
        -- Single-target buffs: find the first unit that needs it.
        for _, unit in ipairs(units) do
          if UnitExists(unit) and not UnitIsDead(unit) then
            if ClassMatches(unit, spell.targetClass) then
              if not UnitHasBuff(unit, spell.buffName) then
                DPB.nextSpell  = spell.spellName
                DPB.nextTarget = unit
                DPB.nextIcon   = spell.icon
                DPB:UpdateButton()
                return
              end
            end
          end
        end
      end
    end
  end

  -- All buffs are up!
  DPB.nextSpell  = nil
  DPB.nextTarget = nil
  DPB.nextIcon   = nil
  DPB:UpdateButton()
end

-- ============================================================
-- Event Frame
-- ============================================================
local eventFrame = CreateFrame("Frame", "DPB_EventFrame", UIParent)

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")   -- TBC: party changes
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")  -- TBC fallback
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")   -- Just left combat

eventFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    local _, class = UnitClass("player")
    DPB.playerClass = class
    DPB:ScanBuffs()

  elseif event == "UNIT_AURA" then
    -- arg1 is the unit whose auras changed
    local unit = ...
    -- Only re-scan if it's a party member or the player
    if unit == "player" or string.find(unit, "party") then
      DPB:ScanBuffs()
    end

  elseif event == "GROUP_ROSTER_UPDATE"
      or event == "PARTY_MEMBERS_CHANGED"
      or event == "PLAYER_REGEN_ENABLED" then
    DPB:ScanBuffs()
  end
end)

print("|cff00ff00[DynamicPartyBuff]|r Loaded. Happy buffing!")
