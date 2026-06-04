local KC = KeystoneCouncil

KC.GroupKeyProvider = {
  lib = nil,
  registered = false,
  lastImportCount = 0,
  lastError = nil,
}

local SOURCE_NAME = "GroupKeyProvider"

local function FromBytes(...)
  local chars = {}
  for index = 1, select("#", ...) do
    chars[index] = string.char(select(index, ...))
  end
  return table.concat(chars)
end

local function LibraryName()
  return FromBytes(76, 105, 98, 79, 112, 101, 110, 82, 97, 105, 100, 45, 49, 46, 48)
end

local function NormalizeGroupMapID(keystoneInfo)
  return keystoneInfo.challengeMapID or keystoneInfo.mythicPlusMapID or keystoneInfo.mapID
end

local function ClassFileFromID(classID)
  if classID and GetClassInfo then
    return select(2, GetClassInfo(classID))
  end
  return nil
end

function KC.GroupKeyProvider:IsAvailable()
  return LibStub and LibStub:GetLibrary(LibraryName(), true) or nil
end

function KC.GroupKeyProvider:BindLibrary()
  self.lib = self.lib or self:IsAvailable()
  if self.lib and self.lib.RegisterCallback and not self.registered then
    pcall(self.lib.RegisterCallback, self, "KeystoneUpdate", "OnKeystoneUpdate")
    self.registered = true
  end
  return self.lib
end

function KC.GroupKeyProvider:ImportAllKeystones()
  local lib = self:BindLibrary()
  if not lib or not lib.GetAllKeystonesInfo then
    self.lastError = "Group key provider unavailable"
    return false
  end

  local ok, allKeystones = pcall(lib.GetAllKeystonesInfo)
  if not ok or type(allKeystones) ~= "table" then
    self.lastError = ok and "No keystone table returned" or tostring(allKeystones)
    return false
  end

  self.lastImportCount = 0
  for unitName, keystoneInfo in pairs(allKeystones) do
    if type(keystoneInfo) == "table" and tonumber(keystoneInfo.level) and tonumber(keystoneInfo.level) > 0 then
      self.lastImportCount = self.lastImportCount + 1
      KC.KeyStore:Upsert({
        ownerName = unitName,
        unitID = unitName,
        classFile = ClassFileFromID(keystoneInfo.classID),
        dungeonID = NormalizeGroupMapID(keystoneInfo),
        level = keystoneInfo.level,
        score = keystoneInfo.score or keystoneInfo.mythicScore or keystoneInfo.rating or keystoneInfo.dungeonScore,
        weeklyBest = keystoneInfo.weeklyBest or keystoneInfo.bestLevel or keystoneInfo.bestThisWeek or keystoneInfo.maxCompletedLevel,
        source = SOURCE_NAME,
        updatedAt = time(),
      })
    end
  end

  self.lastError = nil
  return true
end

function KC.GroupKeyProvider:RequestPartyKeys()
  local lib = self:BindLibrary()
  if not lib then
    self.lastError = "Group key provider unavailable"
    return false
  end

  local ok = true
  if IsInRaid and IsInRaid() and lib.RequestKeystoneDataFromRaid then
    ok = pcall(lib.RequestKeystoneDataFromRaid)
  elseif IsInGroup and IsInGroup() and lib.RequestKeystoneDataFromParty then
    ok = pcall(lib.RequestKeystoneDataFromParty)
  else
    self.lastError = "Not grouped"
    return false
  end

  if not ok then
    self.lastError = "Keystone request failed"
    return false
  end

  self.lastError = nil
  self:ImportAllKeystones()
  return true
end

function KC.GroupKeyProvider:OnKeystoneUpdate(unitID, keystoneInfo, allKeystonesInfo)
  if allKeystonesInfo then
    self:ImportAllKeystones()
    return
  end

  if not keystoneInfo or not tonumber(keystoneInfo.level) or tonumber(keystoneInfo.level) <= 0 then
    return
  end

  local ownerName = unitID
  if self.lib and self.lib.GetUnitInfo then
    local ok, unitInfo = pcall(self.lib.GetUnitInfo, unitID)
    if ok and type(unitInfo) == "table" and unitInfo.name then
      ownerName = unitInfo.name
    end
  end

  self.lastImportCount = self.lastImportCount + 1
  self.lastError = nil

  KC.KeyStore:Upsert({
    ownerName = ownerName,
    classFile = ClassFileFromID(keystoneInfo.classID),
    dungeonID = NormalizeGroupMapID(keystoneInfo),
    level = keystoneInfo.level,
    score = keystoneInfo.score or keystoneInfo.mythicScore or keystoneInfo.rating or keystoneInfo.dungeonScore,
    weeklyBest = keystoneInfo.weeklyBest or keystoneInfo.bestLevel or keystoneInfo.bestThisWeek or keystoneInfo.maxCompletedLevel,
    source = SOURCE_NAME,
    updatedAt = time(),
  })
end

function KC.GroupKeyProvider:GetStatusLine()
  if not self:BindLibrary() then
    return "Group key provider: unavailable"
  end

  local line = "Group key provider: ready"
  if self.lastImportCount and self.lastImportCount > 0 then
    line = line .. ", imported " .. tostring(self.lastImportCount)
  end
  if self.lastError then
    line = line .. " (" .. tostring(self.lastError) .. ")"
  end
  return line
end

function KC.GroupKeyProvider:OnEnable()
  self:BindLibrary()
  self:ImportAllKeystones()
end

KC:RegisterModule("GroupKeyProvider", KC.GroupKeyProvider)
