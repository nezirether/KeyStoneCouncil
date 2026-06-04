local KC = KeystoneCouncil

KC.KeyStore = {
  keys = {},
  order = {},
  silent = false,
}

local function KeyID(key)
  return tostring(key.ownerGUID or key.ownerName or "unknown") .. ":" .. tostring(key.dungeonID or key.dungeonName or "dungeon") .. ":" .. tostring(key.level or 0)
end

local function CleanString(value, fallback)
  value = tostring(value or fallback or "")
  value = string.gsub(value, "^%s+", "")
  value = string.gsub(value, "%s+$", "")
  return value
end

local function BlankToNil(value)
  value = CleanString(value)
  return value ~= "" and value or nil
end

local function OwnerID(key)
  if key.ownerGUID and key.ownerGUID ~= "" then
    return key.ownerGUID
  end

  return KC.Util:NormalizePlayerName(KC.Util:BuildFullName(key.ownerName, key.ownerRealm) or key.ownerName or "unknown") or "unknown"
end

local function OwnerNameID(key)
  return KC.Util:NormalizePlayerName(KC.Util:BuildFullName(key.ownerName, key.ownerRealm) or key.ownerName or "unknown") or "unknown"
end

local function BaseOwnerName(name)
  name = tostring(name or "unknown")
  name = string.gsub(name, "%s+", "")
  name = string.match(name, "^([^-]+)") or name
  return name ~= "" and name or "unknown"
end

local function DisplayOwnerID(key)
  if key and key.ownerGUID and key.ownerGUID ~= "" then
    return key.ownerGUID
  end

  return OwnerNameID(key or {})
end

local function SameOwner(a, b)
  if not a or not b then
    return false
  end

  if a.ownerGUID and a.ownerGUID ~= "" and b.ownerGUID and b.ownerGUID ~= "" then
    return a.ownerGUID == b.ownerGUID
  end

  if a.ownerGUID and a.ownerGUID ~= "" and b.ownerGUID == a.ownerGUID then
    return true
  end

  if b.ownerGUID and b.ownerGUID ~= "" and a.ownerGUID == b.ownerGUID then
    return true
  end

  return OwnerNameID(a) == OwnerNameID(b)
end

local sourcePriority = {
  Blizzard = 100,
  PartySync = 95,
  PartySyncLedger = 92,
  GroupKeyProvider = 90,
  SharedKeyProvider = 85,
  ExternalKeyProvider = 60,
  AstralBridge = 55,
  Dev = 10,
  Test = 10,
  Unknown = 0,
}

local function SourcePriority(source)
  return sourcePriority[source or "Unknown"] or 0
end

local validSortModes = {
  level = true,
  dungeon = true,
  owner = true,
  score = true,
  weekly = true,
  seen = true,
}

local function SortMode()
  local options = KeystoneCouncilDB and KeystoneCouncilDB.profile and KeystoneCouncilDB.profile.options or {}
  if validSortModes[options.keySortMode] then
    return options.keySortMode
  end
  return "level"
end

local function DungeonSortName(key)
  if KC.DungeonRegistry and KC.DungeonRegistry.GetShortName then
    return KC.DungeonRegistry:GetShortName(key.dungeonID)
  end
  return tostring(key.dungeonName or key.dungeonID or "")
end

local function CompareKeys(a, b)
  local mode = SortMode()
  if a.isStale ~= b.isStale then
    return not a.isStale
  end

  if mode == "dungeon" then
    local aDungeon = DungeonSortName(a)
    local bDungeon = DungeonSortName(b)
    if aDungeon ~= bDungeon then
      return aDungeon < bDungeon
    end
  elseif mode == "owner" then
    local aOwner = tostring(a.ownerName or "")
    local bOwner = tostring(b.ownerName or "")
    if aOwner ~= bOwner then
      return aOwner < bOwner
    end
  elseif mode == "score" then
    local aScore = tonumber(a.score) or 0
    local bScore = tonumber(b.score) or 0
    if aScore ~= bScore then
      return aScore > bScore
    end
  elseif mode == "weekly" then
    local aWeekly = tonumber(a.weeklyBest) or 0
    local bWeekly = tonumber(b.weeklyBest) or 0
    if aWeekly ~= bWeekly then
      return aWeekly > bWeekly
    end
  elseif mode == "seen" then
    local aSeen = tonumber(a.lastSeenAt or a.updatedAt) or 0
    local bSeen = tonumber(b.lastSeenAt or b.updatedAt) or 0
    if aSeen ~= bSeen then
      return aSeen > bSeen
    end
  end

  local aLevel = tonumber(a.level) or 0
  local bLevel = tonumber(b.level) or 0
  if aLevel ~= bLevel then
    return aLevel > bLevel
  end

  return tostring(a.ownerName or "") < tostring(b.ownerName or "")
end

local function ShouldReplaceOwnerEntry(existing, incoming)
  if not existing then
    return true
  end

  local existingPriority = SourcePriority(existing.source)
  local incomingPriority = SourcePriority(incoming.source)
  if incomingPriority ~= existingPriority then
    return incomingPriority > existingPriority
  end

  local existingUpdated = tonumber(existing.updatedAt) or 0
  local incomingUpdated = tonumber(incoming.updatedAt) or 0
  if incomingUpdated ~= existingUpdated then
    return incomingUpdated >= existingUpdated
  end

  return (tonumber(incoming.level) or 0) >= (tonumber(existing.level) or 0)
end

local function ShouldDisplayEntry(existing, incoming)
  if not existing then
    return true
  end

  if existing.isStale ~= incoming.isStale then
    return not incoming.isStale
  end

  local existingUpdated = tonumber(existing.lastSeenAt or existing.updatedAt) or 0
  local incomingUpdated = tonumber(incoming.lastSeenAt or incoming.updatedAt) or 0
  if existingUpdated ~= incomingUpdated then
    return incomingUpdated > existingUpdated
  end

  local existingPriority = SourcePriority(existing.source)
  local incomingPriority = SourcePriority(incoming.source)
  if existingPriority ~= incomingPriority then
    return incomingPriority > existingPriority
  end

  return (tonumber(incoming.level) or 0) > (tonumber(existing.level) or 0)
end

local function IsDevPartyKey(key)
  return key
    and key.devParty == true
    and KC.DevTools
    and KC.DevTools.IsUnlocked
    and KC.DevTools:IsUnlocked()
end

local function MatchesView(key, view)
  if view == "party" then
    return IsDevPartyKey(key) or KC.Util:IsPartyMember(key.ownerName, key.ownerRealm)
  end

  if view == "friends" then
    return key.sourceBucket == "friends" or KC.Util:IsFriend(key.ownerName, key.ownerRealm)
  end

  if view == "guild" then
    return key.sourceBucket == "guild" or KC.Util:IsGuildMember(key.ownerName, key.ownerRealm)
  end

  return false
end

function KC.KeyStore:DeduplicateByOwner(keys)
  local byOwner = {}
  local order = {}

  for _, key in ipairs(keys or {}) do
    local ownerID = DisplayOwnerID(key)
    if not byOwner[ownerID] then
      order[#order + 1] = ownerID
      byOwner[ownerID] = key
    elseif ShouldDisplayEntry(byOwner[ownerID], key) then
      byOwner[ownerID] = key
    end
  end

  local result = {}
  for _, ownerID in ipairs(order) do
    result[#result + 1] = byOwner[ownerID]
  end

  return self:SortKeys(result)
end

function KC.KeyStore:GetSortMode()
  return SortMode()
end

function KC.KeyStore:SetSortMode(mode)
  mode = tostring(mode or "")
  if not validSortModes[mode] then
    return false
  end

  KeystoneCouncilDB.profile = KeystoneCouncilDB.profile or {}
  KeystoneCouncilDB.profile.options = KeystoneCouncilDB.profile.options or {}
  KeystoneCouncilDB.profile.options.keySortMode = mode
  KC.EventBus:Emit(KC.EVENTS.KEYS_CHANGED, self:GetAll())
  return true
end

function KC.KeyStore:SortKeys(keys)
  table.sort(keys, CompareKeys)
  return keys
end

function KC.KeyStore:Normalize(input)
  input = KC.Util:EnrichKeyData(input or {})
  if KC.ExternalScoreProvider and KC.ExternalScoreProvider.EnrichKey then
    input = KC.ExternalScoreProvider:EnrichKey(input)
  end

  local inputDungeonID = tonumber(input.dungeonID)
  local inputDungeonName = CleanString(input.dungeonName)
  local dungeon = inputDungeonID and KC.DungeonRegistry.byID[inputDungeonID] or KC.DungeonRegistry:FindByName(inputDungeonName)
  local dungeonID = inputDungeonID or (dungeon and dungeon.id) or 0
  local dungeonName = inputDungeonName ~= "" and inputDungeonName or KC.DungeonRegistry:GetName(dungeonID)
  local ownerName = CleanString(input.ownerName or input.character, "Unknown")
  local ownerRealmText = CleanString(input.ownerRealm)
  local ownerRealm = ownerRealmText ~= "" and string.gsub(ownerRealmText, "%s+", "") or nil
  local level = math.max(0, tonumber(input.level) or 0)

  local key = {
    id = input.id,
    ownerGUID = BlankToNil(input.ownerGUID),
    ownerName = ownerName ~= "" and ownerName or "Unknown",
    ownerRealm = ownerRealm,
    classFile = BlankToNil(input.classFile),
    dungeonID = dungeonID,
    dungeonName = dungeonName,
    level = level,
    score = tonumber(input.score or input.mythicScore or input.mplusScore or input.rating),
    weeklyBest = tonumber(input.weeklyBest or input.bestLevel or input.bestThisWeek),
    scoreSource = BlankToNil(input.scoreSource),
    devParty = input.devParty == true,
    source = BlankToNil(input.source) or "Unknown",
    sourceBucket = BlankToNil(input.sourceBucket),
    updatedAt = tonumber(input.updatedAt) or (time and time() or 0),
  }

  key.id = key.id or KeyID(key)
  return key
end

function KC.KeyStore:OnInitialize()
  self.keys = type(self.keys) == "table" and self.keys or {}
  self.order = type(self.order) == "table" and self.order or {}
  self:RebuildOrder()
end

function KC.KeyStore:Upsert(input)
  local key = self:Normalize(input)
  local existingForOwner

  for existingID, existing in pairs(self.keys) do
    if SameOwner(existing, key) then
      if existingID == key.id then
        existingForOwner = existing
      elseif not existingForOwner or ShouldReplaceOwnerEntry(existingForOwner, existing) then
        existingForOwner = existing
      end
    end
  end

  if existingForOwner and not ShouldReplaceOwnerEntry(existingForOwner, key) then
    if key.score and not existingForOwner.score then
      existingForOwner.score = key.score
    end
    if key.weeklyBest and not existingForOwner.weeklyBest then
      existingForOwner.weeklyBest = key.weeklyBest
    end
    if key.scoreSource and not existingForOwner.scoreSource then
      existingForOwner.scoreSource = key.scoreSource
    end
    if key.devParty then
      existingForOwner.devParty = true
    end
    return existingForOwner
  end

  if existingForOwner then
    key.score = key.score or existingForOwner.score
    key.weeklyBest = key.weeklyBest or existingForOwner.weeklyBest
    key.scoreSource = key.scoreSource or existingForOwner.scoreSource
    key.devParty = key.devParty or existingForOwner.devParty == true
  end

  for existingID, existing in pairs(self.keys) do
    if existingID ~= key.id and SameOwner(existing, key) then
      self.keys[existingID] = nil
    end
  end

  self.keys[key.id] = key

  if KC.KeyLedger then
    KC.KeyLedger:Record(key)
  end

  self:RebuildOrder()

  if not self.silent then
    KC.EventBus:Emit(KC.EVENTS.KEYS_CHANGED, self:GetAll())
  end
  return key
end

function KC.KeyStore:ReplaceSource(source, keys)
  keys = type(keys) == "table" and keys or {}
  self.silent = true

  for id, key in pairs(self.keys) do
    if key.source == source then
      self.keys[id] = nil
    end
  end

  if KC.KeyLedger then
    KC.KeyLedger:ForgetSource(source)
  end

  for _, key in ipairs(keys) do
    self:Upsert(key)
  end

  self:RebuildOrder()
  self.silent = false
  KC.EventBus:Emit(KC.EVENTS.KEYS_CHANGED, self:GetAll())
end

function KC.KeyStore:ClearSource(source)
  local changed = false

  for id, key in pairs(self.keys) do
    if key.source == source then
      self.keys[id] = nil
      changed = true
    end
  end

  if changed then
    if KC.KeyLedger then
      KC.KeyLedger:ForgetSource(source)
    end
    self:RebuildOrder()
    KC.EventBus:Emit(KC.EVENTS.KEYS_CHANGED, self:GetAll())
  end
end

function KC.KeyStore:RebuildOrder()
  self.order = {}
  for id in pairs(self.keys) do
    table.insert(self.order, id)
  end
end

function KC.KeyStore:GetAll()
  local result = {}
  local seen = {}

  for _, id in ipairs(self.order) do
    if self.keys[id] and not seen[id] then
      table.insert(result, self.keys[id])
      seen[id] = true
    end
  end

  return self:SortKeys(result)
end

function KC.KeyStore:GetByView(view)
  local options = KeystoneCouncilDB and KeystoneCouncilDB.profile and KeystoneCouncilDB.profile.options or {}
  local allKeys = self:GetAll()
  if not view or view == "all" then
    return self:DeduplicateByOwner(allKeys)
  end

  if view == "friends" and options.syncFriends == false then
    return {}
  end

  local result = {}
  for _, key in ipairs(allKeys) do
    if MatchesView(key, view) then
      if view == "guild" and key.sourceBucket ~= "guild" and not KC.Util:IsGuildRankAllowed(key.ownerName, key.ownerRealm) then
      elseif view ~= "party" and options.showOfflinePlayers == false and not KC.Util:IsOwnerOnline(key) then
      else
        result[#result + 1] = key
      end
    end
  end

  if options.displayOfflineBelowOnline then
    table.sort(result, function(a, b)
      local aOnline = KC.Util:IsOwnerOnline(a)
      local bOnline = KC.Util:IsOwnerOnline(b)
      if aOnline ~= bOnline then
        return aOnline
      end
      return CompareKeys(a, b)
    end)
  else
    self:SortKeys(result)
  end

  return self:DeduplicateByOwner(result)
end

function KC.KeyStore:Get(id)
  return self.keys[id]
end

function KC.KeyStore:Clear()
  self.keys = {}
  self.order = {}
  KC.EventBus:Emit(KC.EVENTS.KEYS_CHANGED, self:GetAll())
end

KC:RegisterModule("KeyStore", KC.KeyStore)
