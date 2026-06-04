local KC = KeystoneCouncil

KC.TeleportButton = {
  result = nil,
  spellName = nil,
  pendingResult = nil,
  pendingHide = false,
}

local function GetSpellInfo(spellName)
  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, spellName)
    if ok and type(info) == "table" then
      return info
    end
  end

  if _G["GetSpellInfo"] then
    local ok, name, rank, icon = pcall(_G["GetSpellInfo"], spellName)
    if ok and name then
      return { name = name, iconID = icon }
    end
  end

  return nil
end

local function SpellExists(spellName)
  if not spellName or spellName == "" then
    return false
  end

  if C_Spell and C_Spell.IsSpellUsable then
    local ok, usable = pcall(C_Spell.IsSpellUsable, spellName)
    if ok then
      return usable == true
    end
  end

  if C_Spell and C_Spell.DoesSpellExist then
    local ok, exists = pcall(C_Spell.DoesSpellExist, spellName)
    if ok and exists then
      return true
    end
  end

  return GetSpellInfo(spellName) ~= nil
end

local function BuildTeleportSpellName(result)
  local dungeonName = result and result.dungeonName
  if (not dungeonName or dungeonName == "") and result and result.dungeonID then
    dungeonName = KC.DungeonRegistry:GetName(result.dungeonID)
  end

  if not dungeonName or dungeonName == "" then
    return nil
  end

  return "Teleport: " .. tostring(dungeonName)
end

function KC.TeleportButton:Create(parent)
  if self.button then
    return
  end

  local button = CreateFrame("Button", "KeystoneCouncilTeleportButton", parent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
  button:SetSize(126, 28)
  button:SetText("Teleport")
  button:SetAttribute("type", "spell")
  button:Hide()

  button:SetScript("OnEnter", function()
    if not self.spellName then
      return
    end

    GameTooltip:SetOwner(parent or UIParent, "ANCHOR_TOP")
    GameTooltip:SetText(self.spellName, 1, 0.82, 0.28)
    GameTooltip:AddLine("Click to cast the dungeon teleport if your character has unlocked it.", 0.95, 0.92, 0.84, true)
    GameTooltip:AddLine("WoW requires a real click and may block changes during combat.", 0.62, 0.62, 0.66, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  self.button = button
end

function KC.TeleportButton:AnchorTo(startButton)
  if not self.button or not startButton then
    return
  end

  self.button:ClearAllPoints()
  self.button:SetPoint("RIGHT", startButton, "LEFT", -10, 0)
end

function KC.TeleportButton:Hide()
  if InCombatLockdown and InCombatLockdown() then
    self.pendingHide = true
    self.pendingResult = nil
    return
  end

  if self.button then
    self.button:Hide()
  end
  self.result = nil
  self.spellName = nil
  self.pendingResult = nil
  self.pendingHide = false
end

function KC.TeleportButton:ShowForResult(result)
  if not self.button then
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    self.pendingResult = result
    self.pendingHide = false
    return
  end

  local spellName = BuildTeleportSpellName(result)
  if not SpellExists(spellName) then
    self:Hide()
    return
  end

  self.result = result
  self.spellName = spellName
  self.pendingResult = nil
  self.pendingHide = false

  self.button:SetAttribute("spell", spellName)
  self.button:SetText("Teleport")
  self.button:Show()
end

function KC.TeleportButton:RefreshLockdown()
  if InCombatLockdown and InCombatLockdown() then
    return
  end

  if self.pendingHide then
    self:Hide()
    return
  end

  if self.pendingResult then
    local result = self.pendingResult
    self.pendingResult = nil
    self:ShowForResult(result)
    return
  end

  if self.result and self.spellName and self.button then
    self.button:SetAttribute("spell", self.spellName)
    self.button:SetText("Teleport")
  end
end

function KC.TeleportButton:OnEnable()
  local frame = CreateFrame("Frame")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  frame:SetScript("OnEvent", function()
    self:RefreshLockdown()
  end)
  self.eventFrame = frame
end

KC:RegisterModule("TeleportButton", KC.TeleportButton)
