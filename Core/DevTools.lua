local KC = KeystoneCouncil

KC.DevTools = {
  unlocked = false,
  password = "BlameChopper",
  source = "Dev",
}

local fakePartyKeys = {
  { ownerGUID = "Dev-Party-1", ownerName = "Nez", ownerRealm = "Area52", classFile = "MAGE", dungeonID = 503, level = 15, score = 2450, weeklyBest = 12 },
  { ownerGUID = "Dev-Party-2", ownerName = "Chopper", ownerRealm = "Area52", classFile = "ROGUE", dungeonID = 504, level = 14, score = 2100, weeklyBest = 14 },
  { ownerGUID = "Dev-Party-3", ownerName = "Volk", ownerRealm = "Area52", classFile = "WARRIOR", dungeonID = 505, level = 13, score = 1850, weeklyBest = 10 },
  { ownerGUID = "Dev-Party-4", ownerName = "Dym", ownerRealm = "Area52", classFile = "PRIEST", dungeonID = 511, level = 16, score = 2600, weeklyBest = 16 },
  { ownerGUID = "Dev-Party-5", ownerName = "Gears", ownerRealm = "Area52", classFile = "HUNTER", dungeonID = 506, level = 12, score = 1600, weeklyBest = 8 },
}

local fakeLedgerKeys = {
  { ownerGUID = "Dev-Ledger-1", ownerName = "Vaultdad", ownerRealm = "Area52", classFile = "PALADIN", dungeonID = 503, level = 10, score = 1200, weeklyBest = 4 },
  { ownerGUID = "Dev-Ledger-2", ownerName = "Scoregap", ownerRealm = "Area52", classFile = "DRUID", dungeonID = 504, level = 17, score = 900, weeklyBest = 9 },
  { ownerGUID = "Dev-Ledger-3", ownerName = "Latejoin", ownerRealm = "Area52", classFile = "SHAMAN", dungeonID = 505, level = 8, score = 700, weeklyBest = 0 },
  { ownerGUID = "Dev-Ledger-4", ownerName = "Guildbank", ownerRealm = "Area52", classFile = "WARLOCK", dungeonID = 511, level = 18, score = 2800, weeklyBest = 18 },
  { ownerGUID = "Dev-Ledger-5", ownerName = "Mirror", ownerRealm = "Area52", classFile = "MONK", dungeonID = 506, level = 11, score = 1500, weeklyBest = 10 },
  { ownerGUID = "Dev-Ledger-6", ownerName = "Mirror", ownerRealm = "Stormrage", classFile = "EVOKER", dungeonID = 507, level = 12, score = 1520, weeklyBest = 11 },
}

function KC.DevTools:IsUnlocked()
  return self.unlocked == true
end

function KC.DevTools:Unlock(password)
  if password == self.password then
    self.unlocked = true
    KC.Logger:Print("Developer area unlocked.")
    return true
  end

  KC.Logger:Error("Developer password rejected.")
  return false
end

function KC.DevTools:RequireUnlocked()
  if self:IsUnlocked() then
    return true
  end

  KC.Logger:Print("Developer area locked. Use /kc dev <password>.")
  return false
end

function KC.DevTools:AddFakeParty()
  if not self:RequireUnlocked() then
    return false
  end

  KC.KeyStore:ClearSource(self.source)
  for _, key in ipairs(fakePartyKeys) do
    local copy = {}
    for field, value in pairs(key) do
      copy[field] = value
    end
    copy.source = self.source
    copy.devParty = true
    copy.updatedAt = time()
    KC.KeyStore:Upsert(copy)
  end

  if KC.MainFrame then
    KC.MainFrame:Show()
  end
  if KC.KeyList and KC.KeyList.SetView then
    KC.KeyList:SetView("party")
  end
  KC.Logger:Print("Developer fake party keys loaded.")
  return true
end

function KC.DevTools:AddFakeLedger()
  if not self:RequireUnlocked() then
    return false
  end

  for _, key in ipairs(fakeLedgerKeys) do
    local copy = {}
    for field, value in pairs(key) do
      copy[field] = value
    end
    copy.source = self.source
    copy.updatedAt = time()
    KC.KeyStore:Upsert(copy)
  end

  KC.Logger:Print("Developer fake ledger keys loaded.")
  return true
end

function KC.DevTools:AddStaleKey()
  if not self:RequireUnlocked() then
    return false
  end

  if KC.KeyLedger then
    KC.KeyLedger:Record({
      ownerName = "Oldreset",
      ownerRealm = "Area52",
      classFile = "DEATHKNIGHT",
      dungeonID = 503,
      level = 20,
      source = self.source,
      updatedAt = time() - (9 * 24 * 60 * 60),
    })
  end

  KC.Logger:Print("Developer stale key loaded into ledger.")
  return true
end

function KC.DevTools:ClearFakeData()
  if not self:RequireUnlocked() then
    return false
  end

  KC.KeyStore:ClearSource(self.source)
  if KC.KeyLedger then
    KC.KeyLedger:ForgetSource(self.source)
  end
  KC.SessionStore:ClearVotes()
  KC.EventBus:Emit(KC.EVENTS.KEYS_CHANGED, KC.KeyStore:GetAll())
  KC.Logger:Print("Developer fake keys cleared.")
  return true
end

function KC.DevTools:Open()
  if not self:RequireUnlocked() then
    return false
  end

  if KC.DevPanel then
    KC.DevPanel:Toggle()
  end
  return true
end

KC:RegisterModule("DevTools", KC.DevTools)
