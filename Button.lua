-- Button.lua
-- DynamicPartyBuff: Secure dynamic buff button
-- Uses SecureActionButtonTemplate so it works with the WoW protected action system.
-- The button is draggable and shows the next spell icon + tooltip.

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
button:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
button:SetMovable(true)
button:EnableMouse(true)
button:RegisterForDrag("LeftButton")
button:SetClampedToScreen(true)
button:SetScript("OnDragStart", function(self)
  if not InCombatLockdown() then
    self:StartMoving()
  end
end)
button:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
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
local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
cooldown:SetAllPoints(button)

-- Gloss / border overlay
local border = button:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
border:SetSize(64, 64)
border:SetPoint("CENTER", button, "CENTER", 0, 0)

-- Status label (spell name or status text at bottom of button)
local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
label:SetPoint("BOTTOM", button, "BOTTOM", 0, -14)
label:SetTextColor(1, 1, 1, 1)
label:SetText("Scanning...")

-- Target name label (shows who is being buffed)
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
    GameTooltip:SetText("|cffffd700" .. DPB.nextSpell .. "|r", 1, 1, 1)
    local targetName = DPB.nextTarget and UnitName(DPB.nextTarget) or "Party"
    GameTooltip:AddLine("Target: " .. (targetName or DPB.nextTarget), 0.4, 0.9, 1)
    GameTooltip:AddLine("Left-click to cast.", 0.7, 0.7, 0.7)
  else
    GameTooltip:SetText("|cff00ff00All buffs are up!|r", 1, 1, 1)
  end
  GameTooltip:Show()
end)
button:SetScript("OnLeave", function(self)
  GameTooltip:Hide()
end)

-- ============================================================
-- UpdateButton: called by Core.lua after a scan
-- Wires up secure attributes and updates visuals.
-- ============================================================
function DPB:UpdateButton()
  -- Must not be in combat to change secure attributes
  if InCombatLockdown() then return end

  if DPB.nextSpell and DPB.nextTarget then
    -- Update secure attributes for the protected cast
    button:SetAttribute("spell", DPB.nextSpell)
    button:SetAttribute("unit",  DPB.nextTarget)

    -- Update icon
    iconTex:SetTexture(DPB.nextIcon or "Interface\\Icons\\INV_Misc_QuestionMark")

    -- Update labels
    local targetName = UnitName(DPB.nextTarget) or DPB.nextTarget
    local shortSpell = DPB.nextSpell
    -- Shorten long spell names for the label
    if string.len(shortSpell) > 14 then
      shortSpell = string.sub(shortSpell, 1, 13) .. "..."
    end
    label:SetText(shortSpell)
    targetLabel:SetText(targetName)

    button:SetAlpha(1.0)
    DPB:SetButtonReady(true)
  else
    -- No buffs needed
    iconTex:SetTexture("Interface\\Icons\\Spell_Holy_Resurrection")  -- Green checkmark-like icon
    label:SetText("|cff00ff00All Up!|r")
    targetLabel:SetText("")
    button:SetAttribute("spell", nil)
    button:SetAttribute("unit",  nil)
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
-- Slash command: /dpb  (toggle visibility)
-- ============================================================
SLASH_DYNAMICPARTYBUFF1 = "/dpb"
SlashCmdList["DYNAMICPARTYBUFF"] = function(msg)
  if button:IsShown() then
    button:Hide()
    print("|cff00ff00[DPB]|r Button hidden. Type /dpb to show again.")
  else
    button:Show()
    print("|cff00ff00[DPB]|r Button shown.")
  end
end

button:Show()
