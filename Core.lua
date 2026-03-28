-- Core.lua
-- DynamicPartyBuff: Main addon logic
--
-- v1.4.1 Bug fixes:
--   [Bug A] PLAYER_ENTERING_WORLD now sets playerClass as a safety net.
--           In TBC Classic the event fire order can vary; re-setting here
--           costs nothing and prevents a nil playerClass on first scan.
--   [Bug B] ScanBuffs() now tracks whether any spell matched the player's
--           class. If the class matched but ALL spells were skipped because
--           they aren't in the spellbook, the button shows "No Spells Known"
--           instead of the misleading "All Up!" / "All buffs are up" state.
--   [Bug C] The "all up" path now only fires when at least one class-matched
--           spell was fully evaluated (not just silently skipped).

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

local function DPBPrint(msg)
  print("|cff00ff00[DPB]|r " .. tostring(msg))
end

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
  local total = 0
  if GetNumGroupMembers then
    total = GetNumGroupMembers()
  elseif GetNumPartyMembers then
    total = GetNumPartyMembers()
    for i = 1, total do
      table.insert(units, "party" .. i)
    end
    return units
  end
  local partyCount = math.min(total - 1, 4)
  for i = 1, partyCount do
    table.insert(units, "party" .. i)
  end
  return units
end

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
-- Core Scan
-- ============================================================
function DPB:ScanBuffs()
  if InCombatLockdown() then
    if DPB.SetButtonReady then
      DPB:SetButtonReady(false, "In Combat")
    end
    return
  end

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

  -- [Bug B] Track whether the player's class has ANY entries in the spell table
  -- and whether any of those were actually evaluatable (known spell).
  local classHasSpells  = false  -- true if at least one spell.class == playerClass
  local anySpellKnown   = false  -- true if at least one of those spells is in spellbook

  for _, spell in ipairs(DPB.Spells) do
    if spell.class == playerClass then
      classHasSpells = true

      if not PlayerKnowsSpell(spell.spellName) then
        if DPB.debug then
          DPBPrint("ScanBuffs: skipping " .. spell.spellName .. " (not in spellbook)")
        end
      else
        anySpellKnown = true

        if spell.isGroupBuff then
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

  -- [Bug B] Distinguish between "all buffs up" and "no spells known yet"
  DPB.nextSpell  = nil
  DPB.nextTarget = nil
  DPB.nextIcon   = nil

  if not classHasSpells then
    -- Player's class has no entries in the spell table at all
    if DPB.debug then DPBPrint("ScanBuffs: no spells defined for class " .. tostring(playerClass)) end
    DPB:SetButtonReady(false, "No Spells")
  elseif not anySpellKnown then
    -- Class is supported but player hasn't trained any of the spells yet
    if DPB.debug then DPBPrint("ScanBuffs: class matched but no spells in spellbook yet.") end
    DPB:SetButtonReady(false, "Train Spells")
  else
    -- Genuinely all buffs are up
    if DPB.debug then DPBPrint("ScanBuffs: all buffs are up.") end
    DPB:UpdateButton()
  end
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
    local _, class = UnitClass("player")
    DPB.playerClass = class
    ValidateSpells()
    if DPB.Spells then
      table.sort(DPB.Spells, function(a, b) return a.priority < b.priority end)
    end
    if DPB.RestorePosition then
      DPB:RestorePosition()
    end
    DPB:ScanBuffs()

  elseif event == "PLAYER_ENTERING_WORLD" then
    -- [Bug A] Re-set playerClass here as a safety net.
    -- In TBC Classic, PLAYER_ENTERING_WORLD can fire before PLAYER_LOGIN on
    -- a fresh login, leaving playerClass nil for the first scan. Setting it
    -- here ensures ScanBuffs() always has a valid class to work with.
    local _, class = UnitClass("player")
    DPB.playerClass = class
    DPB:ScanBuffs()

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

print("|cff00ff00[DynamicPartyBuff]|r Loaded. Happy buffing!")
