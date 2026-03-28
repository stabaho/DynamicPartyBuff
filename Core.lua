-- Core.lua
-- DynamicPartyBuff: Main addon logic
-- v1.5.1 - Fix syntax error in OnEvent handler (broken multi-line elseif).
--          Also fixes: No Spells path now uses SetButtonReady, not UpdateButton.
--          Diagnostic prints retained on all paths.
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
  return GetSpellInfo(spellName) ~= nil
end

local function ClassMatches(unit, targetClassList)
  if not targetClassList then return true end
  local _, unitClass = UnitClass(unit)
  for _, c in ipairs(targetClassList) do
    if c == unitClass then return true end
  end
  return false
end

local function GetPartyUnits()
  local units = { "player" }
  local numParty = 0
  if GetNumPartyMembers then
    numParty = GetNumPartyMembers()
  end
  PE("GetPartyUnits: numParty=" .. tostring(numParty))
  for i = 1, numParty do
    table.insert(units, "party" .. i)
  end
  return units
end

local function ValidateSpells()
  if not DPB.Spells then
    PE("ValidateSpells: DPB.Spells is NIL!")
    return
  end
  PE("ValidateSpells: " .. #DPB.Spells .. " spells loaded.")
  for i, spell in ipairs(DPB.Spells) do
    PE("  [" .. i .. "] " .. tostring(spell.spellName) .. " class=" .. tostring(spell.class) .. " group=" .. tostring(spell.isGroupBuff))
  end
end

local function DeferredScan(label)
  PE("DeferredScan from: " .. tostring(label))
  if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      PE("DeferredScan fired (C_Timer): calling ScanBuffs")
      DPB:ScanBuffs()
    end)
  else
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self)
      self:SetScript("OnUpdate", nil)
      PE("DeferredScan fired (OnUpdate): calling ScanBuffs")
      DPB:ScanBuffs()
    end)
  end
end
-- ============================================================
-- Core Scan
-- ============================================================
function DPB:ScanBuffs()
  PE("=== ScanBuffs START ===")

  if InCombatLockdown() then
    DPB.currentStatus = "In Combat"
    if DPB.SetButtonReady then DPB:SetButtonReady(false, DPB.currentStatus) end
    PE("ScanBuffs: in combat, aborting")
    return
  end

  PE("ScanBuffs: Spells=" .. tostring(DPB.Spells) .. " count=" .. tostring(DPB.Spells and #DPB.Spells or "nil"))
  if not DPB.Spells or #DPB.Spells == 0 then
    DPB.nextSpell  = nil
    DPB.nextTarget = nil
    DPB.nextIcon   = nil
    DPB.currentStatus = "No Spells"
    if DPB.SetButtonReady then
      DPB:SetButtonReady(false, DPB.currentStatus)
    end
    PE("ScanBuffs: no spell table, aborting")
    return
  end

  if not DPB.playerClass then
    local _, class = UnitClass("player")
    PE("ScanBuffs: fetching class from UnitClass: " .. tostring(class))
    if class and class ~= "" then
      DPB.playerClass = class
    end
  end
  local playerClass = DPB.playerClass
  PE("ScanBuffs: playerClass=" .. tostring(playerClass))
  PE("ScanBuffs: UpdateButton=" .. tostring(DPB.UpdateButton) .. " SetButtonReady=" .. tostring(DPB.SetButtonReady))

  local units = GetPartyUnits()
  PE("ScanBuffs: scanning " .. #units .. " unit(s)")

  local classHasSpells = false
  local anySpellKnown  = false

  for idx, spell in ipairs(DPB.Spells) do
    PE("Spell[" .. idx .. "]: " .. tostring(spell.spellName) .. " spell.class=" .. tostring(spell.class))
    if spell.class == playerClass then
      classHasSpells = true
      local known = PlayerKnowsSpell(spell.spellName)
      PE("  class match! known=" .. tostring(known))
      if known then
        anySpellKnown = true
        if spell.isGroupBuff then
          for _, unit in ipairs(units) do
            if UnitExists(unit) and not UnitIsDead(unit) then
              if ClassMatches(unit, spell.targetClass) then
                local has = UnitHasBuff(unit, spell.buffName)
                PE("  group " .. unit .. " has " .. spell.buffName .. "=" .. tostring(has))
                if not has then
                  DPB.nextSpell  = spell.spellName
                  DPB.nextTarget = nil
                  DPB.nextIcon   = spell.icon
                  DPB.currentStatus = "Ready"
                  PE("ScanBuffs: READY group " .. spell.spellName .. " for " .. unit)
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
                local has = UnitHasBuff(unit, spell.buffName)
                PE("  single " .. unit .. " has " .. spell.buffName .. "=" .. tostring(has))
                if not has then
                  DPB.nextSpell  = spell.spellName
                  DPB.nextTarget = unit
                  DPB.nextIcon   = spell.icon
                  DPB.currentStatus = "Ready"
                  PE("ScanBuffs: READY single " .. spell.spellName .. " on " .. unit)
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
  elseif not classHasSpells then
    DPB.currentStatus = "No Spells"
    if DPB.SetButtonReady then DPB:SetButtonReady(false, DPB.currentStatus) end
  elseif not anySpellKnown then
    DPB.currentStatus = "Train Spells"
    if DPB.SetButtonReady then DPB:SetButtonReady(false, DPB.currentStatus) end
  else
    DPB.currentStatus = "All Up"
    if DPB.UpdateButton then DPB:UpdateButton() end
  end
  PE("ScanBuffs: result=" .. tostring(DPB.currentStatus))
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
    PE("EVENT: PLAYER_LOGIN")
    local _, class = UnitClass("player")
    PE("PLAYER_LOGIN: class=" .. tostring(class))
    if class and class ~= "" then DPB.playerClass = class end
    ValidateSpells()
    if DPB.Spells then
      table.sort(DPB.Spells, function(a, b) return a.priority < b.priority end)
    end
    if DPB.RestorePosition then DPB:RestorePosition() end
    PE("PLAYER_LOGIN: UpdateButton=" .. tostring(DPB.UpdateButton) .. " SetButtonReady=" .. tostring(DPB.SetButtonReady))
    DeferredScan("PLAYER_LOGIN")
  elseif event == "PLAYER_ENTERING_WORLD" then
    PE("EVENT: PLAYER_ENTERING_WORLD")
    local _, class = UnitClass("player")
    if class and class ~= "" then DPB.playerClass = class end
    DeferredScan("PLAYER_ENTERING_WORLD")
  elseif event == "UNIT_AURA" then
    local unit = ...
    if unit == "player" or unit:match("^party") then
      DPB:ScanBuffs()
    end
  elseif event == "GROUP_ROSTER_UPDATE" then
    DeferredScan("GROUP_ROSTER_UPDATE")
  elseif event == "PARTY_MEMBERS_CHANGED" then
    DeferredScan("PARTY_MEMBERS_CHANGED")
  elseif event == "PLAYER_REGEN_ENABLED" then
    DeferredScan("PLAYER_REGEN_ENABLED")
  end
end)
P("v1.5.1 loaded - watch for [DPB-DIAG] on login")
