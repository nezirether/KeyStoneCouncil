local KC = KeystoneCouncil

KC.SessionStore = {
  maxSelections = 50,
}

local function EnsureSession()
  KeystoneCouncilDB.session = KeystoneCouncilDB.session or {}
  if type(KeystoneCouncilDB.session.votes) ~= "table" then
    KeystoneCouncilDB.session.votes = {}
  end
  if type(KeystoneCouncilDB.session.selections) ~= "table" then
    KeystoneCouncilDB.session.selections = {}
  end
  if KeystoneCouncilDB.session.voteOpen == nil then
    KeystoneCouncilDB.session.voteOpen = false
  end
  if type(KeystoneCouncilDB.session.voteMode) ~= "string" then
    KeystoneCouncilDB.session.voteMode = ""
  end
  if type(KeystoneCouncilDB.session.voteToken) ~= "string" then
    KeystoneCouncilDB.session.voteToken = ""
  end
  if type(KeystoneCouncilDB.session.closedVoteTokens) ~= "table" then
    KeystoneCouncilDB.session.closedVoteTokens = {}
  end
  if type(KeystoneCouncilDB.session.closedVoteOrder) ~= "table" then
    KeystoneCouncilDB.session.closedVoteOrder = {}
  end
  return KeystoneCouncilDB.session
end

local function Now()
  return time and time() or 0
end

local function RandomTokenPart()
  if math and math.random then
    return math.random(1000, 9999)
  end
  return 0
end

function KC.SessionStore:IsVoteTokenClosed(token)
  local session = EnsureSession()
  token = tostring(token or "")
  return token ~= "" and session.closedVoteTokens[token] == true
end

function KC.SessionStore:MarkVoteTokenClosed(token)
  local session = EnsureSession()
  token = tostring(token or "")
  if token == "" or session.closedVoteTokens[token] then
    return
  end

  session.closedVoteTokens[token] = true
  session.closedVoteOrder[#session.closedVoteOrder + 1] = token
  while #session.closedVoteOrder > 20 do
    local oldToken = table.remove(session.closedVoteOrder, 1)
    if oldToken then
      session.closedVoteTokens[oldToken] = nil
    end
  end
end

function KC.SessionStore:IsVoteOpen()
  return KeystoneCouncilDB and EnsureSession().voteOpen == true
end

function KC.SessionStore:SetVoteOpen(isOpen)
  local session = EnsureSession()
  local closingToken = session.voteToken
  session.voteOpen = isOpen and true or false
  if not session.voteOpen then
    self:MarkVoteTokenClosed(closingToken)
    session.voteMode = ""
    session.voteToken = ""
  end
  KC.EventBus:Emit(KC.EVENTS.SESSION_CHANGED, session)
end

function KC.SessionStore:StartVoteSession(mode, token)
  local session = EnsureSession()
  if KC.Modes and KC.Modes.NormalizeMode then
    mode = KC.Modes:NormalizeMode(mode) or "raffle"
  else
    mode = tostring(mode or "raffle")
  end
  token = tostring(token or "")
  if token == "" then
    token = tostring(mode or "vote") .. ":" .. tostring(Now()) .. ":" .. tostring(RandomTokenPart())
  end
  if self:IsVoteTokenClosed(token) then
    return nil
  end

  if session.voteToken ~= token then
    session.votes = {}
    KC.EventBus:Emit(KC.EVENTS.VOTES_CHANGED, session.votes)
  end

  session.voteOpen = true
  session.voteMode = mode
  session.voteToken = token
  KC.EventBus:Emit(KC.EVENTS.SESSION_CHANGED, session)
  return token
end

function KC.SessionStore:RecordSelection(result)
  local session = EnsureSession()
  local resultID = result.id or result.resultID
  if resultID then
    for _, selection in ipairs(session.selections) do
      if selection.id == resultID or selection.resultID == resultID then
        return false
      end
    end
  end

  session.selections[#session.selections + 1] = result
  while #session.selections > self.maxSelections do
    table.remove(session.selections, 1)
  end

  KC.EventBus:Emit(KC.EVENTS.SESSION_CHANGED, session)
  return true
end

function KC.SessionStore:SetVote(unitName, keyID)
  local session = EnsureSession()
  session.votes[unitName] = keyID
  KC.EventBus:Emit(KC.EVENTS.VOTES_CHANGED, session.votes)
end

function KC.SessionStore:PruneVotes(keys)
  local valid = {}
  local changed = false

  for _, key in ipairs(keys or KC.KeyStore:GetAll()) do
    valid[key.id] = true
  end

  local session = EnsureSession()
  for voter, keyID in pairs(session.votes or {}) do
    if not valid[keyID] then
      session.votes[voter] = nil
      changed = true
    end
  end

  if changed then
    KC.EventBus:Emit(KC.EVENTS.VOTES_CHANGED, session.votes)
  end
end

function KC.SessionStore:ClearVotes()
  local session = EnsureSession()
  session.votes = {}
  KC.EventBus:Emit(KC.EVENTS.VOTES_CHANGED, session.votes)
end

function KC.SessionStore:OnEnable()
  KC.EventBus:On(KC.EVENTS.KEYS_CHANGED, self, function(owner, keys)
    owner:PruneVotes(keys)
  end)
end

KC:RegisterModule("SessionStore", KC.SessionStore)
