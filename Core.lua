-- Core.lua
-- DynamicPartyBuff: Main addon logic
-- v1.5.0 - Full diagnostic build: prints every step to chat on login.
-- ============================================================
-- Namespace & state
-- ============================================================
DPB = DPB or {}
DPB.nextSpell    = nil
DPB.nextTarget   = nil
DPB.nextIcon     = nil
DPB.playerClass  = nil
DPB.debug        = false
DPB.debugEvents  = false
DPB.currentStatus = "Scanning..."
-- ============================================================
-- Print helpers
-- ============================================================
local function P(msg)
  print("|cff00ff00[DPB]|r " .. tostring(msg))
end
local function PE(msg)
  print("|cffffaa00[DPB-DIAG]|r " .. tostring(msg))
end
-- ============================================================
-- Core helpers
-- ============================================================
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

local function PlayerKnowsSpell(spellName)
  local found = GetSpellInfo(spellName)
  return found ~= nil
end

local function ClassMatches(unit, targetClassList)
  if not targetClassList then return true end
  local _, unitClass = UnitClass(unit)
  for _, c in ipairs(targetClassList) do
    if c == unitClass then return true end
  end
  return false
end

-- TBC Classic: GetNumPartyMembers() returns 0-4 (excludes player).
-- GetNumGroupMembers does NOT exist in TBC 2.4.3.
local function GetPartyUnits()
  local units = { "player" }
  local numParty = 0
  if GetNumPartyMembers then
    numParty = GetNumPartyMembers()
  end
  PE("GetPartyUnits: GetNumPartyMembers()=" .. tostring(numParty))
  for i = 1, numParty do
    table.insert(units, "party" .. i)
  end
  return units
end

local function ValidateSpells()
  if not DPB.Spells then
    PE("ValidateSpells: DPB.Spells is NIL - Spells.lua may not have loaded!")
    return
  end
  PE("ValidateSpells: DPB.Spells has " .. #DPB.Spells .. " entries.")
  local required = { "spellName", "buffName", "icon", "class", "priority", "isGroupBuff" }
  for i, spell in ipairs(DPB.Spells) do
    for _, field in ipairs(required) do
      if spell[field] == nil then
        PE("WARNING: Spell #" .. i .. " (" .. tostring(spell.spellName) .. ") missing field: " .. field)
      end
    end
    PE("  Spell[" .. i .. "]: " .. tostring(spell.spellName) .. " class=" .. tostring(spell.class) .. " isGroup=" .. tostring(spell.isGroupBuff) .. " priority=" .. tostring(spell.priority))
  end
end

-- One-frame defer with fallback for environments without C_Timer
local function DeferredScan(label)
  PE("DeferredScan called from: " .. tostring(label))
  if C_Timer and C_Timer.After then
    PE("DeferredScan: using C_Timer.After")
    C_Timer.After(0, function()
      PE("DeferredScan: C_Timer fired, calling ScanBuffs")
      DPB:ScanBuffs()
    end)
  else
    PE("DeferredScan: C_Timer unavailable, using OnUpdate fallback")
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self)
      self:SetScript("OnUpdate", nil)
      PE("DeferredScan: OnUpdate fired, calling ScanBuffs")
      DPB:ScanBuffs()
    end)
  end
end
-- ============================================================
-- Core Scan
-- ============================================================
function DPB:ScanBuffs()
  PE("=== ScanBuffs START ===")

  -- Check combat
  local inCombat = InCombatLockdown()
  PE("ScanBuffs: InCombatLockdown=" .. tostring(inCombat))
  if inCombat then
    DPB.currentStatus = "In Combat"
    if DPB.SetButtonReady then DPB:SetButtonReady(false, DPB.currentStatus) end
    PE("ScanBuffs: aborting - in combat")
    return
  end

  -- Check spell table
  PE("ScanBuffs: DPB.Spells=" .. tostring(DPB.Spells) .. " count=" .. tostring(DPB.Spells and #DPB.Spells or "nil"))
  if not DPB.Spells or #DPB.Spells == 0 then
    DPB.nextSpell  = nil
    DPB.nextTarget = nil
    DPB.nextIcon   = nil
    DPB.currentStatus = "No Spells"
    if DPB.UpdateButton then DPB:UpdateButton() end
    PE("ScanBuffs: aborting - no spells table")
    return
  end

  -- Check / fetch playerClass
  PE("ScanBuffs: DPB.playerClass=" .. tostring(DPB.playerClass))
  if not DPB.playerClass then
    local _, class = UnitClass("player")
    PE("ScanBuffs: UnitClass fetch returned class=" .. tostring(class))
    if class and class ~= "" then
      DPB.playerClass = class
    end
  end
  local playerClass = DPB.playerClass
  PE("ScanBuffs: effective playerClass=" .. tostring(playerClass))

  -- Check UpdateButton / SetButtonReady availability
  PE("ScanBuffs: DPB.UpdateButton=" .. tostring(DPB.UpdateButton))
  PE("ScanBuffs: DPB.SetButtonReady=" .. tostring(DPB.SetButtonReady))

  -- Build unit list
  local units = GetPartyUnits()
  PE("ScanBuffs: unit count=" .. #units)
  for i, u in ipairs(units) do
    PE("  unit[" .. i .. "]=" .. u .. " exists=" .. tostring(UnitExists(u)) .. " dead=" .. tostring(UnitIsDead(u)))
  end

  local classHasSpells = false
  local anySpellKnown  = false

  for idx, spell in ipairs(DPB.Spells) do
    PE("ScanBuffs: checking spell[" .. idx .. "]=" .. tostring(spell.spellName) .. " spell.class=" .. tostring(spell.class) .. " playerClass=" .. tostring(playerClass))
    if spell.class == playerClass then
      classHasSpells = true
      local known = PlayerKnowsSpell(spell.spellName)
      PE("  -> class match! PlayerKnowsSpell=" .. tostring(known))
      if not known then
        PE("  -> skipping (not in spellbook)")
      else
        anySpellKnown = true
        if spell.isGroupBuff then
          for _, unit in ipairs(units) do
            if UnitExists(unit) and not UnitIsDead(unit) then
              if ClassMatches(unit, spell.targetClass) then
                local hasBuff = UnitHasBuff(unit, spell.buffName)
                PE("    group: " .. unit .. " hasBuff(" .. spell.buffName .. ")=" .. tostring(hasBuff))
                if not hasBuff then
                  DPB.nextSpell  = spell.spellName
                  DPB.nextTarget = nil
                  DPB.nextIcon   = spell.icon
                  DPB.currentStatus = "Ready"
                  PE("ScanBuffs: READY - " .. spell.spellName .. " (group) for " .. unit)
                  if DPB.UpdateButton then DPB:UpdateButton() end
                  return
                end
              end
            end
          end
        else
          for _, unit in ipairs(units) do
            if UnitExists(unit) and not UnitIsDead(unit) then
              if ClassMatches(unit, spell.targetClass) then
                local hasBuff = UnitHasBuff(unit, spell.buffName)
                PE("    single: " .. unit .. " hasBuff(" .. spell.buffName .. ")=" .. tostring(hasBuff))
                if not hasBuff then
                  DPB.nextSpell  = spell.spellName
                  DPB.nextTarget = unit
                  DPB.nextIcon   = spell.icon
                  DPB.currentStatus = "Ready"
                  PE("ScanBuffs: READY - " .. spell.spellName .. " on " .. unit)
                  if DPB.UpdateButton then DPB:UpdateButton() end
                  return
                end
              end
            end
          end
        end
      end
    end
  end

  DPB.nextSpell  = nil
  DPB.nextTarget = nil
  DPB.nextIcon   = nil

  PE("ScanBuffs END: classHasSpells=" .. tostring(classHasSpells) .. " anySpellKnown=" .. tostring(anySpellKnown))

  if not playerClass then
    DPB.currentStatus = "Class Missing"
    if DPB.SetButtonReady then DPB:SetButtonReady(false, DPB.currentStatus) end
    PE("ScanBuffs: result=Class Missing")
  elseif not classHasSpells then
    DPB.currentStatus = "No Spells"
    if DPB.SetButtonReady then DPB:SetButtonReady(false, DPB.currentStatus) end
    PE("ScanBuffs: result=No Spells for class " .. tostring(playerClass))
  elseif not anySpellKnown then
    DPB.currentStatus = "Train Spells"
    if DPB.SetButtonReady then DPB:SetButtonReady(false, DPB.currentStatus) end
    PE("ScanBuffs: result=Train Spells")
  else
    DPB.currentStatus = "All Up"
    if DPB.UpdateButton then DPB:UpdateButton() end
    PE("ScanBuffs: result=All Up")
  end
  PE("=== ScanBuffs END ===")
end
-- ============================================================
-- Event Frame
-- ============================================================
local eventFrame = CreateFrame("Frame", "DPB_EventFrame", UIParent)
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" then
    PE("EVENT: PLAYER_LOGIN fired")
    local _, class = UnitClass("player")
    PE("PLAYER_LOGIN: UnitClass=" .. tostring(class))
    if class and class ~= "" then
      DPB.playerClass = class
    end
    PE("PLAYER_LOGIN: DPB.Spells=" .. tostring(DPB.Spells))
    ValidateSpells()
    if DPB.Spells then
      table.sort(DPB.Spells, function(a, b) return a.priority < b.priority end)
      PE("PLAYER_LOGIN: spells sorted")
    end
    PE("PLAYER_LOGIN: DPB.RestorePosition=" .. tostring(DPB.RestorePosition))
    if DPB.RestorePosition then
      DPB:RestorePosition()
    end
    PE("PLAYER_LOGIN: DPB.UpdateButton=" .. tostring(DPB.UpdateButton))
    PE("PLAYER_LOGIN: DPB.SetButtonReady=" .. tostring(DPB.SetButtonReady))
    DeferredScan("PLAYER_LOGIN")
  elseif event == "PLAYER_ENTERING_WORLD" then
    PE("EVENT: PLAYER_ENTERING_WORLD fired")
    local _, class = UnitClass("player")
    PE("PLAYER_ENTERING_WORLD: UnitClass=" .. tostring(class))
    if class and class ~= "" then
      DPB.playerClass = class
    end
    DeferredScan("PLAYER_ENTERING_WORLD")
  elseif event == "UNIT_AURA" then
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
P("v1.5.0 DIAG loaded. Check chat for [DPB-DIAG] messages on login.")
