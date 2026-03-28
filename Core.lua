-- Core.lua
-- DynamicPartyBuff: Main addon logic
--
-- v1.4.1 Bug fixes:
-- [Bug A] PLAYER_ENTERING_WORLD now sets playerClass as a safety net.
--         In TBC Classic the event fire order can vary; re-setting here
--         costs nothing and prevents a nil playerClass on first scan.
-- [Bug B] ScanBuffs() now tracks whether any spell matched the player's
--         class. If the class matched but ALL spells were skipped because
--         they aren't in the spellbook, the button shows "No Spells Known"
--         instead of the misleading "All Up!" / "All buffs are up" state.
-- [Bug C] The "all up" path now only fires when at least one class-matched
--         spell was fully evaluated (not just silently skipped).
--
-- v1.4.2 Debug additions:
-- [Debug] Event-level logging added to OnEvent handler (/dpb debug).
--         Each fired event prints: timestamp, event name, and key args.
-- [Debug] UpdateButton() and SetButtonReady() now log state transitions.
-- [Debug] /dpb debugevents toggles event logging independently of scan logging.
-- ============================================================
-- Namespace & state
-- ============================================================
DPB = DPB or {}
DPB.nextSpell    = nil   -- spell name to cast next
DPB.nextTarget   = nil   -- unit token ("player", "party1" .. "party4")
DPB.nextIcon     = nil   -- icon path for button texture
DPB.playerClass  = nil   -- caster's class (e.g. "DRUID")
DPB.debug        = false -- set true via /dpb debug to print scan output to chat
DPB.debugEvents  = false -- set true via /dpb debugevents to also log every event
DPB.currentStatus = "Scanning..." -- tracks why nextSpell is nil (for tooltip)
-- ============================================================
-- Helpers
-- ============================================================
local function DPBPrint(msg)
  print("|cff00ff00[DPB]|r " .. tostring(msg))
end
-- Unified debug printer: only fires when DPB.debug is true
local function DPBDebug(msg)
  if DPB.debug then
    DPBPrint(string.format("[%.3f] %s", GetTime(), tostring(msg)))
  end
end
-- Event debug printer: fires when DPB.debug OR DPB.debugEvents is true
local function DPBEventDebug(msg)
  if DPB.debug or DPB.debugEvents then
    DPBPrint(string.format("[%.3f] EVENT %s", GetTime(), tostring(msg)))
  end
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
    DPB.currentStatus = "In Combat"
    if DPB.SetButtonReady then
      DPB:SetButtonReady(false, DPB.currentStatus)
    end
    return
  end
  if not DPB.Spells or #DPB.Spells == 0 then
    DPBDebug("ScanBuffs: DPB.Spells is empty or nil.")
    DPB.nextSpell = nil
    DPB.nextTarget = nil
    DPB.nextIcon = nil
    DPB.currentStatus = "No Spells"
    if DPB.UpdateButton then DPB:UpdateButton() end
    return
  end
  -- Robust class check: try to fetch it if nil
  if not DPB.playerClass then
    local _, class = UnitClass("player")
    if class and class ~= "" then
      DPB.playerClass = class
      DPBDebug("ScanBuffs: playerClass was nil, fetched: " .. tostring(class))
    end
  end
  local playerClass = DPB.playerClass
  local units = GetPartyUnits()
  DPBDebug("ScanBuffs START: class=" .. tostring(playerClass) .. ", units=" .. #units)
  -- [Bug B] Track whether the player's class has ANY entries in the spell table
  -- and whether any of those were actually evaluatable (known spell).
  local classHasSpells = false  -- true if at least one spell.class == playerClass
  local anySpellKnown  = false  -- true if at least one of those spells is in spellbook
  for _, spell in ipairs(DPB.Spells) do
    if spell.class == playerClass then
      classHasSpells = true
      if not PlayerKnowsSpell(spell.spellName) then
        DPBDebug("ScanBuffs: skipping " .. spell.spellName .. " (not in spellbook)")
      else
        anySpellKnown = true
        if spell.isGroupBuff then
          for _, unit in ipairs(units) do
            if UnitExists(unit) and not UnitIsDead(unit) then
              if ClassMatches(unit, spell.targetClass) then
                if not UnitHasBuff(unit, spell.buffName) then
                  DPBDebug("ScanBuffs: need " .. spell.spellName .. " (group) - " .. unit .. " missing " .. spell.buffName)
                  DPB.nextSpell  = spell.spellName
                  DPB.nextTarget = nil
                  DPB.nextIcon   = spell.icon
                  DPB.currentStatus = "Ready"
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
                if not UnitHasBuff(unit, spell.buffName) then
                  DPBDebug("ScanBuffs: need " .. spell.spellName .. " on " .. unit)
                  DPB.nextSpell  = spell.spellName
                  DPB.nextTarget = unit
                  DPB.nextIcon   = spell.icon
                  DPB.currentStatus = "Ready"
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
  -- [Bug B] Distinguish between "all buffs up" and "no spells known yet"
  DPB.nextSpell  = nil
  DPB.nextTarget = nil
  DPB.nextIcon   = nil
  if not playerClass then
    DPBDebug("ScanBuffs END: playerClass is nil. Can't match spells.")
    DPB.currentStatus = "Class Missing"
    if DPB.SetButtonReady then DPB:SetButtonReady(false, DPB.currentStatus) end
  elseif not classHasSpells then
    -- Player's class has no entries in the spell table at all
    DPBDebug("ScanBuffs END: no spells defined for class " .. tostring(playerClass))
    DPB.currentStatus = "No Spells"
    if DPB.SetButtonReady then DPB:SetButtonReady(false, DPB.currentStatus) end
  elseif not anySpellKnown then
    -- Class is supported but player hasn't trained any of the spells yet
    DPBDebug("ScanBuffs END: class matched but no spells in spellbook yet.")
    DPB.currentStatus = "Train Spells"
    if DPB.SetButtonReady then DPB:SetButtonReady(false, DPB.currentStatus) end
  else
    -- Genuinely all buffs are up
    DPBDebug("ScanBuffs END: all buffs are up.")
    DPB.currentStatus = "All Up"
    if DPB.UpdateButton then DPB:UpdateButton() end
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
    DPBEventDebug("PLAYER_LOGIN: class=" .. tostring(class))
    if class and class ~= "" then
      DPB.playerClass = class
    end
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
    local _, class = UnitClass("player")
    local isLogin, isReload = ...
    DPBEventDebug("PLAYER_ENTERING_WORLD: class=" .. tostring(class)
      .. " isLogin=" .. tostring(isLogin)
      .. " isReload=" .. tostring(isReload))
    if class and class ~= "" then
      DPB.playerClass = class
    end
    DPB:ScanBuffs()
  elseif event == "UNIT_AURA" then
    local unit = ...
    if unit == "player" or unit:match("^party") then
      DPBEventDebug("UNIT_AURA: unit=" .. tostring(unit))
      DPB:ScanBuffs()
    end
  elseif event == "GROUP_ROSTER_UPDATE"
      or event == "PARTY_MEMBERS_CHANGED"
      or event == "PLAYER_REGEN_ENABLED" then
    DPBEventDebug(event)
    DPB:ScanBuffs()
  end
end)
print("|cff00ff00[DynamicPartyBuff]|r Loaded. Happy buffing!")
