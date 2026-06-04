local KC = KeystoneCouncil

KC.KeyLedger = {
  staleAfter = 8 * 24 * 60 * 60,
  maxRows = 500,
}

local function DateTable(timestamp)
  if date then
    return date("*t", timestamp)
  end
  if os and os.date then
    return os.date("*t", timestamp)
  end
  return nil
end

local function WeekID(timestamp)
  timestamp = tonumber(timestamp) or time()
  local info = DateTable(timestamp)
  if not info then
    return "unknown"
  end

  local yday = tonumber(info.yday) or 1
  local wday = tonumber(info.wday) or 3
  local daysSinceReset = wday - 3
  if daysSinceReset < 0 then
    daysSinceReset = daysSinceReset + 7
  end

  local resetInfo = DateTable(timestamp - (daysSinceReset * 24 * 60 * 60)) or info
  local week = math.floor(((tonumber(resetInfo.yday) or yday) + 6) / 7)
  return tostring(resetInfo.year or info.year or "0000") .. "-RW" .. tostring(week)
end

local function LedgerTable()
  KeystoneCouncilDB.global.keyLedger = KeystoneCouncilDB.global.keyLedger or {}
  return KeystoneCouncilDB.global.keyLedger
end

local function OwnerKey(key)
  local fullName = KC.Util:BuildFullName(key.ownerName, key.ownerRealm) or key.ownerName or key.ownerGUID or "unknown"
  return KC.Util:NormalizePlayerName(fullName) or "unknown"
end

local function DisplayOwnerKey(key)
  if key and key.ownerGUID and key.ownerGUID ~= "" then
    return key.ownerGUID
  end

  local fullName = KC.Util:BuildFullName(key and key.ownerName, key and key.ownerRealm) or (key and key.ownerName)
  return KC.Util:NormalizePlayerName(fullName) or "unknown"
end

local function ShortOwnerKey(key)
  local name = tostring(key and key.ownerName or "unknown")
  name = string.gsub(name, "%s+", "")
  name = string.match(name, "^([^-]+)") or name
  return KC.Util:NormalizePlayerName(name) or "unknown"
end

local function EntryID(key)
  return tostring(key.ownerGUID or OwnerKey(key)) .. ":" .. tostring(key.dungeonID or key.dungeonName or 0)
end

function KC.KeyLedger:Record(input)
  if type(input) ~= "table" or not input.ownerName or (not input.dungeonID and not input.dungeonName) then
    return nil
  end

  local key = KC.KeyStore and KC.KeyStore:Normalize(input) or input
  local ledger = LedgerTable()
  local id = EntryID(key)
  local now = time()
  local existing = ledger[id] or {}

  ledger[id] = {
    id = id,
    ownerGUID = key.ownerGUID or existing.ownerGUID,
    ownerName = key.ownerName or existing.ownerName,
    ownerRealm = key.ownerRealm or existing.ownerRealm,
    classFile = key.classFile or existing.classFile,
    dungeonID = key.dungeonID or existing.dungeonID,
    dungeonName = key.dungeonName or existing.dungeonName,
    level = tonumber(key.level) or tonumber(existing.level) or 0,
    score = tonumber(key.score) or tonumber(existing.score),
    weeklyBest = tonumber(key.weeklyBest) or tonumber(existing.weeklyBest),
    source = key.source or existing.source or "Unknown",
    sourceBucket = key.sourceBucket or existing.sourceBucket,
    originalSource = key.originalSource or existing.originalSource,
    firstSeenAt = tonumber(existing.firstSeenAt) or now,
    lastSeenAt = tonumber(key.updatedAt) or now,
    updatedAt = tonumber(key.updatedAt) or now,
    resetWeek = key.resetWeek or WeekID(tonumber(key.updatedAt) or now),
    bucket = key.sourceBucket or (KC.Util and KC.Util:GetSocialBucket(key.ownerName, key.ownerRealm)) or "other",
  }

  self:PruneOverflow()
  return ledger[id]
end

function KC.KeyLedger:PruneOverflow(maxRows)
  maxRows = tonumber(maxRows) or self.maxRows or 500
  local ledger = LedgerTable()
  local ids = {}
  for id, entry in pairs(ledger) do
    ids[#ids + 1] = {
      id = id,
      stale = self:IsEntryStale(entry),
      seen = tonumber(entry.lastSeenAt or entry.updatedAt) or 0,
    }
  end

  if #ids <= maxRows then
    return 0
  end

  table.sort(ids, function(a, b)
    if a.stale ~= b.stale then
      return a.stale
    end
    return a.seen < b.seen
  end)

  local removed = 0
  for index = 1, #ids - maxRows do
    ledger[ids[index].id] = nil
    removed = removed + 1
  end
  return removed
end

function KC.KeyLedger:GetCurrentWeek()
  return WeekID(time())
end

function KC.KeyLedger:IsEntryStale(entry)
  if not entry then
    return true
  end

  local now = time()
  local age = now - (tonumber(entry.lastSeenAt) or tonumber(entry.updatedAt) or now)
  if age > self.staleAfter then
    return true
  end

  local resetWeek = entry.resetWeek or WeekID(tonumber(entry.updatedAt) or tonumber(entry.lastSeenAt) or now)
  return resetWeek ~= "unknown" and resetWeek ~= self:GetCurrentWeek()
end

function KC.KeyLedger:ForgetSource(source)
  local ledger = LedgerTable()
  local changed = false
  for id, entry in pairs(ledger) do
    if entry.source == source then
      ledger[id] = nil
      changed = true
    end
  end
  return changed
end

function KC.KeyLedger:ResolveBucket(entry)
  -- sourceBucket is what the import explicitly told us (e.g. AstralBridge sets
  -- "guild" or "friends" based on the Astral channel). Trust it when present.
  if entry.sourceBucket and entry.sourceBucket ~= "" and entry.sourceBucket ~= "other" then
    return entry.sourceBucket
  end
  -- Fall back to a live roster check. This corrects entries that were imported
  -- before GUILD_ROSTER_UPDATE or the friend cache was populated, which caused
  -- GetSocialBucket to return "other" and lock the entry out of Guild/Friends tabs.
  if KC.Util then
    local live = KC.Util:GetSocialBucket(entry.ownerName, entry.ownerRealm)
    if live and live ~= "other" then
      return live
    end
  end
  -- Last resort: use whatever was stored, even if it is "other".
  return entry.sourceBucket or entry.bucket or "other"
end

function KC.KeyLedger:GetAll()
  local ledger = LedgerTable()
  local result = {}
  local now = time()

  for _, entry in pairs(ledger) do
    local copy = {}
    for key, value in pairs(entry) do
      copy[key] = value
    end
    copy.age = now - (tonumber(copy.lastSeenAt) or tonumber(copy.updatedAt) or now)
    copy.resetWeek = copy.resetWeek or WeekID(tonumber(copy.updatedAt) or tonumber(copy.lastSeenAt) or now)
    copy.isStale = self:IsEntryStale(copy)
    -- Recompute bucket on every read so entries imported before roster caches
    -- were populated are assigned the correct guild/friends/party bucket.
    copy.bucket = self:ResolveBucket(copy)
    result[#result + 1] = copy
  end

  if KC.KeyStore and KC.KeyStore.SortKeys then
    KC.KeyStore:SortKeys(result)
  else
    table.sort(result, function(a, b)
      if a.isStale ~= b.isStale then
        return not a.isStale
      end
      if (tonumber(a.level) or 0) == (tonumber(b.level) or 0) then
        return tostring(a.ownerName) < tostring(b.ownerName)
      end
      return (tonumber(a.level) or 0) > (tonumber(b.level) or 0)
    end)
  end

  return result
end

function KC.KeyLedger:GetAuditSummary()
  local all = self:GetAll()
  local summary = {
    total = #all,
    stale = 0,
    currentWeek = self:GetCurrentWeek(),
    guild = 0,
    party = 0,
    friends = 0,
    other = 0,
    duplicateDisplayOwners = 0,
    realmVariants = 0,
    sources = {},
  }
  local displayOwners = {}
  local ownerRealms = {}

  for _, entry in ipairs(all) do
    if entry.isStale then
      summary.stale = summary.stale + 1
    end

    local bucket = entry.bucket or "other"
    if summary[bucket] ~= nil then
      summary[bucket] = summary[bucket] + 1
    else
      summary.other = summary.other + 1
    end

    local source = tostring(entry.source or "Unknown")
    summary.sources[source] = (summary.sources[source] or 0) + 1

    local displayOwner = ShortOwnerKey(entry)
    displayOwners[displayOwner] = (displayOwners[displayOwner] or 0) + 1

    local realm = tostring(entry.ownerRealm or "")
    if realm ~= "" then
      ownerRealms[displayOwner] = ownerRealms[displayOwner] or {}
      ownerRealms[displayOwner][realm] = true
    end
  end

  for owner, count in pairs(displayOwners) do
    if count > 1 then
      summary.duplicateDisplayOwners = summary.duplicateDisplayOwners + 1
    end
    local realmCount = 0
    for _ in pairs(ownerRealms[owner] or {}) do
      realmCount = realmCount + 1
    end
    if realmCount > 1 then
      summary.realmVariants = summary.realmVariants + 1
    end
  end

  return summary
end

function KC.KeyLedger:EntryMatchesView(entry, view)
  if not view or view == "all" then
    return true
  end
  -- Check the dynamically-resolved bucket first (handles entries imported before rosters loaded).
  local bucket = entry.bucket or self:ResolveBucket(entry)
  if bucket == view then
    return true
  end
  -- Also do a live social check for guild/friends/party so stale cached buckets
  -- don't silently exclude valid entries.
  if KC.Util then
    if view == "guild" and KC.Util:IsGuildMember(entry.ownerName, entry.ownerRealm) then
      return true
    end
    if view == "friends" and KC.Util:IsFriend(entry.ownerName, entry.ownerRealm) then
      return true
    end
    if view == "party" and KC.Util:IsPartyMember(entry.ownerName, entry.ownerRealm) then
      return true
    end
  end
  return false
end

function KC.KeyLedger:GetByView(view)
  local all = self:GetAll()
  if not view or view == "all" then
    if KC.KeyStore and KC.KeyStore.DeduplicateByOwner then
      return KC.KeyStore:DeduplicateByOwner(all)
    end
    return all
  end

  local result = {}
  for _, entry in ipairs(all) do
    if self:EntryMatchesView(entry, view) then
      result[#result + 1] = entry
    end
  end
  if KC.KeyStore and KC.KeyStore.DeduplicateByOwner then
    return KC.KeyStore:DeduplicateByOwner(result)
  end
  return result
end

function KC.KeyLedger:GetStatusLine()
  local all = self:GetAll()
  local visible = all
  if KC.KeyStore and KC.KeyStore.DeduplicateByOwner then
    visible = KC.KeyStore:DeduplicateByOwner(all)
  end
  local stale = 0
  for _, entry in ipairs(all) do
    if entry.isStale then
      stale = stale + 1
    end
  end

  return "Key ledger: " .. tostring(#visible) .. " players, " .. tostring(#all) .. " keys, " .. tostring(stale) .. " stale"
end

function KC.KeyLedger:Cleanup(silent)
  local ledger = LedgerTable()
  local all = self:GetAll()
  local keep = {}
  local removed = 0

  if KC.KeyStore and KC.KeyStore.DeduplicateByOwner then
    for _, entry in ipairs(KC.KeyStore:DeduplicateByOwner(all)) do
      keep[DisplayOwnerKey(entry)] = entry.id
    end
  end

  for id, entry in pairs(ledger) do
    local displayOwner = DisplayOwnerKey(entry)
    -- Do not purge stale social/provider keys automatically. Stale rows are useful
    -- when Show Offline is enabled and match AstralKeys behavior. Only remove
    -- duplicate owner rows during cleanup.
    if keep[displayOwner] and keep[displayOwner] ~= id then
      ledger[id] = nil
      removed = removed + 1
    end
  end

  if KC.KeyStore then
    KC.KeyStore:Clear()
    self:HydrateStore()
  end

  removed = removed + self:PruneOverflow()

  if collectgarbage then
    pcall(collectgarbage, "collect")
  end

  if not silent then
    KC.Logger:Print("Cleaned " .. tostring(removed) .. " old or duplicate key entr" .. (removed == 1 and "y." or "ies."))
  end
  return removed
end

function KC.KeyLedger:HydrateStore()
  if not KC.KeyStore then
    return
  end

  local all = self:GetAll()
  KC.KeyStore.silent = true
  local options = KeystoneCouncilDB and KeystoneCouncilDB.profile and KeystoneCouncilDB.profile.options or {}
  for _, entry in ipairs(all) do
    if not entry.isStale or options.showOfflinePlayers ~= false then
      KC.KeyStore:Upsert(entry)
    end
  end
  KC.KeyStore.silent = false
  KC.EventBus:Emit(KC.EVENTS.KEYS_CHANGED, KC.KeyStore:GetAll())
end

function KC.KeyLedger:OnEnable()
  -- Hydrate instead of cleanup. Cleanup used to remove stale Astral/social rows on
  -- login, which made Guild/Friends/All look empty even with Show Offline enabled.
  self:HydrateStore()
end

KC:RegisterModule("KeyLedger", KC.KeyLedger)
