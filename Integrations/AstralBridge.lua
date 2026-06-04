local KC = KeystoneCouncil

KC.AstralBridge = {
  frame = nil,
  requestedAt = 0,
  imported = 0,
  received = 0,
  rejected = 0,
  lastSource = "none",
  lastImportedPlayer = nil,
  lastRejectedReason = nil,
  sourceBuckets = {},
  messageCache = {},
  maxMessagesPerMinute = 45,
  astralSeen = false,
  astralPrefixRegistered = false,
  savedScanned = 0,
  savedImported = 0,
  savedRejected = 0,
  lastSavedImportAt = 0,
  friendRequestedAt = 0,
  friendPingsSent = 0,
}

local ASTRAL_PREFIX = "AstralKeys"
local SOURCE = "AstralBridge"
local CURRENT_SYNC = "sync6"

local function Now()
  return time and time() or 0
end

local function Clean(value)
  value = tostring(value or "")
  value = string.gsub(value, "^%s+", "")
  value = string.gsub(value, "%s+$", "")
  return value
end

local function SplitFullName(unit)
  unit = Clean(unit)
  local name, realm = string.match(unit, "^([^-]+)%-(.+)$")
  if name and realm then
    realm = string.gsub(realm, "%s+", "")
    return name, realm
  end
  return unit ~= "" and unit or nil, nil
end

local function SourceBucketFrom(sourceLabel)
  sourceLabel = string.lower(tostring(sourceLabel or ""))
  if string.find(sourceLabel, "bn", 1, true) or string.find(sourceLabel, "friend", 1, true) or string.find(sourceLabel, "whisper", 1, true) then
    return "friends"
  end
  if string.find(sourceLabel, "guild", 1, true) then
    return "guild"
  end
  if string.find(sourceLabel, "party", 1, true) or string.find(sourceLabel, "raid", 1, true) or string.find(sourceLabel, "instance", 1, true) then
    return "party"
  end
  return nil
end

local function ImportKey(entry, sourceLabel)
  if type(entry) ~= "table" then
    return false, "entry is not table"
  end

  local unit = Clean(entry.unit or entry.ownerName or entry.player or entry.name)
  local name, realm = SplitFullName(unit)
  local level = tonumber(entry.key_level or entry.keyLevel or entry.level or entry.keystoneLevel)
  local mapID = tonumber(entry.dungeon_id or entry.dungeonID or entry.mapID or entry.challengeMapID or entry.map)

  if not name or name == "" then
    return false, "missing player"
  end
  if not level or level <= 0 then
    return false, "missing key level"
  end
  if not mapID or mapID <= 0 then
    return false, "missing dungeon id"
  end

  KC.KeyStore:Upsert({
    ownerName = name,
    ownerRealm = entry.realm or entry.ownerRealm or realm,
    classFile = entry.class or entry.classFile,
    dungeonID = mapID,
    level = level,
    weeklyBest = tonumber(entry.weekly_best or entry.weeklyBest or entry.bestThisWeek),
    score = tonumber(entry.mplus_score or entry.mplusScore or entry.score or entry.rating),
    faction = entry.faction,
    -- Astral message timestamps are not guaranteed to be Unix timestamps in every version.
    -- Treat the receipt time as freshness so freshly-seen guild/friend keys do not display as stale.
    astralTimestamp = tonumber(entry.time_stamp or entry.timestamp or entry.updatedAt),
    updatedAt = Now(),
    source = SOURCE,
    sourceBucket = entry.sourceBucket or SourceBucketFrom(sourceLabel),
  })

  KC.AstralBridge.imported = (KC.AstralBridge.imported or 0) + 1
  KC.AstralBridge.lastSource = sourceLabel or "Astral message"
  KC.AstralBridge.lastImportedPlayer = unit
  return true
end

local function Reject(reason)
  KC.AstralBridge.rejected = (KC.AstralBridge.rejected or 0) + 1
  KC.AstralBridge.lastRejectedReason = KC.AstralBridge.lastRejectedReason or reason
end

local function ParseEntry(text, sourceLabel)
  text = Clean(text)
  if text == "" then
    return false
  end

  local parts = { strsplit(":", text) }
  local count = #parts
  local entry

  -- Astral guild sync6: unit:class:dungeon_id:key_level:weekly_best:week:time_stamp:mplus_score
  if count >= 8 then
    entry = {
      unit = parts[1],
      class = parts[2],
      dungeon_id = tonumber(parts[3]),
      key_level = tonumber(parts[4]),
      weekly_best = tonumber(parts[5]),
      week = tonumber(parts[6]),
      time_stamp = tonumber(parts[7]),
      mplus_score = tonumber(parts[8]),
    }
  -- Astral updateV9/updateV8: unit:class:dungeon_id:key_level:weekly_best:week:mplus_score
  elseif count >= 7 then
    entry = {
      unit = parts[1],
      class = parts[2],
      dungeon_id = tonumber(parts[3]),
      key_level = tonumber(parts[4]),
      weekly_best = tonumber(parts[5]),
      week = tonumber(parts[6]),
      mplus_score = tonumber(parts[7]),
    }
  -- Some friend sync variants: unit:class:map:key:week:timestamp:faction:weekly_best:mplus_score
  elseif count >= 6 then
    entry = {
      unit = parts[1],
      class = parts[2],
      dungeon_id = tonumber(parts[3]),
      key_level = tonumber(parts[4]),
      week = tonumber(parts[5]),
      time_stamp = tonumber(parts[6]),
      faction = parts[7],
      weekly_best = tonumber(parts[8]),
      mplus_score = tonumber(parts[9]),
    }
  else
    Reject("not enough fields")
    return false
  end

  local ok, reason = ImportKey(entry, sourceLabel)
  if not ok then
    Reject(reason)
  end
  return ok
end

local function ParseBatch(content, sourceLabel)
  local imported = 0
  content = Clean(content)
  for raw in string.gmatch(content .. "_", "(.-)_") do
    if raw and raw ~= "" and ParseEntry(raw, sourceLabel) then
      imported = imported + 1
    end
  end
  return imported
end

function KC.AstralBridge:OnInitialize()
  if self.frame or not CreateFrame then
    return
  end

  self.frame = CreateFrame("Frame")
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    local ok, result = pcall(C_ChatInfo.RegisterAddonMessagePrefix, ASTRAL_PREFIX)
    self.astralPrefixRegistered = ok and result ~= false
  end

  self.frame:RegisterEvent("CHAT_MSG_ADDON")
  if self.frame.RegisterEvent then
    pcall(function() self.frame:RegisterEvent("BN_CHAT_MSG_ADDON") end)
  end
  self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  self.frame:RegisterEvent("GUILD_ROSTER_UPDATE")
  self.frame:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" or event == "BN_CHAT_MSG_ADDON" then
      self:OnAddonMessage(event, ...)
    else
      if C_Timer and C_Timer.After then
        C_Timer.After(2, function() self:RequestAstralKeys() end)
      else
        self:RequestAstralKeys()
      end
    end
  end)
end

function KC.AstralBridge:OnEnable()
  if C_Timer and C_Timer.After then
    C_Timer.After(3, function()
      self:ImportSavedVariables()
      self:RequestAstralKeys()
    end)
  else
    self:ImportSavedVariables()
    self:RequestAstralKeys()
  end
end

function KC.AstralBridge:RequestAstralKeys()
  if not (IsInGuild and IsInGuild()) then
    return false
  end
  if Now() - (self.requestedAt or 0) < 15 then
    return false
  end
  self.requestedAt = Now()
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    pcall(C_ChatInfo.SendAddonMessage, ASTRAL_PREFIX, "request", "GUILD")
    return true
  end
  return false
end

function KC.AstralBridge:OnAddonMessage(event, prefix, msg, channel, sender)
  if prefix ~= ASTRAL_PREFIX or not msg or msg == "" then
    return
  end
  if KC.Util and KC.Util.IsSelfSender and KC.Util:IsSelfSender(sender) then
    return
  end

  self.astralSeen = true
  self.received = (self.received or 0) + 1

  -- Avoid repeatedly parsing identical Astral bursts; some versions rebroadcast aggressively.
  local now = Now()
  -- Keep only a tiny signature, never the whole Astral payload. Full sync payloads can be huge.
  local cacheKey = tostring(sender or "?") .. "|" .. tostring(channel or "?") .. "|" .. tostring(#msg) .. "|" .. string.sub(tostring(msg), 1, 80)
  if self.messageCache[cacheKey] and now - self.messageCache[cacheKey] < 60 then
    return
  end
  self.messageCache[cacheKey] = now
  for key, seenAt in pairs(self.messageCache) do
    if now - (tonumber(seenAt) or 0) > 90 then
      self.messageCache[key] = nil
    end
  end

  local command, content = string.match(msg, "^(%S+)%s*(.-)$")
  command = command or msg
  content = content or ""

  local sourceLabel = "Astral " .. tostring(command or "") .. " " .. tostring(event or "") .. " " .. tostring(channel or "")

  if command == "sync6" then
    ParseBatch(content, sourceLabel)
  elseif command == "updateV9" or command == "updateV8" or command == "update5" or command == "updateV7" then
    ParseEntry(content, sourceLabel)
  end
end

local function GuessBucketForEntry(entry, sourceLabel)
  if entry and entry.sourceBucket then
    return entry.sourceBucket
  end
  local sourceBucket = SourceBucketFrom(sourceLabel or (entry and entry.source))
  if sourceBucket then
    return sourceBucket
  end
  local unit = entry and Clean(entry.unit or entry.ownerName or entry.player or entry.name)
  local name, realm = SplitFullName(unit)
  if KC.Util then
    if KC.Util.IsFriend and KC.Util:IsFriend(name, realm) then
      return "friends"
    end
    if KC.Util.IsGuildMember and KC.Util:IsGuildMember(name, realm) then
      return "guild"
    end
    if KC.Util.IsPartyMember and KC.Util:IsPartyMember(name, realm) then
      return "party"
    end
  end
  return nil
end

function KC.AstralBridge:ImportSavedVariables(force)
  local now = Now()
  if not force and (now - (self.lastSavedImportAt or 0)) < 20 then
    return 0
  end
  self.lastSavedImportAt = now

  local astral = _G and _G.AstralKeys
  if type(astral) ~= "table" then
    return 0
  end

  self.astralSeen = true
  local imported, rejected, scanned = 0, 0, 0
  for _, entry in pairs(astral) do
    if type(entry) == "table" then
      scanned = scanned + 1
      -- AstralKeys 4.x stores every known guild/friend/player key in the
      -- global AstralKeys saved-variable table. Importing this table is cheap
      -- and avoids relying on live Astral addon-message timing.
      local copy = {}
      for key, value in pairs(entry) do
        copy[key] = value
      end
      copy.sourceBucket = copy.sourceBucket or GuessBucketForEntry(copy, "Astral saved " .. tostring(copy.source or ""))
      local ok, reason = ImportKey(copy, "Astral saved " .. tostring(copy.source or ""))
      if ok then
        imported = imported + 1
      else
        rejected = rejected + 1
        self.lastRejectedReason = self.lastRejectedReason or reason
      end
    end
  end

  self.savedScanned = scanned
  self.savedImported = imported
  self.savedRejected = rejected
  return imported
end

function KC.AstralBridge:RequestAstralFriends()
  local now = Now()
  if now - (self.friendRequestedAt or 0) < 60 then
    return false
  end
  self.friendRequestedAt = now

  local sent = 0
  local message = "BNet_query ping"

  if BNSendGameData and BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendAccountInfo then
    local total = BNGetNumFriends() or 0
    for index = 1, total do
      local ok, accountInfo = pcall(C_BattleNet.GetFriendAccountInfo, index)
      if ok and type(accountInfo) == "table" and type(accountInfo.gameAccountInfo) == "table" then
        local game = accountInfo.gameAccountInfo
        if game.clientProgram == BNET_CLIENT_WOW and game.isOnline ~= false and game.gameAccountID then
          if pcall(BNSendGameData, game.gameAccountID, ASTRAL_PREFIX, message) then
            sent = sent + 1
          end
        end
      end
    end
  end

  if C_ChatInfo and C_ChatInfo.SendAddonMessage and C_FriendList and C_FriendList.GetNumOnlineFriends and C_FriendList.GetFriendInfoByIndex then
    local total = C_FriendList.GetNumOnlineFriends() or 0
    local realm = GetRealmName and string.gsub(GetRealmName() or "", "%s+", "") or nil
    for index = 1, total do
      local info = C_FriendList.GetFriendInfoByIndex(index)
      if type(info) == "table" and info.connected ~= false and info.name then
        local target = info.name
        if realm and not string.find(target, "-", 1, true) then
          target = target .. "-" .. realm
        end
        if pcall(C_ChatInfo.SendAddonMessage, ASTRAL_PREFIX, message, "WHISPER", target) then
          sent = sent + 1
        end
      end
    end
  end

  self.friendPingsSent = (self.friendPingsSent or 0) + sent
  return sent > 0
end

function KC.AstralBridge:GetStatusLine()
  return "Astral bridge: "
    .. "seen " .. (self.astralSeen and "yes" or "no")
    .. ", messages " .. tostring(self.received or 0)
    .. ", imported " .. tostring(self.imported or 0)
    .. ", rejected " .. tostring(self.rejected or 0)
    .. ", saved scanned " .. tostring(self.savedScanned or 0)
    .. ", saved imported " .. tostring(self.savedImported or 0)
    .. ", saved rejected " .. tostring(self.savedRejected or 0)
    .. ", friend pings " .. tostring(self.friendPingsSent or 0)
    .. ", requested " .. ((self.requestedAt or 0) > 0 and "yes" or "no")
    .. ", cache " .. tostring((function(t) local n=0 for _ in pairs(t or {}) do n=n+1 end return n end)(self.messageCache))
end

function KC.AstralBridge:GetDebugLines()
  local lines = {
    self:GetStatusLine(),
    "last source: " .. tostring(self.lastSource or "none"),
    "last imported player: " .. tostring(self.lastImportedPlayer or "none"),
    "first rejected reason: " .. tostring(self.lastRejectedReason or "none"),
    "saved table present: " .. (type(_G and _G.AstralKeys) == "table" and "yes" or "no"),
    "saved scanned/imported/rejected: " .. tostring(self.savedScanned or 0) .. "/" .. tostring(self.savedImported or 0) .. "/" .. tostring(self.savedRejected or 0),
    "friend pings sent: " .. tostring(self.friendPingsSent or 0),
  }
  return lines
end

KC:RegisterModule("AstralBridge", KC.AstralBridge)
