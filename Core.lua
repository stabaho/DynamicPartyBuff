-- Core.lua
-- DynamicPartyBuff: Main addon logic
-- Scans party members for missing buffs out of combat and
-- updates the dynamic button with the next target + spell to cast.
--
-- v1.3.0 Code Review fixes:
--   [R1] Removed table.sort() from ScanBuffs() - sorted once at PLAYER_LOGIN.
--   [R2] playerClass set only in PLAYER_LOGIN, not repeated in PLAYER_ENTERING_WORLD.
--   [R3] UNIT_AURA uses unit:match("^party") for precise start-of-string matching.
--   [R4] Added ValidateSpells() to warn on malformed spell table entries at startup.
--   [R5] ScanBuffs() guards against nil/empty DPB.Spells gracefully.
--
-- v1.4.0:
--   Renamed DPB_Spells to DPB.Spells to reduce global namespace pollution.
--   Added DPB.debug flag; ScanBuffs() prints results to chat when enabled.

-- ============================================================
-- Namespace & state
-- ============================================================
DPB = DPB or {}
DPB.nextSpell    = nil   -- spell name to cast next
DPB.nextTarget   = nil   -- unit token ("player", "party1" .. "party4")
DPB.nextIcon     = nil   -- icon path for button texture
DPB.playerClass  = nil   -- caster's class (e.g. "DRUID")
DPB.debug        = false -- set true via /dpb debug to print scan output to chat

-- ============================================================
-- Helpers
-- ============================================================

-- Local shorthand for debug output.
local function DPBPrint(msg)
  print("|cff00ff00[DPB]|r " .. tostring(msg))
end

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

-- [R4] Validate spell table entries at startup and print warnings for bad data.
local function ValidateSpells()
  if not DPB.Spells then
    DPBPrint("WARNING: DPB.Spells is nil - no spells loaded!")
    return
  end
  local required = { "spellName", "buffName", "icon", "class", "priority", "isGroupBuff" }
  for i, spell in ipairs(DPB.Spells) do
    for _, field in ipairs(required) do
      if spell[field] == nil then
        DPBPrint("WARNING: Spell #" .. i .. " (" .. (spell.spellName or "?") .. ") missing field: " .. field)
      end
    end
  end
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

  -- [R5] Guard against missing or empty spell table
  if not DPB.Spells or #DPB.Spells == 0 then
    if DPB.debug then DPBPrint("ScanBuffs: DPB.Spells is empty or nil.") end
    DPB.nextSpell  = nil
    DPB.nextTarget = nil
    DPB.nextIcon   = nil
    DPB:UpdateButton()
    return
  end

  local playerClass = DPB.playerClass
  local units = GetPartyUnits()

  if DPB.debug then
    DPBPrint("ScanBuffs: class=" .. tostring(playerClass) .. ", units=" .. #units)
  end

  -- [R1] NOTE: DPB.Spells is sorted once in PLAYER_LOGIN - do NOT sort here.

  for _, spell in ipairs(DPB.Spells) do
    -- Skip spells the player's class cannot cast
    if spell.class == playerClass then
      if not PlayerKnowsSpell(spell.spellName) then
        if DPB.debug then
          DPBPrint("ScanBuffs: skipping " .. spell.spellName .. " (not in spellbook)")
        end
      else
        if spell.isGroupBuff then
          -- [Bug 4 Fix] Group buffs: check if ANY party member is missing the buff.
          for _, unit in ipairs(units) do
            if UnitExists(unit) and not UnitIsDead(unit) then
              if ClassMatches(unit, spell.targetClass) then
                if not UnitHasBuff(unit, spell.buffName) then
                  if DPB.debug then
                    DPBPrint("ScanBuffs: need " .. spell.spellName .. " (group) - " .. unit .. " missing " .. spell.buffName)
                  end
                  DPB.nextSpell  = spell.spellName
                  DPB.nextTarget = nil
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
                  if DPB.debug then
                    DPBPrint("ScanBuffs: need " .. spell.spellName .. " on " .. unit)
                  end
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
  end

  -- All buffs are up!
  if DPB.debug then DPBPrint("ScanBuffs: all buffs are up.") end
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
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED") -- TBC fallback
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Just left combat

eventFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" then
    -- [R2] Set playerClass ONCE here. Class never changes within a session.
    local _, class = UnitClass("player")
    DPB.playerClass = class

    -- [R4] Validate spell table entries at startup.
    ValidateSpells()

    -- [R1] Sort spell table ONCE here, not on every ScanBuffs() call.
    if DPB.Spells then
      table.sort(DPB.Spells, function(a, b) return a.priority < b.priority end)
    end

    -- Restore button position before ScanBuffs so button is placed correctly
    -- before UpdateButton() fires.
    if DPB.RestorePosition then
      DPB:RestorePosition()
    end

    DPB:ScanBuffs()

  elseif event == "PLAYER_ENTERING_WORLD" then
    -- Zone transition / UI reload. Class already set. Just re-scan.
    -- [R2] playerClass intentionally NOT re-set here.
    DPB:ScanBuffs()

  elseif event == "UNIT_AURA" then
    -- [R3] unit:match("^party") anchored to start of string for precision.
    local unit = ...
    if unit == "player" or unit:match("^party") then
      DPB:ScanBuffs()
    end

  elseif event == "GROUP_ROSTER_UPDATE"
      or event == "PARTY_MEMBERS_CHANGED"
      or event == "PLAYER_REGEN_ENABLED" then
    DPB:ScanBuffs()
  end
end)

print("|cff00ff00[DynamicPartyBuff]|r Loaded. Happy buffing!")
