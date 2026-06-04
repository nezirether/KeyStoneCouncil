local KC = KeystoneCouncil

KC.SmartEngine = {}

function KC.SmartEngine:GetFrameworkSignals(key, lowestScore)
  local smart = KeystoneCouncilDB.profile.smart or {}
  local signals = {
    base = 10 + math.min(tonumber(key.level) or 0, 20),
    reasons = { "level +" .. tostring(math.min(tonumber(key.level) or 0, 20)) },
  }

  if smart.preferLowestScore and lowestScore and tonumber(key.score) and tonumber(key.score) == lowestScore then
    signals.scoreBonus = tonumber(smart.scoreGapBonus) or 4
    signals.reasons[#signals.reasons + 1] = "lowest score catch-up"
  end

  if smart.preferVaultNeeds and tonumber(key.weeklyBest or 0) < tonumber(key.level or 0) then
    signals.vaultBonus = tonumber(smart.vaultNeedBonus) or 6
    signals.reasons[#signals.reasons + 1] = "vault upgrade opportunity"
  end

  local seasonBest = KC.SeasonBest and KC.SeasonBest.GetBestForDungeon and KC.SeasonBest:GetBestForDungeon(key.dungeonID)
  if seasonBest and tonumber(key.level or 0) > tonumber(seasonBest.level or 0) then
    signals.seasonBestBonus = tonumber(smart.seasonBestBonus) or 3
    signals.reasons[#signals.reasons + 1] = "season-best upgrade opportunity"
  end

  if KC.HistoryStore and KC.HistoryStore.WasRecentlySelected and KC.HistoryStore:WasRecentlySelected(key.ownerGUID, key.dungeonID, key.ownerName, key.ownerRealm) then
    signals.historyMultiplier = tonumber(smart.recentPenalty) or 0.65
    signals.reasons[#signals.reasons + 1] = "recent history penalty"
  end

  if smart.intent == "push" then
    signals.intentBonus = math.floor((tonumber(key.level) or 0) / 5)
    signals.reasons[#signals.reasons + 1] = "push intent"
  elseif smart.intent == "farm" and tonumber(key.weeklyBest or 0) >= tonumber(key.level or 0) then
    signals.intentBonus = 2
    signals.reasons[#signals.reasons + 1] = "farm intent"
  end

  return signals
end

function KC.SmartEngine:CalculateWeight(key, lowestScore)
  local signals = self:GetFrameworkSignals(key, lowestScore)
  local weight = signals.base
  weight = weight + (tonumber(signals.scoreBonus) or 0)
  weight = weight + (tonumber(signals.vaultBonus) or 0)
  weight = weight + (tonumber(signals.seasonBestBonus) or 0)
  weight = weight + (tonumber(signals.intentBonus) or 0)
  if signals.historyMultiplier then
    weight = weight * signals.historyMultiplier
  end
  return math.max(1, math.floor(weight)), table.concat(signals.reasons, ", ")
end

function KC.SmartEngine:GetWeights(keys)
  local weights = {}
  self.lastReasons = {}

  local lowestScore
  for _, key in ipairs(keys) do
    local score = tonumber(key.score)
    if score and score > 0 and (not lowestScore or score < lowestScore) then
      lowestScore = score
    end
  end

  for _, key in ipairs(keys) do
    local weight, reason = self:CalculateWeight(key, lowestScore)
    weights[key.id] = weight
    self.lastReasons[key.id] = reason
  end

  return weights
end

function KC.SmartEngine:GetReason(winnerKeyID)
  if winnerKeyID and self.lastReasons and self.lastReasons[winnerKeyID] then
    return "Smart Mode: " .. self.lastReasons[winnerKeyID] .. "."
  end

  return "Smart Mode weighs key level, score gaps, vault opportunities, season-best opportunities, intent, and recent Council history."
end

KC:RegisterModule("SmartEngine", KC.SmartEngine)
