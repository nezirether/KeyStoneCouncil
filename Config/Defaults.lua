local KC = KeystoneCouncil

KC.Defaults = {
  profileVersion = 3,
  profile = {
    debug = false,
    mode = "spin",
    announce = true,
    announceChannel = "PARTY",
    announceSelf = true,
    announceWinnerToParty = true,
    scale = 1,
    streamerMode = false,
    countdownPrimaryAudio = true,
    countdownSecondaryAudio = true,
    options = {
      showMinimapButton = true,
      syncFriends = true,
      showOfflinePlayers = true,
      displayOfflineBelowOnline = true,
      showCurrentKeyTooltip = true,
      showOtherFaction = true,
      shareLedger = true,
      useExternalScores = false,
      includeGuildMemeQuotes = false,
      includeRareQuotes = false,
      keySortMode = "level",
      guildRankFilter = {},
    },
    keyReporting = {
      chatCommand = "!keys",
      announceNewKeyGuild = true,
      announceNewKeyParty = true,
      respondGuild = true,
      respondParty = true,
      respondRaid = true,
      respondInstance = true,
      respondSay = true,
      includeNoKey = true,
      respondAllVisibleKeys = false,
    },
    smart = {
      preferUntimed = true,
      preferLowestScore = true,
      preferVaultNeeds = true,
      recentPenalty = 0.65,
      scoreGapBonus = 4,
      vaultNeedBonus = 6,
      seasonBestBonus = 3,
      duplicateDungeonPenalty = 0.75,
      intent = "balanced",
    }
  },
  global = {
    history = {},
    stats = {},
    keyLedger = {},
    seasonBest = {},
    migrations = {},
  },
  session = {
    startedAt = 0,
    voteOpen = false,
    voteMode = "",
    voteToken = "",
    closedVoteTokens = {},
    closedVoteOrder = {},
    votes = {},
    selections = {},
  }
}

local function CopyDefaults(target, defaults)
  for key, value in pairs(defaults) do
    if type(value) == "table" then
      if type(target[key]) ~= "table" then
        target[key] = {}
      end
      CopyDefaults(target[key], value)
    elseif target[key] == nil then
      target[key] = value
    end
  end
end

local function FromBytes(...)
  local chars = {}
  for index = 1, select("#", ...) do
    chars[index] = string.char(select(index, ...))
  end
  return table.concat(chars)
end

local function MigrateStoredSourceNames(db)
  local sourceMap = {
    [FromBytes(65, 115, 116, 114, 97, 108, 75, 101, 121, 115)] = "ExternalKeyProvider",
    [FromBytes(76, 105, 98, 75, 101, 121, 115, 116, 111, 110, 101)] = "SharedKeyProvider",
    [FromBytes(79, 112, 101, 110, 82, 97, 105, 100)] = "GroupKeyProvider",
  }
  local scoreSourceMap = {
    [FromBytes(82, 97, 105, 100, 101, 114, 46, 73, 79)] = "ExternalScore",
  }

  local function MigrateRows(rows)
    if type(rows) ~= "table" then
      return
    end
    for _, row in pairs(rows) do
      if type(row) == "table" then
        if sourceMap[row.source] then
          row.source = sourceMap[row.source]
        end
        if scoreSourceMap[row.scoreSource] then
          row.scoreSource = scoreSourceMap[row.scoreSource]
        end
      end
    end
  end

  if db and db.global then
    MigrateRows(db.global.keyLedger)
    MigrateRows(db.global.history)
    MigrateRows(db.global.seasonBest)
  end
end

local migrations = {
  [2] = function(db)
    db.global = type(db.global) == "table" and db.global or {}
    if type(db.global.seasonBest) ~= "table" then
      db.global.seasonBest = {}
    end
    if type(db.global.seasonBests) == "table" then
      for id, row in pairs(db.global.seasonBests) do
        if db.global.seasonBest[id] == nil then
          db.global.seasonBest[id] = row
        end
      end
    end
    if db.profile and db.profile.mode == "chaos" then
      db.profile.mode = "spin"
    end
  end,
  [3] = function(db)
    db.profile = type(db.profile) == "table" and db.profile or {}
    db.profile.options = type(db.profile.options) == "table" and db.profile.options or {}

    local legacyPrimary = FromBytes(98, 105, 103, 87, 105, 103, 115, 65, 117, 100, 105, 111)
    local legacySecondary = FromBytes(100, 98, 109, 65, 117, 100, 105, 111)
    local legacyScore = FromBytes(117, 115, 101, 82, 97, 105, 100, 101, 114, 73, 79, 83, 99, 111, 114, 101, 115)

    if db.profile[legacyPrimary] ~= nil then
      db.profile.countdownPrimaryAudio = db.profile[legacyPrimary] ~= false
      db.profile[legacyPrimary] = nil
    end
    if db.profile[legacySecondary] ~= nil then
      db.profile.countdownSecondaryAudio = db.profile[legacySecondary] ~= false
      db.profile[legacySecondary] = nil
    end
    if db.profile.options[legacyScore] ~= nil then
      db.profile.options.useExternalScores = db.profile.options[legacyScore] == true
      db.profile.options[legacyScore] = nil
    end

    MigrateStoredSourceNames(db)
  end,
}

function KC:RunDatabaseMigrations(fromVersion)
  KeystoneCouncilDB.global = type(KeystoneCouncilDB.global) == "table" and KeystoneCouncilDB.global or {}
  KeystoneCouncilDB.global.migrations = type(KeystoneCouncilDB.global.migrations) == "table" and KeystoneCouncilDB.global.migrations or {}

  fromVersion = tonumber(fromVersion) or 0
  for version = fromVersion + 1, KC.Defaults.profileVersion do
    local migration = migrations[version]
    if migration then
      local ok, err = pcall(migration, KeystoneCouncilDB)
      if ok then
        KeystoneCouncilDB.global.migrations[tostring(version)] = time and time() or 0
      elseif KC.Logger then
        KC.Logger:Error("Saved data migration " .. tostring(version) .. " failed: " .. tostring(err))
      end
    end
  end
end

function KC:InitializeDatabase()
  KeystoneCouncilDB = KeystoneCouncilDB or {}
  local previousProfileVersion = tonumber(KeystoneCouncilDB.profileVersion) or 0
  CopyDefaults(KeystoneCouncilDB, KC.Defaults)
  self:RunDatabaseMigrations(previousProfileVersion)
  CopyDefaults(KeystoneCouncilDB, KC.Defaults)

  if type(KeystoneCouncilDB.global.history) ~= "table" then
    KeystoneCouncilDB.global.history = {}
  end

  if type(KeystoneCouncilDB.global.stats) ~= "table" then
    KeystoneCouncilDB.global.stats = {}
  end

  if type(KeystoneCouncilDB.global.keyLedger) ~= "table" then
    KeystoneCouncilDB.global.keyLedger = {}
  end

  if type(KeystoneCouncilDB.global.seasonBest) ~= "table" then
    KeystoneCouncilDB.global.seasonBest = {}
  end

  if type(KeystoneCouncilDB.global.migrations) ~= "table" then
    KeystoneCouncilDB.global.migrations = {}
  end

  if type(KeystoneCouncilDB.session.votes) ~= "table" then
    KeystoneCouncilDB.session.votes = {}
  end

  if type(KeystoneCouncilDB.session.selections) ~= "table" then
    KeystoneCouncilDB.session.selections = {}
  end

  if KeystoneCouncilDB.session.voteOpen == nil then
    KeystoneCouncilDB.session.voteOpen = false
  end
  KeystoneCouncilDB.session.voteMode = type(KeystoneCouncilDB.session.voteMode) == "string" and KeystoneCouncilDB.session.voteMode or ""
  KeystoneCouncilDB.session.voteToken = type(KeystoneCouncilDB.session.voteToken) == "string" and KeystoneCouncilDB.session.voteToken or ""
  KeystoneCouncilDB.session.closedVoteTokens = type(KeystoneCouncilDB.session.closedVoteTokens) == "table" and KeystoneCouncilDB.session.closedVoteTokens or {}
  KeystoneCouncilDB.session.closedVoteOrder = type(KeystoneCouncilDB.session.closedVoteOrder) == "table" and KeystoneCouncilDB.session.closedVoteOrder or {}

  if type(KeystoneCouncilDB.profile.options) ~= "table" then
    KeystoneCouncilDB.profile.options = {}
  end
  CopyDefaults(KeystoneCouncilDB.profile.options, KC.Defaults.profile.options)

  if type(KeystoneCouncilDB.profile.options.guildRankFilter) ~= "table" then
    KeystoneCouncilDB.profile.options.guildRankFilter = {}
  end

  local validSortModes = {
    level = true,
    dungeon = true,
    owner = true,
    score = true,
    weekly = true,
    seen = true,
  }
  if not validSortModes[KeystoneCouncilDB.profile.options.keySortMode] then
    KeystoneCouncilDB.profile.options.keySortMode = KC.Defaults.profile.options.keySortMode
  end

  if type(KeystoneCouncilDB.profile.keyReporting) ~= "table" then
    KeystoneCouncilDB.profile.keyReporting = {}
  end
  CopyDefaults(KeystoneCouncilDB.profile.keyReporting, KC.Defaults.profile.keyReporting)

  if type(KeystoneCouncilDB.profile.smart) ~= "table" then
    KeystoneCouncilDB.profile.smart = {}
  end
  CopyDefaults(KeystoneCouncilDB.profile.smart, KC.Defaults.profile.smart)

  local validModes = {
    spin = true,
    raffle = true,
    majority = true,
    smart = true,
  }
  local modeAliases = {
    voting = "raffle",
    vote = "raffle",
    democracy = "majority",
    democratic = "majority",
    chaos = "spin",
  }
  if modeAliases[KeystoneCouncilDB.profile.mode] then
    KeystoneCouncilDB.profile.mode = modeAliases[KeystoneCouncilDB.profile.mode]
  end

  if not validModes[KeystoneCouncilDB.profile.mode] then
    KeystoneCouncilDB.profile.mode = KC.Defaults.profile.mode
  end

  KeystoneCouncilDB.profile.scale = tonumber(KeystoneCouncilDB.profile.scale) or KC.Defaults.profile.scale
  KeystoneCouncilDB.profile.scale = math.max(0.75, math.min(1.4, KeystoneCouncilDB.profile.scale))

  KeystoneCouncilDB.profile.smart.recentPenalty = tonumber(KeystoneCouncilDB.profile.smart.recentPenalty) or KC.Defaults.profile.smart.recentPenalty
  KeystoneCouncilDB.profile.smart.recentPenalty = math.max(0.1, math.min(1, KeystoneCouncilDB.profile.smart.recentPenalty))
  KeystoneCouncilDB.profile.smart.scoreGapBonus = tonumber(KeystoneCouncilDB.profile.smart.scoreGapBonus) or KC.Defaults.profile.smart.scoreGapBonus
  KeystoneCouncilDB.profile.smart.scoreGapBonus = math.max(0, math.min(20, KeystoneCouncilDB.profile.smart.scoreGapBonus))
  KeystoneCouncilDB.profile.smart.vaultNeedBonus = tonumber(KeystoneCouncilDB.profile.smart.vaultNeedBonus) or KC.Defaults.profile.smart.vaultNeedBonus
  KeystoneCouncilDB.profile.smart.vaultNeedBonus = math.max(0, math.min(20, KeystoneCouncilDB.profile.smart.vaultNeedBonus))
  KeystoneCouncilDB.profile.smart.seasonBestBonus = tonumber(KeystoneCouncilDB.profile.smart.seasonBestBonus) or KC.Defaults.profile.smart.seasonBestBonus
  KeystoneCouncilDB.profile.smart.seasonBestBonus = math.max(0, math.min(20, KeystoneCouncilDB.profile.smart.seasonBestBonus))
  KeystoneCouncilDB.profile.smart.duplicateDungeonPenalty = tonumber(KeystoneCouncilDB.profile.smart.duplicateDungeonPenalty) or KC.Defaults.profile.smart.duplicateDungeonPenalty
  KeystoneCouncilDB.profile.smart.duplicateDungeonPenalty = math.max(0.1, math.min(1, KeystoneCouncilDB.profile.smart.duplicateDungeonPenalty))
  if KeystoneCouncilDB.profile.smart.intent ~= "farm" and KeystoneCouncilDB.profile.smart.intent ~= "push" then
    KeystoneCouncilDB.profile.smart.intent = KC.Defaults.profile.smart.intent
  end

  KeystoneCouncilDB.session.startedAt = tonumber(KeystoneCouncilDB.session.startedAt) or 0
  KeystoneCouncilDB.session.startedAt = KeystoneCouncilDB.session.startedAt > 0 and KeystoneCouncilDB.session.startedAt or time()
  KeystoneCouncilDB.profileVersion = KC.Defaults.profileVersion
end
