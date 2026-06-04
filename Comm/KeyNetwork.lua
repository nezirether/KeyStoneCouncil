local KC = KeystoneCouncil

KC.KeyNetwork = {
  frame = nil,
  lastBroadcast = 0,
  received = 0,
  imported = 0,
  sent = 0,
  guildPeers = {},
}

local function Now()
  return time and time() or 0
end

local function CanGuild()
  return IsInGuild and IsInGuild() and C_ChatInfo and C_ChatInfo.SendAddonMessage
end

function KC.KeyNetwork:OnInitialize()
  if self.frame or not CreateFrame then
    return
  end

  self.frame = CreateFrame("Frame")
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, KC.COMM_PREFIX)
  end
  self.frame:RegisterEvent("CHAT_MSG_ADDON")
  self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  self.frame:RegisterEvent("GUILD_ROSTER_UPDATE")
  self.frame:RegisterEvent("BAG_UPDATE_DELAYED")
  self.frame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
  self.frame:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
      self:OnAddonMessage(...)
    else
      if C_Timer and C_Timer.After then
        C_Timer.After(2, function() self:BroadcastLocalKey() end)
      else
        self:BroadcastLocalKey()
      end
    end
  end)
end

function KC.KeyNetwork:OnEnable()
  if C_Timer and C_Timer.After then
    C_Timer.After(4, function() self:BroadcastLocalKey() end)
  else
    self:BroadcastLocalKey()
  end
end

function KC.KeyNetwork:SendGuild(payload)
  if not CanGuild() or not payload or payload == "" then
    return false
  end
  local ok, result = pcall(C_ChatInfo.SendAddonMessage, KC.COMM_PREFIX, payload, "GUILD")
  if ok and result ~= false then
    self.sent = (self.sent or 0) + 1
    return true
  end
  return false
end

function KC.KeyNetwork:BroadcastLocalKey(force)
  if not force and Now() - (self.lastBroadcast or 0) < 20 then
    return false
  end
  self.lastBroadcast = Now()

  local key = KC.BlizzardKeys and KC.BlizzardKeys.ReadLocalKey and KC.BlizzardKeys:ReadLocalKey()
  if not key then
    return false
  end
  KC.KeyStore:Upsert(key)
  return self:SendGuild(KC.Protocol:EncodeKey(key))
end

function KC.KeyNetwork:OnAddonMessage(prefix, payload, channel, sender)
  if prefix ~= KC.COMM_PREFIX or channel ~= "GUILD" or not sender or sender == "" then
    return
  end
  if KC.Util and KC.Util.IsSelfSender and KC.Util:IsSelfSender(sender) then
    return
  end

  local kind, data = KC.Protocol:Decode(payload)
  if kind == "KEY" and data then
    self.received = (self.received or 0) + 1
    self.imported = (self.imported or 0) + 1
    self.guildPeers[sender] = Now()
    data.source = "KeyNetwork"
    -- Received via GUILD channel so the sender is a guild member by definition.
    if not data.sourceBucket or data.sourceBucket == "" then
      data.sourceBucket = "guild"
    end
    KC.KeyStore:Upsert(data)
  elseif kind == "HELLO" and data then
    self.guildPeers[sender] = Now()
  end
end

function KC.KeyNetwork:GetPeerCount()
  local now = Now()
  local count = 0
  for sender, seen in pairs(self.guildPeers or {}) do
    if now - (tonumber(seen) or 0) <= 3600 then
      count = count + 1
    else
      self.guildPeers[sender] = nil
    end
  end
  return count
end

function KC.KeyNetwork:GetStatusLine()
  return "KC guild network: sent " .. tostring(self.sent or 0)
    .. ", received " .. tostring(self.received or 0)
    .. ", imported " .. tostring(self.imported or 0)
    .. ", peers " .. tostring(self:GetPeerCount())
end

KC:RegisterModule("KeyNetwork", KC.KeyNetwork)
