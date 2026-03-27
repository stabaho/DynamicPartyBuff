-- Core.lua
-- DynamicPartyBuff: Main addon logic
-- Scans party members for missing buffs out of combat and
-- updates the dynamic button with the next target + spell to cast.
--
-- Bug fixes (v1.2.0):
--   [Bug 1] Guard DPB:SetButtonReady() call so it doesn't crash before Button.lua loads
--   [Bug 2] Merged PLAYER_LOGIN handling so RestorePosition() fires BEFORE ScanBuffs()
--   [Bug 3] Replaced deprecated GetNumPartyMembers() with GetNumGroupMembers() (TBC API)
--   [Bug 4] Group buffs no longer set a 'unit' attribute - let the spell's AoE handle targeting

-- ============================================================
-- Namespace & state
-- ============================================================
DPB = DPB or {}
DPB.nextSpell   = nil   -- spell name to cast next
DPB.nextTarget  = nil   -- unit token ("player", "party1" .. "party4")
DPB.nextIcon    = nil   -- icon path for button texture
DPB.playerClass = nil   -- caster's class (e.g. "DRUID")

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

-- [Bug 3 Fix] TBC uses GetNumGroupMembers() which counts ALL members including self.
-- Party-only tokens are party1..party4, so subtract 1 for self and cap at 4.
local function GetPartyUnits()
  local units = { "player" }
  local total = 0
  if GetNumGroupMembers then
    total = GetNumGroupMembers()
  elseif GetNumPartyMembers then
    -- Vanilla/pre-TBC fallback: GetNumPartyMembers excludes self
    total = GetNumPartyMembers()
    for i = 1, total do
      table.insert(units, "party" .. i)
    end
    return units
  end
  -- GetNumGroupMembers includes the player, so party members = total - 1, max 4
  local partyCount = math.min(total - 1, 4)
  for i = 1, partyCount do
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
    -- [Bug 1 Fix] Guard: Button.lua may not be loaded yet at earliest events
    if DPB.SetButtonReady then
      DPB:SetButtonReady(false, "In Combat")
    end
    return
  end

  local playerClass = DPB.playerClass
  local units       = GetPartyUnits()

  -- Sort spell list by priority (lowest number = highest priority)
  table.sort(DPB_Spells, function(a, b) return a.priority < b.priority end)

  for _, spell in ipairs(DPB_Spells) do
    -- Skip spells the player's class cannot cast
    if spell.class == playerClass and PlayerKnowsSpell(spell.spellName) then

      if spell.isGroupBuff then
        -- [Bug 4 Fix] Group buffs: check if ANY party member is missing the buff.
        -- We do NOT set a unit attribute - group buff spells in TBC (Gift of the Wild,
        -- Prayer of Fortitude, etc.) cast on the whole party/raid automatically.
        -- Setting unit="player" would restrict the cast and break the AoE behavior.
        for _, unit in ipairs(units) do
          if UnitExists(unit) and not UnitIsDead(unit) then
            if ClassMatches(unit, spell.targetClass) then
              if not UnitHasBuff(unit, spell.buffName) then
                DPB.nextSpell  = spell.spellName
                DPB.nextTarget = nil   -- nil = no unit override; spell itself is AoE
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
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")   -- TBC: party roster changes
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")  -- TBC fallback
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")   -- Just left combat

eventFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" then
    -- [Bug 2 Fix] On PLAYER_LOGIN, SavedVars are guaranteed loaded by WoW.
    -- Restore button position FIRST so the button is in the right place
    -- before ScanBuffs() calls UpdateButton() and the player sees it.
    local _, class = UnitClass("player")
    DPB.playerClass = class
    -- RestorePosition is defined in Button.lua which is loaded after Core.lua,
    -- but PLAYER_LOGIN fires after ALL files are loaded, so it is safe to call.
    if DPB.RestorePosition then
      DPB:RestorePosition()
    end
    DPB:ScanBuffs()

  elseif event == "PLAYER_ENTERING_WORLD" then
    -- Fires on every zone transition/reload - just re-scan, position already set
    local _, class = UnitClass("player")
    DPB.playerClass = class
    DPB:ScanBuffs()

  elseif event == "UNIT_AURA" then
    -- Only re-scan when a party member or the player's auras change
    local unit = ...
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
