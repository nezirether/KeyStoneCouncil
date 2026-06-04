local KC = KeystoneCouncil

KC.SharedKeyProvider = {
  lib = nil,
  registered = false,
  lastImportCount = 0,
  lastError = nil,
  lastRequestChannel = nil,
}

local SOURCE_NAME = "SharedKeyProvider"

local function FromBytes(...)
  local chars = {}
  for index = 1, select("#", ...) do
    chars[index] = string.char(select(index, ...))
  end
  return table.concat(chars)
end

local function LibraryName()
  return FromBytes(76, 105, 98, 75, 101, 121, 115, 116, 111, 110, 101)
end

function KC.SharedKeyProvider:IsAvailable()
  return LibStub and LibStub:GetLibrary(LibraryName(), true) or nil
end

function KC.SharedKeyProvider:BindLibrary()
  self.lib = self.lib or self:IsAvailable()
  if self.lib and self.lib.Register and not self.registered then
    self.lib.Register(self, function(...)
      self:OnSharedKeyUpdate(...)
    end)
    self.registered = true
  end
  return self.lib
end

function KC.SharedKeyProvider:OnSharedKeyUpdate(keyLevel, challengeMapID, playerRating, sender, channel, weeklyBest)
  if not sender or sender == "" or KC.Util:IsSelfSender(sender) then
    return
  end

  if not keyLevel or keyLevel <= 0 then
    return
  end

  self.lastImportCount = self.lastImportCount + 1
  self.lastError = nil

  KC.KeyStore:Upsert({
    ownerName = sender,
    dungeonID = challengeMapID,
    level = keyLevel,
    score = playerRating,
    weeklyBest = weeklyBest,
    source = SOURCE_NAME,
    updatedAt = time(),
  })
end

function KC.SharedKeyProvider:RequestPartyKeys()
  self.lastRequestChannel = "PARTY"
  local lib = self:BindLibrary()
  if not lib or not lib.Request then
    self.lastError = "Shared key provider unavailable"
    return false
  end

  self.lastImportCount = 0
  local ok, err = pcall(lib.Request, "PARTY")
  if not ok then
    self.lastError = tostring(err)
    return false
  end

  self.lastError = nil
  return true
end

function KC.SharedKeyProvider:RequestGuildKeys()
  self.lastRequestChannel = "GUILD"
  local lib = self:BindLibrary()
  if not lib or not lib.Request then
    self.lastError = "Shared key provider unavailable"
    return false
  end

  local ok, err = pcall(lib.Request, "GUILD")
  if not ok then
    self.lastError = tostring(err)
    return false
  end

  self.lastError = nil
  return true
end

function KC.SharedKeyProvider:GetStatusLine()
  if not self:BindLibrary() then
    return "Shared key provider: unavailable"
  end

  local line = "Shared key provider: ready"
  if self.lastImportCount and self.lastImportCount > 0 then
    line = line .. ", imported " .. tostring(self.lastImportCount)
  end
  if self.lastError then
    line = line .. " (" .. tostring(self.lastError) .. ")"
  end
  return line
end

function KC.SharedKeyProvider:OnEnable()
  self:BindLibrary()

  -- BigWigs ships LibKeystone. Depending on addon load order, it may appear just
  -- after Keystone Council initializes, so retry once shortly after login.
  if C_Timer and C_Timer.After then
    C_Timer.After(2, function()
      self:BindLibrary()
      if self.lib and self.lib.Request then
        pcall(self.lib.Request, "PARTY")
        pcall(self.lib.Request, "GUILD")
      end
    end)
  end
end

KC:RegisterModule("SharedKeyProvider", KC.SharedKeyProvider)
