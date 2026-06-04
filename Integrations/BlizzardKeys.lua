local KC = KeystoneCouncil

KC.BlizzardKeys = {}

function KC.BlizzardKeys:GetOverallScore()
  if C_ChallengeMode and C_ChallengeMode.GetOverallDungeonScore then
    local ok, score = pcall(C_ChallengeMode.GetOverallDungeonScore)
    if ok and tonumber(score) and tonumber(score) > 0 then
      return tonumber(score)
    end
  end

  return nil
end

function KC.BlizzardKeys:GetCurrentWeekBestLevel()
  if not C_MythicPlus then
    return nil
  end

  if C_MythicPlus.GetWeeklyChestRewardLevel then
    local ok, currentWeekBestLevel = pcall(C_MythicPlus.GetWeeklyChestRewardLevel)
    if ok and tonumber(currentWeekBestLevel) and tonumber(currentWeekBestLevel) > 0 then
      return tonumber(currentWeekBestLevel)
    end
  end

  if C_MythicPlus.GetLastWeeklyBestInformation then
    local ok, _, level = pcall(C_MythicPlus.GetLastWeeklyBestInformation)
    if ok and tonumber(level) and tonumber(level) > 0 then
      return tonumber(level)
    end
  end

  return nil
end

function KC.BlizzardKeys:GetRunHistoryWeeklyBestLevel(challengeMapID)
  if not C_MythicPlus or not C_MythicPlus.GetRunHistory then
    return nil
  end

  local ok, runs = pcall(C_MythicPlus.GetRunHistory, false, true, true)
  if not ok or type(runs) ~= "table" then
    return nil
  end

  local best
  for _, run in ipairs(runs) do
    if type(run) == "table" then
      local mapID = tonumber(rawget(run, "mapChallengeModeID") or rawget(run, "challengeMapID") or rawget(run, "mapID"))
      local level = tonumber(rawget(run, "level") or rawget(run, "keystoneLevel"))
      if level and level > 0 and (not challengeMapID or mapID == tonumber(challengeMapID)) then
        best = math.max(best or 0, level)
      end
    end
  end

  return best
end

function KC.BlizzardKeys:GetMapWeeklyBestLevel(challengeMapID)
  if not challengeMapID or not C_MythicPlus or not C_MythicPlus.GetWeeklyBestForMap then
    return nil
  end

  local ok, _, level = pcall(C_MythicPlus.GetWeeklyBestForMap, challengeMapID)
  if ok and tonumber(level) and tonumber(level) > 0 then
    return tonumber(level)
  end

  return nil
end

function KC.BlizzardKeys:ReadLocalKey()
  if not C_MythicPlus or not C_MythicPlus.GetOwnedKeystoneLevel then
    return nil
  end

  local level = C_MythicPlus.GetOwnedKeystoneLevel()
  if not level or level <= 0 then
    return nil
  end

  local dungeonID
  if C_MythicPlus.GetOwnedKeystoneChallengeMapID then
    dungeonID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
  end

  local dungeonName
  if dungeonID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
    dungeonName = KC.Util:SafeCall("C_ChallengeMode.GetMapUIInfo", C_ChallengeMode.GetMapUIInfo, dungeonID)
  end

  local weeklyBest = self:GetMapWeeklyBestLevel(dungeonID) or self:GetRunHistoryWeeklyBestLevel(dungeonID) or self:GetCurrentWeekBestLevel()
  local score = self:GetOverallScore()

  local name, realm = UnitName("player")
  return KC.KeyStore:Normalize({
    ownerGUID = UnitGUID("player"),
    ownerName = name,
    ownerRealm = realm,
    classFile = select(2, UnitClass("player")),
    dungeonID = dungeonID,
    dungeonName = dungeonName,
    level = level,
    score = score,
    weeklyBest = weeklyBest,
    source = "Blizzard",
  })
end

function KC.BlizzardKeys:Refresh()
  if KC.ExternalKeyProvider and KC.ExternalKeyProvider.available then
    KC.ExternalKeyProvider:Import()
  end

  local key = self:ReadLocalKey()
  if key then
    KC.KeyStore:Upsert(key)
    if KC.PartySync then
      KC.PartySync:BroadcastLocalKey()
    end
    return true
  end

  return false
end

function KC.BlizzardKeys:OnEnable()
  local function RefreshLater()
    if C_MythicPlus and C_MythicPlus.RequestMapInfo then
      pcall(C_MythicPlus.RequestMapInfo)
    end
    if C_MythicPlus and C_MythicPlus.RequestRewards then
      pcall(C_MythicPlus.RequestRewards)
    end
    self:Refresh()
  end

  if C_Timer and C_Timer.After then
    C_Timer.After(1, RefreshLater)
  else
    RefreshLater()
  end
end

KC:RegisterModule("BlizzardKeys", KC.BlizzardKeys)
