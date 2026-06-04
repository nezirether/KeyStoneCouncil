local KC = KeystoneCouncil

KC.PartySync = {
  frame = nil,
  lastBroadcast = 0,
  lastLedgerBroadcast = 0,
  peers = {},
  ackCounts = {},
  ackSenders = {},
  pending = {},
  failed = {},
  failedLimit = 10,
  maxPending = 40,
  retryDelay = 3,
  maxRetries = 2,
  peerTTL = 10 * 60,
  sentCounts = {},
  receivedCounts = {},
}

local function GetChannel()
  if IsInRaid and IsInRaid() then
    return "RAID"
  end
  if IsInGroup and IsInGroup() then
    return "PARTY"
  end
  return nil
end

local function IsValidAddonChannel(channel)
  return channel == "PARTY" or channel == "RAID" or channel == "INSTANCE_CHAT"
end

function KC.PartySync:OnInitialize()
  if self.frame then
    return
  end

  self.peers = type(self.peers) == "table" and self.peers or {}
  self.ackCounts = type(self.ackCounts) == "table" and self.ackCounts or {}
  self.ackSenders = type(self.ackSenders) == "table" and self.ackSenders or {}
  self.pending = type(self.pending) == "table" and self.pending or {}
  self.failed = type(self.failed) == "table" and self.failed or {}
  self.sentCounts = type(self.sentCounts) == "table" and self.sentCounts or {}
  self.receivedCounts = type(self.receivedCounts) == "table" and self.receivedCounts or {}

  if not CreateFrame then
    return
  end

  self.frame = CreateFrame("Frame")

  self.prefixRegistered = false
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    local ok, result = pcall(C_ChatInfo.RegisterAddonMessagePrefix, KC.COMM_PREFIX)
    self.prefixRegistered = ok and result ~= false
  end
  self.frame:RegisterEvent("CHAT_MSG_ADDON")
  self.frame:RegisterEvent("GROUP_ROSTER_UPDATE")
  self.frame:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
      self:OnAddonMessage(...)
    elseif event == "GROUP_ROSTER_UPDATE" and C_Timer and C_Timer.After then
      C_Timer.After(1, function()
        self:BroadcastLocalKey()
        if KC.SharedKeyProvider then
          KC.SharedKeyProvider:RequestPartyKeys()
        end
        if KC.GroupKeyProvider then
          KC.GroupKeyProvider:RequestPartyKeys()
        end
        self:BroadcastHello()
        self:BroadcastLedger()
      end)
    end
  end)
end

function KC.PartySync:Send(payload)
  if type(payload) ~= "string" or payload == "" or string.len(payload) > 900 then
    return false
  end

  local channel = GetChannel()
  if channel and C_ChatInfo and C_ChatInfo.SendAddonMessage then
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, KC.COMM_PREFIX, payload, channel)
    return ok and result ~= false
  end
  return false
end

local function PendingID(kind, token)
  return tostring(kind or "unknown") .. ":" .. tostring(token or "")
end

function KC.PartySync:GetAckCount(kind, token)
  return self.ackCounts[PendingID(kind, token)] or 0
end

function KC.PartySync:GetExpectedAckCount()
  return self:GetPeerCount()
end

local function CountTable(tbl)
  local count = 0
  for _ in pairs(tbl or {}) do
    count = count + 1
  end
  return count
end

function KC.PartySync:IsSatisfied(kind, token)
  local expected = self:GetExpectedAckCount()
  return expected <= 0 or self:GetAckCount(kind, token) >= expected
end

function KC.PartySync:ScheduleRetry()
  if self.retryScheduled then
    return
  end

  self.retryScheduled = true
  local function Run()
    self.retryScheduled = false
    self:ProcessRetries()
  end

  if C_Timer and C_Timer.After then
    C_Timer.After(self.retryDelay, Run)
  else
    Run()
  end
end

function KC.PartySync:TrackReliable(kind, token, payload)
  if not kind or not token or not payload then
    return
  end

  if self:GetExpectedAckCount() <= 0 then
    return
  end

  local id = PendingID(kind, token)
  self.pending[id] = {
    id = id,
    kind = kind,
    token = token,
    payload = payload,
    attempts = 0,
    firstSent = time(),
    lastSent = time(),
    status = "pending",
  }
  self:PrunePendingOverflow()
  self:ScheduleRetry()
end

function KC.PartySync:PrunePendingOverflow()
  local rows = {}
  for id, item in pairs(self.pending or {}) do
    rows[#rows + 1] = {
      id = id,
      firstSent = tonumber(item.firstSent) or 0,
    }
  end

  if #rows <= (self.maxPending or 40) then
    return 0
  end

  table.sort(rows, function(a, b)
    return a.firstSent < b.firstSent
  end)

  local removed = 0
  for index = 1, #rows - (self.maxPending or 40) do
    local id = rows[index].id
    if self.pending[id] then
      self:RecordFailed(self.pending[id])
      self.pending[id] = nil
      self.ackCounts[id] = nil
      self.ackSenders[id] = nil
      removed = removed + 1
    end
  end
  return removed
end

function KC.PartySync:RecordFailed(item)
  if not item then
    return
  end

  self.failed[#self.failed + 1] = {
    id = item.id,
    kind = item.kind,
    token = item.token,
    attempts = item.attempts or 0,
    failedAt = time(),
    ackCount = self:GetAckCount(item.kind, item.token),
    expectedAckCount = self:GetExpectedAckCount(),
  }

  while #self.failed > (self.failedLimit or 10) do
    table.remove(self.failed, 1)
  end
end

function KC.PartySync:SendReliable(kind, token, payload)
  if self:Send(payload) then
    self.sentCounts[kind] = (self.sentCounts[kind] or 0) + 1
    self:TrackReliable(kind, token, payload)
    return true
  end
  return false
end

function KC.PartySync:CancelReliable(kind, token)
  local id = PendingID(kind, token)
  if self.pending[id] then
    self.pending[id] = nil
    self.ackCounts[id] = nil
    self.ackSenders[id] = nil
    return true
  end
  return false
end

function KC.PartySync:ProcessRetries()
  local hasPending = false

  for id, item in pairs(self.pending) do
    if self:IsSatisfied(item.kind, item.token) then
      self.pending[id] = nil
      self.ackCounts[id] = nil
      self.ackSenders[id] = nil
    elseif item.attempts >= self.maxRetries then
      item.status = "failed"
      self:RecordFailed(item)
      self.pending[id] = nil
      self.ackCounts[id] = nil
      self.ackSenders[id] = nil
    else
      item.attempts = item.attempts + 1
      item.lastSent = time()
      item.status = "retry " .. tostring(item.attempts)
      if self:Send(item.payload) then
        self.sentCounts[item.kind] = (self.sentCounts[item.kind] or 0) + 1
      end
      hasPending = true
    end
  end

  if hasPending then
    self:ScheduleRetry()
  end
end

function KC.PartySync:BroadcastLocalKey()
  if time() - self.lastBroadcast < 2 then
    return
  end

  self.lastBroadcast = time()

  if KC.BlizzardKeys and KC.BlizzardKeys.ReadLocalKey then
    local key = KC.BlizzardKeys:ReadLocalKey()
    if key then
      self:SendReliable("KEY", key.ownerName or KC.Util:PlayerFullName(), KC.Protocol:EncodeKey(key))
      KC.KeyStore:Upsert(key)
    end
  end
end

function KC.PartySync:BroadcastHello()
  self:SendReliable("HELLO", KC.Util:PlayerFullName(), KC.Protocol:EncodeHello())
end

function KC.PartySync:ShouldShareLedgerEntry(entry)
  if not entry or entry.isStale then
    return false
  end

  local bucket = entry.bucket or (KC.Util and KC.Util:GetSocialBucket(entry.ownerName, entry.ownerRealm))
  return bucket == "party"
end

function KC.PartySync:BroadcastLedger()
  local options = KeystoneCouncilDB and KeystoneCouncilDB.profile and KeystoneCouncilDB.profile.options or {}
  if options.shareLedger == false or not KC.KeyLedger then
    return
  end

  if time() - self.lastLedgerBroadcast < 5 then
    return
  end

  self.lastLedgerBroadcast = time()
  local sent = 0
  for _, entry in ipairs(KC.KeyLedger:GetAll()) do
    if self:ShouldShareLedgerEntry(entry) then
      self:SendReliable("LEDGER", entry.ownerName or entry.ownerGUID or tostring(sent + 1), KC.Protocol:EncodeLedgerKey(entry))
      sent = sent + 1
      if sent >= 10 then
        break
      end
    end
  end
end

function KC.PartySync:BroadcastVote(keyID)
  self:SendReliable("VOTE", keyID, KC.Protocol:EncodeVote(KC.Util:PlayerFullName(), keyID))
end

function KC.PartySync:BroadcastVoteOpen(mode, token)
  self:SendReliable("VOTE_OPEN", token or mode, KC.Protocol:EncodeVoteOpen(mode, token))
end

function KC.PartySync:BroadcastResult(result)
  self:SendReliable("RESULT", result and result.winnerKeyID, KC.Protocol:EncodeResult(result))
end

function KC.PartySync:ApplyRemoteVoteOpen(sender, data)
  local mode = KC.Modes and KC.Modes.NormalizeMode and KC.Modes:NormalizeMode(data.mode)
  if not mode then
    KC.Logger:Debug("Dropped vote-open with invalid mode from " .. tostring(sender))
    return
  end

  local token = tostring(data.token or "")
  local alreadyOpen = KeystoneCouncilDB
    and KeystoneCouncilDB.session
    and KeystoneCouncilDB.session.voteOpen == true
    and KeystoneCouncilDB.session.voteToken == token

  if KC.Modes then
    KC.Modes:SetMode(mode)
  end
  if KC.SessionStore and KC.SessionStore.StartVoteSession then
    if not KC.SessionStore:StartVoteSession(mode, token) then
      return
    end
  end

  if alreadyOpen then
    return
  end

  if KC.MainFrame then
    KC.MainFrame:Show()
  end
  if KC.KeyList and KC.KeyList.SetView then
    KC.KeyList:SetView("party")
  end
  if KC.VotePanel and KC.VotePanel.Refresh then
    KC.VotePanel:Refresh()
  end

  local label = mode == "majority" and "Majority vote" or "Raffle"
  KC.Logger:Print(label .. " opened by " .. tostring(data.playerName or sender or "party") .. ".")
  if KC.Toasts then
    KC.Toasts:Show(label .. " opened.")
  end
end

function KC.PartySync:TrackPeer(sender, data)
  self:PrunePeers()

  local name = data and data.playerName and data.playerName ~= "" and data.playerName or sender
  local existing = self.peers[sender] or {}
  local addonVersion = data and data.addonVersion
  if not addonVersion or addonVersion == "" or addonVersion == "unknown" then
    addonVersion = existing.addonVersion or "unknown"
  end

  self.peers[sender] = {
    name = name,
    addonVersion = addonVersion,
    protocolVersion = KC.PROTOCOL_VERSION,
    lastSeen = time(),
    versionMismatch = addonVersion ~= "unknown" and addonVersion ~= KC.VERSION,
  }
end

function KC.PartySync:PrunePeers()
  local now = time()
  for sender, peer in pairs(self.peers) do
    if now - (tonumber(peer.lastSeen) or now) > self.peerTTL then
      self.peers[sender] = nil
    end
  end
end

function KC.PartySync:TrackAck(sender, data)
  local key = tostring(data.ackKind or "unknown") .. ":" .. tostring(data.token or "")
  self.ackSenders[key] = self.ackSenders[key] or {}
  if self.ackSenders[key][sender] then
    self:TrackPeer(sender, { playerName = data.playerName, addonVersion = "unknown" })
    return
  end

  self.ackSenders[key][sender] = true
  self.ackCounts[key] = (self.ackCounts[key] or 0) + 1
  if self.pending[key] and self:IsSatisfied(data.ackKind, data.token) then
    self.pending[key] = nil
    self.ackCounts[key] = nil
    self.ackSenders[key] = nil
  elseif CountTable(self.ackCounts) > 50 then
    self.ackCounts = {}
    self.ackSenders = {}
  end
  self:TrackPeer(sender, { playerName = data.playerName, addonVersion = "unknown" })
end

function KC.PartySync:GetPeerCount()
  self:PrunePeers()

  local count = 0
  for _ in pairs(self.peers) do
    count = count + 1
  end
  return count
end

function KC.PartySync:GetPeerRows()
  self:PrunePeers()

  local rows = {}
  for sender, peer in pairs(self.peers) do
    rows[#rows + 1] = {
      sender = sender,
      name = peer.name or sender,
      addonVersion = peer.addonVersion or "unknown",
      protocolVersion = peer.protocolVersion or "unknown",
      lastSeen = peer.lastSeen or 0,
      versionMismatch = peer.versionMismatch == true,
    }
  end

  table.sort(rows, function(a, b)
    return tostring(a.name) < tostring(b.name)
  end)

  return rows
end

function KC.PartySync:GetAckRows()
  local rows = {}
  for token, count in pairs(self.ackCounts) do
    rows[#rows + 1] = {
      token = token,
      count = count,
    }
  end

  table.sort(rows, function(a, b)
    return tostring(a.token) < tostring(b.token)
  end)

  return rows
end

function KC.PartySync:GetPendingRows()
  local rows = {}
  for _, item in pairs(self.pending) do
    rows[#rows + 1] = {
      id = item.id,
      kind = item.kind,
      token = item.token,
      attempts = item.attempts or 0,
      status = item.status or "pending",
      lastSent = item.lastSent or 0,
      ackCount = self:GetAckCount(item.kind, item.token),
      expectedAckCount = self:GetExpectedAckCount(),
    }
  end

  table.sort(rows, function(a, b)
    return tostring(a.id) < tostring(b.id)
  end)

  return rows
end

function KC.PartySync:GetFailedRows()
  local rows = {}
  for _, item in ipairs(self.failed or {}) do
    rows[#rows + 1] = item
  end
  table.sort(rows, function(a, b)
    return (tonumber(a.failedAt) or 0) > (tonumber(b.failedAt) or 0)
  end)
  return rows
end

function KC.PartySync:GetTrafficRows()
  local rows = {}
  local seen = {}
  for kind, count in pairs(self.sentCounts or {}) do
    seen[kind] = true
    rows[#rows + 1] = {
      kind = kind,
      sent = count,
      received = (self.receivedCounts or {})[kind] or 0,
    }
  end
  for kind, count in pairs(self.receivedCounts or {}) do
    if not seen[kind] then
      rows[#rows + 1] = {
        kind = kind,
        sent = (self.sentCounts or {})[kind] or 0,
        received = count,
      }
    end
  end
  table.sort(rows, function(a, b)
    return tostring(a.kind) < tostring(b.kind)
  end)
  return rows
end

function KC.PartySync:GetVersionIssueCount()
  local count = 0
  for _, peer in pairs(self.peers) do
    if peer.versionMismatch then
      count = count + 1
    end
  end
  return count
end

function KC.PartySync:GetStatusLine()
  local pendingRows = self:GetPendingRows()
  local failedRows = self:GetFailedRows()
  return "PartySync: peers " .. tostring(self:GetPeerCount()) .. ", mismatches " .. tostring(self:GetVersionIssueCount()) .. ", pending " .. tostring(#pendingRows) .. ", failed " .. tostring(#failedRows) .. ", protocol " .. tostring(KC.PROTOCOL_VERSION)
end

function KC.PartySync:OnAddonMessage(prefix, payload, channel, sender)
  if prefix ~= KC.COMM_PREFIX or KC.Util:IsSelfSender(sender) then
    return
  end
  if not IsValidAddonChannel(channel) or not sender or sender == "" then
    return
  end

  local kind, data, err = KC.Protocol:Decode(payload)
  if err then
    KC.Logger:Debug("Dropped addon message from " .. tostring(sender) .. ": " .. err)
    return
  end
  self.receivedCounts[kind] = (self.receivedCounts[kind] or 0) + 1
  self:TrackPeer(sender, {
    playerName = data and data.playerName or sender,
    addonVersion = data and data.addonVersion or "unknown",
  })

  if kind == "KEY" then
    KC.KeyStore:Upsert(data)
    self:Send(KC.Protocol:EncodeAck("KEY", data.ownerName or sender))
  elseif kind == "LEDGER" then
    if KC.KeyLedger then
      local entry = KC.KeyLedger:Record(data)
      if entry and not KC.KeyLedger:IsEntryStale(entry) then
        KC.KeyStore:Upsert(entry)
      end
    else
      KC.KeyStore:Upsert(data)
    end
    self:Send(KC.Protocol:EncodeAck("LEDGER", data.ownerName or sender))
  elseif kind == "VOTE" then
    if data.keyID and KC.KeyStore:Get(data.keyID) then
      KC.SessionStore:SetVote(data.unitName, data.keyID)
      self:Send(KC.Protocol:EncodeAck("VOTE", data.keyID))
    else
      KC.Logger:Debug("Dropped vote for unavailable key from " .. tostring(sender))
    end
  elseif kind == "VOTE_OPEN" then
    self:TrackPeer(sender, data)
    self:ApplyRemoteVoteOpen(sender, data)
    self:Send(KC.Protocol:EncodeAck("VOTE_OPEN", data.token))
  elseif kind == "RESULT" and KC.Modes then
    KC.Modes:ApplyRemoteResult(data)
    self:Send(KC.Protocol:EncodeAck("RESULT", data.winnerKeyID))
  elseif kind == "HELLO" then
    self:TrackPeer(sender, data)
    self:Send(KC.Protocol:EncodeAck("HELLO", data.playerName or sender))
    if C_Timer and C_Timer.After then
      C_Timer.After(0.5, function()
        self:BroadcastLedger()
      end)
    else
      self:BroadcastLedger()
    end
  elseif kind == "ACK" then
    self:TrackAck(sender, data)
  end
end

KC:RegisterModule("PartySync", KC.PartySync)
