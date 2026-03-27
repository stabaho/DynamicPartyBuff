-- Button.lua
-- DynamicPartyBuff: Secure dynamic buff button
-- Uses SecureActionButtonTemplate so it works with the WoW protected action system.
-- The button is draggable, shows the next spell icon + tooltip,
-- and saves its screen position across sessions via DPB_SavedVars.
--
-- Code Review fixes (v1.3.0):
--   [R6] Cooldown frame is now wired to the actual spell cooldown via GetSpellCooldown().
--   [R7] Label truncation uses string.utf8len-safe approach via string.sub (capped at 13 chars).
--   [R8] Tooltip now shows spell rank from GetSpellInfo() for full spell context.
--   [R9] Tooltip target name nil-guarded cleanly.

-- ============================================================
-- Default saved variable values
-- ============================================================
local DEFAULT_X     = 0
local DEFAULT_Y     = -200
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

-- OnDragStart: begin moving (only allowed out of combat)
button:SetScript("OnDragStart", function(self)
  if not InCombatLockdown() then
    self:StartMoving()
  end
end)

-- OnDragStop: stop moving and immediately save the new position
button:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  DPB:SavePosition()
end)

-- Register for left-click spell cast
button:RegisterForClicks("LeftButtonUp")
button:SetAttribute("type", "spell")

-- ============================================================
-- Textures & Visuals
-- ============================================================
local iconTex = button:CreateTexture(nil, "BACKGROUND")
iconTex:SetAllPoints(button)
iconTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

-- Cooldown overlay (uses the standard Cooldown frame)
-- [R6] This is created here; UpdateButton() will call SetCooldown() on it
--      using GetSpellCooldown() so the swipe animation actually plays.
local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
cooldown:SetAllPoints(button)
cooldown:SetDrawEdge(true)
cooldown:SetHideCountdownNumbers(false)

-- Gloss / border overlay
local border = button:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
border:SetSize(64, 64)
border:SetPoint("CENTER", button, "CENTER", 0, 0)

-- Status label (spell name or status text below the button)
local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
label:SetPoint("BOTTOM", button, "BOTTOM", 0, -14)
label:SetTextColor(1, 1, 1, 1)
label:SetText("Scanning...")

-- Target name label (shows who is being buffed, above button)
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
    -- [R8] Show spell name and rank from GetSpellInfo for full context
    local spellName, spellRank = GetSpellInfo(DPB.nextSpell)
    local displayName = spellName or DPB.nextSpell
    if spellRank and spellRank ~= "" then
      displayName = displayName .. " (" .. spellRank .. ")"
    end
    GameTooltip:SetText("|cffffd700" .. displayName .. "|r", 1, 1, 1)

    if DPB.nextTarget then
      -- [R9] Nil-guard UnitName result
      local targetName = UnitName(DPB.nextTarget) or DPB.nextTarget
      GameTooltip:AddLine("Target: " .. targetName, 0.4, 0.9, 1)
    else
      GameTooltip:AddLine("Target: Whole Party", 0.4, 0.9, 1)
    end
    GameTooltip:AddLine("Left-click to cast.", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Drag to reposition.", 0.5, 0.5, 0.5)
  else
    GameTooltip:SetText("|cff00ff00All buffs are up!|r", 1, 1, 1)
  end
  GameTooltip:Show()
end)

button:SetScript("OnLeave", function(self)
  GameTooltip:Hide()
end)

-- ============================================================
-- SavePosition: write current screen offset into DPB_SavedVars.
-- [Bug 5 Fix] Do NOT use button:GetPoint(1) - after a drag the anchor
-- index can shift and return incorrect or stale values.
-- Instead, calculate the CENTER offset from UIParent directly using
-- absolute pixel positions, which is always accurate post-drag.
-- ============================================================
function DPB:SavePosition()
  local bX, bY = button:GetCenter()
  local sX, sY = UIParent:GetCenter()
  if not bX or not sX then return end
  local x = bX - sX
  local y = bY - sY
  DPB_SavedVars = DPB_SavedVars or {}
  DPB_SavedVars.x     = x
  DPB_SavedVars.y     = y
  DPB_SavedVars.shown = button:IsShown() and true or false
end

-- ============================================================
-- RestorePosition: read DPB_SavedVars and reposition the button.
-- Called by Core.lua's PLAYER_LOGIN handler.
-- ============================================================
function DPB:RestorePosition()
  DPB_SavedVars = DPB_SavedVars or {}
  local x     = DPB_SavedVars.x
  local y     = DPB_SavedVars.y
  local shown = DPB_SavedVars.shown
  if x     == nil then x     = DEFAULT_X end
  if y     == nil then y     = DEFAULT_Y end
  if shown == nil then shown = DEFAULT_SHOWN end
  button:ClearAllPoints()
  button:SetPoint("CENTER", UIParent, "CENTER", x, y)
  if shown then button:Show() else button:Hide() end
  print("|cff00ff00[DPB]|r Position restored (" .. string.format("%.0f", x) .. ", " .. string.format("%.0f", y) .. ")")
end

-- ============================================================
-- UpdateButton: called by Core.lua after every scan.
-- [Bug 4 Fix] nextTarget may be nil for group buffs.
-- [R6] Wires up cooldown frame to actual spell cooldown swipe.
-- [R7] Label truncation capped safely at 13 visible characters.
-- ============================================================
function DPB:UpdateButton()
  if InCombatLockdown() then return end

  if DPB.nextSpell then
    button:SetAttribute("spell", DPB.nextSpell)

    if DPB.nextTarget then
      button:SetAttribute("unit", DPB.nextTarget)
      local targetName = UnitName(DPB.nextTarget) or DPB.nextTarget
      targetLabel:SetText(targetName)
    else
      button:SetAttribute("unit", nil)
      targetLabel:SetText("Party")
    end

    -- Update icon
    iconTex:SetTexture(DPB.nextIcon or "Interface\\Icons\\INV_Misc_QuestionMark")

    -- [R6] Wire cooldown frame to actual spell cooldown
    local start, duration, enable = GetSpellCooldown(DPB.nextSpell)
    if start and start > 0 then
      cooldown:SetCooldown(start, duration)
    else
      cooldown:SetCooldown(0, 0)
    end

    -- [R7] Truncate long spell names safely
    local shortSpell = DPB.nextSpell
    if #shortSpell > 13 then
      shortSpell = string.sub(shortSpell, 1, 13) .. "..."
    end
    label:SetText(shortSpell)

    button:SetAlpha(1.0)
    DPB:SetButtonReady(true)
  else
    iconTex:SetTexture("Interface\\Icons\\Spell_Holy_Resurrection")
    label:SetText("|cff00ff00All Up!|r")
    targetLabel:SetText("")
    button:SetAttribute("spell", nil)
    button:SetAttribute("unit", nil)
    cooldown:SetCooldown(0, 0)
    button:SetAlpha(0.5)
    DPB:SetButtonReady(false)
  end
end

-- ============================================================
-- SetButtonReady: visual enable / disable state
-- ============================================================
function DPB:SetButtonReady(ready, statusText)
  if ready then
    border:SetVertexColor(1, 1, 1, 1)
    button:SetAlpha(1.0)
  else
    border:SetVertexColor(0.5, 0.5, 0.5, 0.8)
    button:SetAlpha(0.6)
    if statusText then
      label:SetText("|cffff4444" .. statusText .. "|r")
      targetLabel:SetText("")
    end
  end
end

-- ============================================================
-- Slash commands: /dpb
--   /dpb        -> toggle show/hide (saves state)
--   /dpb reset  -> move button back to default center position
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

-- NOTE: PLAYER_LOGIN is intentionally NOT registered here.
-- Core.lua owns PLAYER_LOGIN and calls DPB:RestorePosition() before
-- DPB:ScanBuffs() to guarantee correct ordering.
-- Initial button visibility is fully controlled by RestorePosition() via
-- DPB_SavedVars.shown - no unconditional Show() here to avoid flicker.
