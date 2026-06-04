local KC = KeystoneCouncil

KC.PortalActions = {
  button = nil,
  status = nil,
  result = nil,
  action = nil,
  pendingResult = nil,
  pendingHide = false,
}

KC.PortalActions.dungeonPortals = {
  -- Future seasonal dungeon portal mappings should be updated here when Blizzard rotates the Mythic+ pool.
  [499] = { spellName = "Teleport: Priory of the Sacred Flame" },
  [500] = { spellName = "Teleport: The Rookery" },
  [501] = { spellName = "Teleport: The Stonevault" },
  [502] = { spellName = "Teleport: City of Threads" },
  [503] = { spellName = "Teleport: Ara-Kara, City of Echoes" },
  [504] = { spellName = "Teleport: Darkflame Cleft" },
  [505] = { spellName = "Teleport: The Dawnbreaker" },
  [506] = { spellName = "Teleport: Cinderbrew Meadery" },
  [507] = { spellName = "Teleport: Grim Batol" },
  [508] = { spellName = "Teleport: Siege of Boralus" },
  [509] = { spellName = "Teleport: Mists of Tirna Scithe" },
  [510] = { spellName = "Teleport: The Necrotic Wake" },
  [511] = { spellName = "Teleport: Operation: Floodgate" },
  [512] = { spellName = "Teleport: Theater of Pain" },
}

local function GetSpellInfo(spellName)
  if not spellName or spellName == "" then
    return nil
  end

  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, spellName)
    if ok and type(info) == "table" then
      return info
    end
  end

  if _G["GetSpellInfo"] then
    local ok, name, _, icon = pcall(_G["GetSpellInfo"], spellName)
    if ok and name then
      return { name = name, iconID = icon }
    end
  end

  return nil
end

local function SpellIsAvailable(spellName)
  if not spellName or spellName == "" then
    return false
  end

  if C_Spell and C_Spell.IsSpellUsable then
    local ok, usable = pcall(C_Spell.IsSpellUsable, spellName)
    if ok and usable == true then
      return true
    end
  end

  if C_Spell and C_Spell.DoesSpellExist then
    local ok, exists = pcall(C_Spell.DoesSpellExist, spellName)
    if ok and exists == true then
      return true
    end
  end

  return GetSpellInfo(spellName) ~= nil
end

function KC.PortalActions:GetPortalForDungeon(dungeonID, dungeonName)
  local portal = dungeonID and self.dungeonPortals[tonumber(dungeonID)]
  if portal then
    return portal
  end

  if dungeonName and dungeonName ~= "" then
    return {
      spellName = "Teleport: " .. tostring(dungeonName),
      inferred = true,
    }
  end

  return nil
end

function KC.PortalActions:GetActionForResult(result)
  if type(result) ~= "table" then
    return nil
  end

  local dungeonID = tonumber(result.dungeonID)
  local dungeonName = result.dungeonName
  if (not dungeonName or dungeonName == "") and dungeonID and KC.DungeonRegistry then
    dungeonName = KC.DungeonRegistry:GetName(dungeonID)
  end

  local portal = self:GetPortalForDungeon(dungeonID, dungeonName)
  if not portal or not SpellIsAvailable(portal.spellName) then
    return nil
  end

  return {
    type = "spell",
    spellName = portal.spellName,
    dungeonID = dungeonID,
    dungeonName = dungeonName,
    inferred = portal.inferred == true,
  }
end

function KC.PortalActions:GetStatusLine()
  if self.action and self.action.spellName then
    return "Portal Action: " .. tostring(self.action.spellName) .. " ready for click-to-cast"
  end
  return "Portal Action: unavailable until a finalized dungeon has an unlocked portal spell"
end

function KC.PortalActions:Create(parent)
  if self.button then
    return
  end

  local button = CreateFrame("Button", "KeystoneCouncilPortalActionButton", parent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
  button:SetSize(150, 28)
  button:SetText("Portal unavailable")
  button:SetAttribute("type", "spell")
  button:Disable()
  button:SetAlpha(0.62)

  button:SetScript("OnEnter", function()
    if not GameTooltip then
      return
    end
    GameTooltip:SetOwner(parent or UIParent, "ANCHOR_TOP")
    if self.action and self.action.spellName then
      GameTooltip:SetText(self.action.spellName, 1, 0.82, 0.28)
      GameTooltip:AddLine("Click to cast. Keystone Council never casts portal spells automatically.", 0.95, 0.92, 0.84, true)
    else
      GameTooltip:SetText("Portal action unavailable", 1, 0.82, 0.28)
      GameTooltip:AddLine("A dungeon portal appears here only when your character has an available click-to-cast spell.", 0.62, 0.62, 0.66, true)
    end
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)

  self.button = button
end

function KC.PortalActions:AnchorTo(startButton)
  if not self.button or not startButton then
    return
  end

  self.button:ClearAllPoints()
  self.button:SetPoint("RIGHT", startButton, "LEFT", -10, 0)
end

function KC.PortalActions:SetUnavailable(message)
  if not self.button then
    return
  end

  self.action = nil
  self.result = nil
  self.button:SetText(message or "Portal unavailable")
  self.button:SetAlpha(0.62)
  self.button:Disable()
  if not InCombatLockdown or not InCombatLockdown() then
    self.button:SetAttribute("spell", nil)
  end
end

function KC.PortalActions:Hide()
  if InCombatLockdown and InCombatLockdown() then
    self.pendingHide = true
    self.pendingResult = nil
    return
  end

  self.pendingHide = false
  self.pendingResult = nil
  self:SetUnavailable("Portal unavailable")
end

function KC.PortalActions:ShowForResult(result)
  if not self.button then
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    self.pendingResult = result
    self.pendingHide = false
    return
  end

  local action = self:GetActionForResult(result)
  if not action then
    self:SetUnavailable("Portal unavailable")
    return
  end

  self.result = result
  self.action = action
  self.pendingResult = nil
  self.pendingHide = false

  self.button:SetAttribute("type", "spell")
  self.button:SetAttribute("spell", action.spellName)
  self.button:SetText("Cast Portal")
  self.button:SetAlpha(1)
  self.button:Enable()
end

function KC.PortalActions:RefreshLockdown()
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
  elseif self.action and self.button then
    self.button:SetAttribute("spell", self.action.spellName)
  end
end

function KC.PortalActions:OnEnable()
  local frame = CreateFrame("Frame")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  frame:SetScript("OnEvent", function()
    self:RefreshLockdown()
  end)
  self.eventFrame = frame
end

KC:RegisterModule("PortalActions", KC.PortalActions)
