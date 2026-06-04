local KC = KeystoneCouncil

KC.StatsStore = {}

local function EnsureStats()
  KeystoneCouncilDB.global.stats = KeystoneCouncilDB.global.stats or {}
  if type(KeystoneCouncilDB.global.stats) ~= "table" then
    KeystoneCouncilDB.global.stats = {}
  end
  KeystoneCouncilDB.global.stats.players = KeystoneCouncilDB.global.stats.players or {}
  KeystoneCouncilDB.global.stats.dungeons = KeystoneCouncilDB.global.stats.dungeons or {}
  if type(KeystoneCouncilDB.global.stats.players) ~= "table" then
    KeystoneCouncilDB.global.stats.players = {}
  end
  if type(KeystoneCouncilDB.global.stats.dungeons) ~= "table" then
    KeystoneCouncilDB.global.stats.dungeons = {}
  end
  KeystoneCouncilDB.global.stats.totalSelections = KeystoneCouncilDB.global.stats.totalSelections or 0
  return KeystoneCouncilDB.global.stats
end

function KC.StatsStore:Record(result)
  local stats = EnsureStats()
  local playerKey = result.ownerGUID or result.ownerName or "Unknown"
  local dungeonKey = tostring(result.dungeonID or result.dungeonName or "Unknown")

  stats.totalSelections = stats.totalSelections + 1

  stats.players[playerKey] = stats.players[playerKey] or {
    name = result.ownerName or "Unknown",
    selected = 0,
  }
  stats.players[playerKey].selected = stats.players[playerKey].selected + 1
  stats.players[playerKey].name = result.ownerName or stats.players[playerKey].name

  stats.dungeons[dungeonKey] = stats.dungeons[dungeonKey] or {
    name = result.dungeonName or "Unknown",
    selected = 0,
  }
  stats.dungeons[dungeonKey].selected = stats.dungeons[dungeonKey].selected + 1
  stats.dungeons[dungeonKey].name = result.dungeonName or stats.dungeons[dungeonKey].name
end

function KC.StatsStore:GetSummary()
  local stats = EnsureStats()
  local topPlayer
  local topDungeon

  for _, player in pairs(stats.players) do
    if not topPlayer or player.selected > topPlayer.selected then
      topPlayer = player
    end
  end

  for _, dungeon in pairs(stats.dungeons) do
    if not topDungeon or dungeon.selected > topDungeon.selected then
      topDungeon = dungeon
    end
  end

  return {
    totalSelections = stats.totalSelections or 0,
    topPlayer = topPlayer,
    topDungeon = topDungeon,
  }
end

KC:RegisterModule("StatsStore", KC.StatsStore)
