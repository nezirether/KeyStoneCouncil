local KC = KeystoneCouncil

KC.VoteEngine = {}

function KC.VoteEngine:GetWeights(keys)
  local weights = {}
  local votes = KeystoneCouncilDB.session.votes or {}

  for _, key in ipairs(keys) do
    weights[key.id] = 1
  end

  for _, keyID in pairs(votes) do
    if weights[keyID] then
      weights[keyID] = weights[keyID] + 3
    end
  end

  return weights
end

function KC.VoteEngine:Vote(keyID)
  if not keyID or not KC.KeyStore:Get(keyID) then
    KC.Logger:Print("That key is no longer available.")
    return false
  end

  if not (KC.Modes and KC.Modes.IsVoteMode and KC.Modes:IsVoteMode() and KC.SessionStore and KC.SessionStore:IsVoteOpen()) then
    KC.Logger:Print("No vote is open yet. Start a raffle or majority vote first.")
    return false
  end

  local isPartyCandidate = false
  local candidates = KC.Modes and KC.Modes.GetCandidateKeys and KC.Modes:GetCandidateKeys() or KC.KeyStore:GetByView("party")
  for _, key in ipairs(candidates) do
    if key.id == keyID then
      isPartyCandidate = true
      break
    end
  end

  if not isPartyCandidate then
    KC.Logger:Print("Only current eligible keys can be voted on.")
    return false
  end

  local player = KC.Util:PlayerFullName()
  KC.SessionStore:SetVote(player, keyID)
  if KC.PartySync then
    KC.PartySync:BroadcastVote(keyID)
  end
  return true
end

KC:RegisterModule("VoteEngine", KC.VoteEngine)
