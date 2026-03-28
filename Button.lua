print("|cffff0000[DPB] Button.lua LOADING|r")
-- Button.lua
-- DynamicPartyBuff: Secure dynamic buff button
-- v1.5.2 fixes:
--   [Fix D] UpdateButton All Up branch now calls SetButtonReady(true, nil)
--           so the button is full-alpha and green when all buffs are applied.
--           Previously called SetButtonReady(false) which dimmed the button
--           and overwrote the icon/label -- visual bug now corrected.
--   [Fix E] label initializes as "Loading..." so any failure to scan is obvious.
-- ============================================================
-- Default saved variable values
-- ============================================================
local DEFAULT_X    = 0
local DEFAULT_Y    = -200
local DEFAULT_SHOWN = true
-- ============================================================
-- Create the secure button frame
-- ============================================================
local button = CreateFrame(
  "Button",
  "DPB_Button",
  UIParent,
  "SecureActionButtonTemplate"
)
button:SetSize(52, 52)
button:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_X, DEFAULT_Y)
button:SetMovable(true)
button:EnableMouse(true)
button:RegisterForDrag("LeftButton")
button:SetClampedToScreen(true)
button:SetScript("OnDragStart", function(self)
  if not InCombatLockdown() then self:StartMoving() end
end)
button:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  DPB:SavePosition()
end)
button:RegisterForClicks("LeftButtonUp")
button:SetAttribute("type", "spell")
-- ============================================================
-- Textures & Visuals
-- ============================================================
local iconTex = button:CreateTexture(nil, "BACKGROUND")
iconTex:SetAllPoints(button)
iconTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
cooldown:SetAllPoints(button)
cooldown:SetDrawEdge(true)
cooldown:SetHideCountdownNumbers(false)
local border = button:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
border:SetSize(64, 64)
border:SetPoint("CENTER", button, "CENTER", 0, 0)
local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
label:SetPoint("BOTTOM", button, "BOTTOM", 0, -14)
label:SetTextColor(1, 1, 1, 1)
label:SetText("Loading...")
local targetLabel = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
targetLabel:SetPoint("TOP", button, "TOP", 0, 14)
targetLabel:SetTextColor(0.4, 0.9, 1, 1)
targetLabel:SetText("")
-- ============================================================
-- Tooltip
-- ============================================================
button:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  if DPB.nextSpell then
    local spellName, spellRank = GetSpellInfo(DPB.nextSpell)
    local displayName = spellName or DPB.nextSpell
    if spellRank and spellRank ~= "" then
      displayName = displayName .. " (" .. spellRank .. ")"
    end
    GameTooltip:SetText("|cffffd700" .. displayName .. "|r", 1, 1, 1)
    if DPB.nextTarget then
      local targetName = UnitName(DPB.nextTarget) or DPB.nextTarget
      GameTooltip:AddLine("Target: " .. targetName, 0.4, 0.9, 1)
    else
      GameTooltip:AddLine("Target: Whole Party", 0.4, 0.9, 1)
    end
    GameTooltip:AddLine("Left-click to cast.", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Drag to reposition.", 0.5, 0.5, 0.5)
  else
    local status = DPB.currentStatus or "All Up"
    if status == "All Up" then
      GameTooltip:SetText("|cff00ff00All buffs are up!|r", 1, 1, 1)
    else
      GameTooltip:SetText("|cffff4444Status: " .. status .. "|r", 1, 1, 1)
      if status == "Class Missing" then
        GameTooltip:AddLine("Addon could not determine your class.", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Try /reload or check for Lua errors.", 0.5, 0.5, 0.5)
      elseif status == "No Spells" then
        GameTooltip:AddLine("No spells defined for your class in Spells.lua.", 0.7, 0.7, 0.7)
      elseif status == "Train Spells" then
        GameTooltip:AddLine("You haven't trained these spells yet.", 0.7, 0.7, 0.7)
      elseif status == "In Combat" then
        GameTooltip:AddLine("Scanning disabled during combat.", 0.7, 0.7, 0.7)
      else
        GameTooltip:AddLine("Wait for scan to finish...", 0.7, 0.7, 0.7)
      end
    end
  end
  GameTooltip:Show()
end)
button:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
-- ============================================================
-- SavePosition
-- ============================================================
function DPB:SavePosition()
  local bX, bY = button:GetCenter()
  local sX, sY = UIParent:GetCenter()
  if not bX or not sX then return end
  DPB_SavedVars = DPB_SavedVars or {}
  DPB_SavedVars.x = bX - sX
  DPB_SavedVars.y = bY - sY
  DPB_SavedVars.shown = button:IsShown() and true or false
end
-- ============================================================
-- RestorePosition
-- ============================================================
function DPB:RestorePosition()
  DPB_SavedVars = DPB_SavedVars or {}
  local x     = DPB_SavedVars.x
  local y     = DPB_SavedVars.y
  local shown = DPB_SavedVars.shown
  if x    == nil then x    = DEFAULT_X    end
  if y    == nil then y    = DEFAULT_Y    end
  if shown == nil then shown = DEFAULT_SHOWN end
  button:ClearAllPoints()
  button:SetPoint("CENTER", UIParent, "CENTER", x, y)
  if shown then button:Show() else button:Hide() end
  print("|cff00ff00[DPB]|r Position restored (" .. string.format("%.0f", x) .. ", " .. string.format("%.0f", y) .. ")")
end
-- ============================================================
-- UpdateButton: called after every scan when a spell is ready or all up.
-- ============================================================
function DPB:UpdateButton()
  if InCombatLockdown() then return end
  if DPB.nextSpell then
    if DPB.debug then
      print("|cff00ff00[DPB]|r UpdateButton: spell=" .. tostring(DPB.nextSpell) .. " unit=" .. tostring(DPB.nextTarget))
    end
    button:SetAttribute("spell", DPB.nextSpell)
    if DPB.nextTarget then
      button:SetAttribute("unit", DPB.nextTarget)
      local targetName = UnitName(DPB.nextTarget) or DPB.nextTarget
      targetLabel:SetText(targetName)
    else
      button:SetAttribute("unit", nil)
      targetLabel:SetText("Party")
    end
    iconTex:SetTexture(DPB.nextIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
    local start, duration = GetSpellCooldown(DPB.nextSpell)
    if start and start > 0 then
      cooldown:SetCooldown(start, duration)
    else
      cooldown:SetCooldown(0, 0)
    end
    local shortSpell = DPB.nextSpell
    if #shortSpell > 13 then shortSpell = string.sub(shortSpell, 1, 13) .. "..." end
    label:SetText(shortSpell)
    DPB:SetButtonReady(true)
  else
    if DPB.debug then
      print("|cff00ff00[DPB]|r UpdateButton: All Up state")
    end
    iconTex:SetTexture("Interface\\Icons\\Spell_Holy_Resurrection")
    label:SetText("|cff00ff00All Up!|r")
    targetLabel:SetText("")
    button:SetAttribute("spell", nil)
    button:SetAttribute("unit", nil)
    cooldown:SetCooldown(0, 0)
    -- [Fix D] All Up IS a good state: full alpha, green border, no dimming.
    DPB:SetButtonReady(true, nil)
  end
end
-- ============================================================
-- SetButtonReady: visual enable / disable state.
-- ============================================================
function DPB:SetButtonReady(ready, statusText)
  if DPB.debug and statusText then
    print("|cff00ff00[DPB]|r SetButtonReady: ready=" .. tostring(ready) .. " status=" .. tostring(statusText))
  end
  if ready then
    border:SetVertexColor(1, 1, 1, 1)
    button:SetAlpha(1.0)
  else
    border:SetVertexColor(0.5, 0.5, 0.5, 0.8)
    button:SetAlpha(0.6)
    if statusText then
      iconTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
      label:SetText("|cffff4444" .. statusText .. "|r")
      targetLabel:SetText("")
    end
  end
end
-- ============================================================
-- Slash commands: /dpb
-- ============================================================
SLASH_DYNAMICPARTYBUFF1 = "/dpb"
SlashCmdList["DYNAMICPARTYBUFF"] = function(msg)
  local cmd = string.lower(msg or "")
  if cmd == "reset" then
    button:ClearAllPoints()
    button:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_X, DEFAULT_Y)
    button:Show()
    DPB:SavePosition()
    print("|cff00ff00[DPB]|r Button reset to default position.")
  elseif cmd == "debug" then
    DPB.debug = not DPB.debug
    if DPB.debug then
      print("|cff00ff00[DPB]|r Debug mode |cff00ff00ON|r")
      DPB:ScanBuffs()
    else
      print("|cff00ff00[DPB]|r Debug mode |cffff4444OFF|r")
    end
  elseif cmd == "debugevents" then
    DPB.debugEvents = not DPB.debugEvents
    if DPB.debugEvents then
      print("|cff00ff00[DPB]|r Event debug |cff00ff00ON|r - every event logs to chat.")
    else
      print("|cff00ff00[DPB]|r Event debug |cffff4444OFF|r")
    end
  elseif cmd == "help" then
    print("|cff00ff00[DPB]|r Commands:")
    print(" |cffffff00/dpb|r - toggle button visibility")
    print(" |cffffff00/dpb reset|r - move button to default position")
    print(" |cffffff00/dpb debug|r - toggle scan debug output")
    print(" |cffffff00/dpb debugevents|r - toggle event-level logging")
    print(" |cffffff00/dpb help|r - show this help")
  else
    if button:IsShown() then
      button:Hide()
      DPB:SavePosition()
      print("|cff00ff00[DPB]|r Button hidden. Type /dpb to show again.")
    else
      button:Show()
      DPB:SavePosition()
      print("|cff00ff00[DPB]|r Button shown.")
    end
  end
end
-- NOTE: PLAYER_LOGIN is owned by Core.lua which calls DPB:RestorePosition()
-- before DPB:ScanBuffs(). No unconditional Show() here to avoid flicker.
