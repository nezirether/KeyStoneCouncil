local KC = KeystoneCouncil

KC.Util = {
  guildCache = { at = 0, byFull = {} },
  friendCache = { at = 0, byFull = {} },
}

local function Now()
  return time and time() or 0
end

function KC.Util:PlayerFullName()
  local name, realm = UnitName("player")
  if not name or name == "" then
    return "Unknown"
  end

  realm = realm and realm ~= "" and realm or GetRealmName()
  if realm and realm ~= "" then
    return name .. "-" .. string.gsub(realm, "%s+", "")
  end
  return name
end

function KC.Util:NormalizePlayerName(name)
  if not name then
    return nil
  end
  return string.lower(string.gsub(name, "%s+", ""))
end

function KC.Util:BuildFullName(name, realm)
  if not name or name == "" then
    return nil
  end

  if string.find(name, "-", 1, true) then
    return string.gsub(name, "%s+", "")
  end

  realm = realm and realm ~= "" and realm or GetRealmName()
  if realm and realm ~= "" then
    return name .. "-" .. string.gsub(realm, "%s+", "")
  end

  return name
end

function KC.Util:GetUnitFullName(unit)
  if not unit then
    return nil
  end

  local name, realm = UnitName(unit)
  return self:BuildFullName(name, realm)
end

function KC.Util:IsKnownUnitToken(value)
  if type(value) ~= "string" then
    return false
  end

  if value == "player" then
    return true
  end

  if string.match(value, "^party%d+$") or string.match(value, "^raid%d+$") then
    local unitName = UnitName(value)
    return unitName ~= nil and unitName ~= ""
  end

  return false
end

function KC.Util:FindUnitTokenByName(name)
  if self:IsKnownUnitToken(name) then
    return name
  end

  local normalizedName = self:NormalizePlayerName(name)
  if not normalizedName then
    return nil
  end

  local function Matches(unit)
    local unitName, unitRealm = UnitName(unit)
    if not unitName or unitName == "" then
      return false
    end

    if normalizedName == self:NormalizePlayerName(unitName) then
      return true
    end

    if unitRealm and unitRealm ~= "" then
      return normalizedName == self:NormalizePlayerName(unitName .. "-" .. unitRealm)
    end

    return false
  end

  if Matches("player") then
    return "player"
  end

  for i = 1, 4 do
    local unit = "party" .. i
    if Matches(unit) then
      return unit
    end
  end

  for i = 1, 40 do
    local unit = "raid" .. i
    if Matches(unit) then
      return unit
    end
  end

  return nil
end

function KC.Util:GetUnitMythicPlusRatingSummary(unit)
  if not unit or not C_PlayerInfo or not C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
    return nil
  end

  local ok, summary = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, unit)
  if not ok or type(summary) ~= "table" then
    return nil
  end

  return summary
end

function KC.Util:GetUnitMythicPlusScore(unit)
  local summary = self:GetUnitMythicPlusRatingSummary(unit)
  local score = summary and tonumber(summary.currentSeasonScore)
  if score and score > 0 then
    return math.floor(score + 0.5)
  end

  return nil
end

function KC.Util:GetUnitMythicPlusWeeklyBest(unit, challengeMapID)
  local summary = self:GetUnitMythicPlusRatingSummary(unit)
  if type(summary) ~= "table" or type(summary.runs) ~= "table" then
    return nil
  end

  local best
  for _, run in ipairs(summary.runs) do
    if type(run) == "table" then
      local runMapID = tonumber(run.challengeModeID)
      local level = tonumber(run.bestRunLevel)
      if level and level > 0 and (not challengeMapID or runMapID == tonumber(challengeMapID)) then
        best = math.max(best or 0, level)
      end
    end
  end

  return best
end

function KC.Util:IsPartyMember(name, realm)
  local normalized = self:NormalizePlayerName(self:BuildFullName(name, realm) or name)
  if not normalized then
    return false
  end

  if normalized == self:NormalizePlayerName(self:GetUnitFullName("player")) then
    return true
  end

  for i = 1, 4 do
    if normalized == self:NormalizePlayerName(self:GetUnitFullName("party" .. i)) then
      return true
    end
  end

  for i = 1, 40 do
    if normalized == self:NormalizePlayerName(self:GetUnitFullName("raid" .. i)) then
      return true
    end
  end

  return false
end

function KC.Util:IsGuildMember(name, realm)
  return self:GetGuildMemberInfo(name, realm) ~= nil
end

function KC.Util:IsFriend(name, realm)
  return self:GetFriendInfo(name, realm) ~= nil
end

function KC.Util:GetSocialBucket(name, realm)
  if self:IsPartyMember(name, realm) then
    return "party"
  end

  if self:IsFriend(name, realm) then
    return "friends"
  end

  if self:IsGuildMember(name, realm) then
    return "guild"
  end

  return "other"
end

function KC.Util:EnrichKeyData(input)
  if type(input) ~= "table" then
    return input
  end

  local unit = self:FindUnitTokenByName(input.ownerName or input.unitID or input.unit)
  if not unit then
    return input
  end

  local name, realm = UnitName(unit)
  if not input.ownerName or input.ownerName == "" or self:IsKnownUnitToken(input.ownerName) then
    input.ownerName = name
  end
  if not input.ownerRealm or input.ownerRealm == "" then
    input.ownerRealm = realm
  end
  if not input.ownerGUID or input.ownerGUID == "" then
    input.ownerGUID = UnitGUID(unit)
  end
  if not input.classFile or input.classFile == "" then
    input.classFile = select(2, UnitClass(unit))
  end
  if not input.score then
    input.score = self:GetUnitMythicPlusScore(unit)
  end
  if not input.weeklyBest then
    input.weeklyBest = self:GetUnitMythicPlusWeeklyBest(unit, input.dungeonID)
  end

  return input
end

function KC.Util:IsSelfSender(sender)
  if not sender or sender == "" then
    return false
  end

  local selfShort = UnitName("player")
  local selfFull = self:PlayerFullName()
  local normalized = self:NormalizePlayerName(sender)
  return normalized == self:NormalizePlayerName(selfShort) or normalized == self:NormalizePlayerName(selfFull)
end

function KC.Util:SafeCall(label, callback, ...)
  local ok, result = pcall(callback, ...)
  if not ok then
    KC.Logger:Debug(label .. " failed: " .. tostring(result))
    return nil
  end
  return result
end

function KC.Util:NormalizeChatCommand(text)
  if not text then
    return ""
  end

  text = tostring(text)
  text = string.gsub(text, "^%[[^%]]+%]%s*", "")
  text = string.lower(text)
  text = string.gsub(text, "^%s+", "")
  text = string.gsub(text, "%s+$", "")
  return text
end

function KC.Util:KeySignature(key)
  if not key then
    return "none"
  end

  return table.concat({
    tostring(key.ownerGUID or key.ownerName or "unknown"),
    tostring(key.dungeonID or key.dungeonName or "dungeon"),
    tostring(key.level or 0),
  }, ":")
end

function KC.Util:FormatKeystoneLink(key)
  if not key then
    return "no key"
  end

  local dungeonName = tostring(key.dungeonName or KC.DungeonRegistry:GetName(key.dungeonID) or "Unknown")
  local level = tonumber(key.level) or 0
  local mapID = tonumber(key.dungeonID) or 0

  if level > 0 and mapID > 0 then
    return string.format("|cffa335ee|Hkeystone:180653:%d:%d:0:0:0:0:0|h[Keystone: %s (%d)]|h|r", mapID, level, dungeonName, level)
  end

  return string.format("+%s %s", tostring(key.level or "?"), dungeonName)
end

function KC.Util:GetOwnedKey()
  if KC.BlizzardKeys and KC.BlizzardKeys.ReadLocalKey then
    return KC.BlizzardKeys:ReadLocalKey()
  end

  return nil
end

function KC.Util:RebuildGuildCache(force)
  if not force and self.guildCache and Now() - (self.guildCache.at or 0) < 10 then
    return
  end

  local cache = { at = Now(), byFull = {} }
  local total = 0
  if GetNumGuildMembers then
    local ok, count = pcall(GetNumGuildMembers)
    if ok and count then
      total = count
    end
  end

  for index = 1, total do
    if GetGuildRosterInfo then
      local ok, fullName, rank, rankIndex, _, _, _, _, _, online = pcall(GetGuildRosterInfo, index)
      if ok and fullName and fullName ~= "" then
        local normalizedFull = self:NormalizePlayerName(self:BuildFullName(fullName, nil) or fullName)
        if normalizedFull then
          cache.byFull[normalizedFull] = {
            fullName = fullName,
            rank = rank,
            rankIndex = rankIndex,
            online = online ~= false,
          }
          local shortName = string.match(fullName, "^([^-]+)")
          if shortName then
            cache.byFull[self:NormalizePlayerName(shortName)] = cache.byFull[normalizedFull]
          end
        end
      end
    end
  end

  self.guildCache = cache
end

function KC.Util:GetGuildMemberInfo(name, realm)
  local target = self:NormalizePlayerName(self:BuildFullName(name, realm) or name)
  if not target then
    return nil
  end

  self:RebuildGuildCache(false)
  return self.guildCache and self.guildCache.byFull and self.guildCache.byFull[target] or nil
end

function KC.Util:RebuildFriendCache(force)
  if not force and self.friendCache and Now() - (self.friendCache.at or 0) < 10 then
    return
  end

  local cache = { at = Now(), byFull = {} }
  local function Add(nameOnly, friendRealm, online)
    if not nameOnly or nameOnly == "" then return end
    local normalizedFull = self:NormalizePlayerName(self:BuildFullName(nameOnly, friendRealm) or nameOnly)
    if normalizedFull then
      local row = { name = nameOnly, realmName = friendRealm, online = online ~= false }
      cache.byFull[normalizedFull] = row
      cache.byFull[self:NormalizePlayerName(nameOnly)] = row
    end
  end

  local wowFriends = C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetNumFriends() or (GetNumFriends and GetNumFriends() or 0)
  for index = 1, wowFriends do
    local info = C_FriendList and C_FriendList.GetFriendInfoByIndex and C_FriendList.GetFriendInfoByIndex(index)
    if type(info) == "table" then
      Add(info.name, rawget(info, "realmName"), info.connected ~= false and rawget(info, "isOnline") ~= false)
    elseif GetFriendInfo then
      Add(GetFriendInfo(index), nil, true)
    end
  end

  if C_BattleNet and C_BattleNet.GetFriendAccountInfo and BNGetNumFriends then
    for index = 1, BNGetNumFriends() do
      local accountInfo = C_BattleNet.GetFriendAccountInfo(index)
      if type(accountInfo) == "table" and type(accountInfo.gameAccountInfo) == "table" then
        local gameInfo = accountInfo.gameAccountInfo
        if gameInfo.characterName and gameInfo.clientProgram == BNET_CLIENT_WOW then
          Add(gameInfo.characterName, gameInfo.realmName, gameInfo.isOnline ~= false)
        end
      end
    end
  end

  self.friendCache = cache
end

function KC.Util:GetFriendInfo(name, realm)
  local target = self:NormalizePlayerName(self:BuildFullName(name, realm) or name)
  if not target then
    return nil
  end

  self:RebuildFriendCache(false)
  return self.friendCache and self.friendCache.byFull and self.friendCache.byFull[target] or nil
end

function KC.Util:GetAvailableGuildRanks()
  local ranks = {}
  local seen = {}
  local filters = KeystoneCouncilDB and KeystoneCouncilDB.profile and KeystoneCouncilDB.profile.options and KeystoneCouncilDB.profile.options.guildRankFilter or {}
  local total = 0
  if GetNumGuildMembers then
    local ok, count = pcall(GetNumGuildMembers)
    if ok and count then
      total = count
    end
  end
  for index = 1, total do
    if GetGuildRosterInfo then
      local ok, _, rank = pcall(GetGuildRosterInfo, index)
      if ok and rank and rank ~= "" and not seen[rank] then
        seen[rank] = true
        ranks[#ranks + 1] = rank
      end
    end
  end

  for rank in pairs(filters) do
    if rank and rank ~= "" and not seen[rank] then
      seen[rank] = true
      ranks[#ranks + 1] = rank
    end
  end

  table.sort(ranks)
  return ranks
end

function KC.Util:IsGuildRankAllowed(name, realm)
  local filters = KeystoneCouncilDB and KeystoneCouncilDB.profile and KeystoneCouncilDB.profile.options and KeystoneCouncilDB.profile.options.guildRankFilter or {}
  local memberInfo = self:GetGuildMemberInfo(name, realm)
  if not memberInfo or not memberInfo.rank then
    return true
  end

  if filters[memberInfo.rank] == nil then
    return true
  end

  return filters[memberInfo.rank] == true
end

function KC.Util:IsOwnerOnline(key)
  if not key then
    return true
  end

  if self:IsPartyMember(key.ownerName, key.ownerRealm) then
    return true
  end

  local friendInfo = self:GetFriendInfo(key.ownerName, key.ownerRealm)
  if friendInfo then
    return friendInfo.online ~= false
  end

  local guildInfo = self:GetGuildMemberInfo(key.ownerName, key.ownerRealm)
  if guildInfo then
    return guildInfo.online ~= false
  end

  return true
end

function KC.Util:IsCurrentPlayerLeader()
  if not IsInGroup or not IsInGroup() then
    return true
  end

  if UnitIsGroupLeader then
    local ok, isLeader = pcall(UnitIsGroupLeader, "player")
    if ok then
      return isLeader == true
    end
  end

  return false
end
