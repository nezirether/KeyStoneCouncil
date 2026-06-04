local KC = KeystoneCouncil

KC.ExternalKeyProvider = {
  available = false,
  lastImportCount = 0,
  lastImportSource = "none",
  lastError = nil,
  lastProbeLines = {},
}

local SOURCE_NAME = "ExternalKeyProvider"

local function FromBytes(...)
  local chars = {}
  for index = 1, select("#", ...) do
    chars[index] = string.char(select(index, ...))
  end
  return table.concat(chars)
end

local function ProviderName()
  return FromBytes(65, 115, 116, 114, 97, 108, 75, 101, 121, 115)
end

local function ProviderSettingsName()
  return ProviderName() .. "Settings"
end

local function GetProvider()
  return rawget(_G, ProviderName())
end

local function ReadField(value, keys)
  for _, key in ipairs(keys) do
    if value[key] ~= nil and value[key] ~= "" then
      return value[key]
    end
  end
  return nil
end

local function NormalizeEntry(value)
  if type(value) ~= "table" then
    return nil
  end

  local ownerName = ReadField(value, { "character", "name", "owner", "unit", "player" })
  local dungeonID = ReadField(value, { "dungeonID", "dungeon_id", "mapID", "challengeMapID", "map", "id" })
  local dungeonName = ReadField(value, { "dungeon", "dungeonName", "mapName", "instanceName" })
  local level = ReadField(value, { "level", "keyLevel", "key_level", "keystoneLevel" })
  local weeklyBest = ReadField(value, { "weeklyBest", "weekly_best", "bestLevel", "bestThisWeek", "weekBest", "weeklyLevel", "maxCompletedLevel" })
  local score = ReadField(value, { "score", "mythicScore", "mplusScore", "mplus_score", "rating", "dungeonScore" })

  if not ownerName or ((not dungeonID or tonumber(dungeonID) == 0) and not dungeonName) or not tonumber(level) or tonumber(level) <= 0 then
    return nil
  end

  return {
    ownerName = ownerName,
    ownerRealm = ReadField(value, { "realm", "ownerRealm", "realmName", "server" }),
    classFile = ReadField(value, { "classFile", "class" }),
    btag = ReadField(value, { "btag", "battleTag", "battle_tag" }),
    faction = ReadField(value, { "faction", "factionGroup" }),
    dungeonID = tonumber(dungeonID) or nil,
    dungeonName = dungeonName,
    level = tonumber(level),
    score = tonumber(score),
    weeklyBest = tonumber(weeklyBest),
    source = SOURCE_NAME,
  }
end

local function CollectEntries(container, imported)
  if type(container) ~= "table" then
    return 0
  end

  local added = 0
  for _, value in pairs(container) do
    local normalized = NormalizeEntry(value)
    if normalized then
      imported[#imported + 1] = normalized
      added = added + 1
    end
  end

  return added
end

local function ImportFromProviderAPI(imported, probeLines)
  local provider = GetProvider()
  if not (type(provider) == "table" and type(provider.GetKeys) == "function") then
    probeLines[#probeLines + 1] = "provider.GetKeys: unavailable"
    return 0, nil
  end

  local ok, keys = pcall(provider.GetKeys, provider)
  if not ok then
    probeLines[#probeLines + 1] = "provider.GetKeys: failed"
    return 0, "provider.GetKeys failed"
  end

  local count = CollectEntries(keys, imported)
  probeLines[#probeLines + 1] = "provider.GetKeys: " .. tostring(count)
  return count, "provider.GetKeys"
end

local function ImportFromCandidates(imported, probeLines)
  local provider = GetProvider()
  local providerSettings = rawget(_G, ProviderSettingsName())
  local sources = {
    { label = "AstralKeys saved variable", value = provider },
    { label = "provider.keys", value = provider and provider.keys },
    { label = "provider.characters", value = provider and provider.characters },
    { label = "provider.db.keys", value = provider and provider.db and provider.db.keys },
    { label = "provider.db.characters", value = provider and provider.db and provider.db.characters },
    { label = "provider.db.global.keys", value = provider and provider.db and provider.db.global and provider.db.global.keys },
    { label = "provider.db.global.characters", value = provider and provider.db and provider.db.global and provider.db.global.characters },
    { label = "AstralKeysSettings.keys", value = providerSettings and providerSettings.keys },
    { label = "AstralKeysSettings.characters", value = providerSettings and providerSettings.characters },
    { label = "AstralCharacters saved variable", value = rawget(_G, "AstralCharacters") },
  }

  for _, source in ipairs(sources) do
    local count = CollectEntries(source.value, imported)
    probeLines[#probeLines + 1] = source.label .. ": " .. tostring(count)
    if count > 0 then
      return count, source.label
    end
  end

  return 0, nil
end

function KC.ExternalKeyProvider:IsLoaded()
  local providerName = ProviderName()
  if C_AddOns and C_AddOns.IsAddOnLoaded then
    local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, providerName)
    if ok and loaded then
      return true
    end
  end
  return type(GetProvider()) == "table"
end

function KC.ExternalKeyProvider:OnEnable()
  self.available = self:IsLoaded()
  if self.available then
    local function ImportLater()
      self:Import()
    end

    if C_Timer and C_Timer.After then
      C_Timer.After(1, ImportLater)
    else
      ImportLater()
    end
  end
end

function KC.ExternalKeyProvider:Import()
  self.available = self:IsLoaded()
  if not self.available then
    self.lastImportCount = 0
    self.lastImportSource = "unavailable"
    self.lastError = "External key provider not loaded"
    self.lastProbeLines = {}
    if KC.KeyStore then
      KC.KeyStore:ClearSource(SOURCE_NAME)
    end
    return false
  end

  local imported = {}
  local probeLines = {}
  local count, source = ImportFromProviderAPI(imported, probeLines)

  if count == 0 then
    count, source = ImportFromCandidates(imported, probeLines)
  end

  self.lastImportCount = #imported
  self.lastImportSource = source or "none"
  self.lastError = nil
  self.lastProbeLines = probeLines

  if KC.KeyStore then
    KC.KeyStore:ReplaceSource(SOURCE_NAME, imported)
  end

  if #imported == 0 then
    self.lastError = "No compatible external key table found"
    KC.Logger:Print("External key provider is loaded, but Keystone Council could not read a compatible key table.")
    KC.Logger:Print("Party keys still require Keystone Council party sync unless external data is visible locally.")
    return false
  end

  KC.Logger:Print("Imported " .. tostring(#imported) .. " external key provider entr" .. (#imported == 1 and "y" or "ies") .. ".")
  return true
end

function KC.ExternalKeyProvider:GetStatusLine()
  if not self.available then
    return "External key provider: not loaded"
  end

  local line = "External key provider: loaded"
  if self.lastImportCount and self.lastImportCount > 0 then
    line = line .. ", imported " .. tostring(self.lastImportCount)
  end
  if self.lastImportSource and self.lastImportSource ~= "none" then
    line = line .. " via " .. tostring(self.lastImportSource)
  end
  if self.lastError then
    line = line .. " (" .. tostring(self.lastError) .. ")"
  end

  return line
end

function KC.ExternalKeyProvider:GetProbeLines()
  return self.lastProbeLines or {}
end

KC:RegisterModule("ExternalKeyProvider", KC.ExternalKeyProvider)
