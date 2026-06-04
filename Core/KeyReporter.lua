local KC = KeystoneCouncil

KC.KeyReporter = {
  frame = nil,
  lastSignature = "unknown",
  lastReplies = {},
  replyThrottleSeconds = 4,
  refreshAfterCombat = false,
}

local MYTHIC_KEY_CITY_NPCID = 197711

local function ParseNpcID(guid)
  if type(guid) ~= "string" then
    return nil
  end

  local _, _, _, _, _, npcID = string.match(guid, "([^%-]+)%-(.-)%-(.-)%-(.-)%-(.-)%-(.+)")
  return tonumber(npcID)
end

local function ReplyThrottleKey(channel, sender)
  return tostring(channel or "UNKNOWN") .. ":" .. tostring(sender or "unknown")
end

function KC.KeyReporter:PruneReplyThrottle(now)
  now = now or (time and time() or 0)
  local count = 0
  for key, timestamp in pairs(self.lastReplies or {}) do
    count = count + 1
    if now <= 0 or now - (tonumber(timestamp) or 0) > 60 then
      self.lastReplies[key] = nil
      count = count - 1
    end
  end

  if count > 40 then
    self.lastReplies = {}
  end
end

local function ReportingConfig()
  return KeystoneCouncilDB and KeystoneCouncilDB.profile and KeystoneCouncilDB.profile.keyReporting or {}
end

local function SendLine(channel, text)
  if not channel or not text then
    return false
  end

  local ok = false
  if C_ChatInfo and C_ChatInfo.SendChatMessage then
    ok = pcall(C_ChatInfo.SendChatMessage, text, channel)
  elseif SendChatMessage then
    ok = pcall(SendChatMessage, text, channel)
  end
  if not ok and KC.Logger then
    KC.Logger:Debug("Chat reply blocked for " .. tostring(channel) .. ": " .. tostring(text))
  end
  return ok
end

local function RegisterEventSafe(frame, event)
  if frame and frame.RegisterEvent then
    pcall(frame.RegisterEvent, frame, event)
  end
end

function KC.KeyReporter:GetCommand()
  local command = ReportingConfig().chatCommand
  if type(command) ~= "string" or command == "" then
    return "!keys"
  end
  return string.lower(command)
end

function KC.KeyReporter:IsReportCommand(text)
  local normalized = KC.Util:NormalizeChatCommand(text)
  local configured = self:GetCommand()

  return normalized == configured or normalized == "!keys" or normalized == "!key"
end

function KC.KeyReporter:BuildOwnedKeyMessage()
  local key = KC.Util:GetOwnedKey()
  if key then
    return "Keystone Council: " .. KC.Util:FormatKeystoneLink(key)
  end

  if ReportingConfig().includeNoKey then
    return "Keystone Council: no key"
  end

  return nil
end

function KC.KeyReporter:BuildVisibleKeyMessages(channel)
  local config = ReportingConfig()
  if not config.respondAllVisibleKeys then
    return nil
  end

  local view = "party"
  if channel == "GUILD" then
    view = "guild"
  elseif channel == "RAID" or channel == "INSTANCE_CHAT" or channel == "SAY" then
    view = "party"
  end

  local keys = KC.KeyStore and KC.KeyStore.GetByView and KC.KeyStore:GetByView(view) or {}
  if #keys == 0 then
    return nil
  end

  local lines = {}
  for index, key in ipairs(keys) do
    if index > 5 then
      break
    end
    lines[#lines + 1] = tostring(key.ownerName or "Unknown") .. ": " .. KC.Util:FormatKeystoneLink(key)
  end

  return lines
end

function KC.KeyReporter:ReplyToChat(channel, sender)
  local now = time and time() or 0
  self:PruneReplyThrottle(now)
  local throttleKey = ReplyThrottleKey(channel, sender)
  if now > 0 and self.lastReplies[throttleKey] and now - self.lastReplies[throttleKey] < self.replyThrottleSeconds then
    return
  end
  self.lastReplies[throttleKey] = now

  local lines = self:BuildVisibleKeyMessages(channel)
  if lines and #lines > 0 then
    for _, line in ipairs(lines) do
      SendLine(channel, "Keystone Council: " .. line)
    end
    return
  end

  local ownedLine = self:BuildOwnedKeyMessage()
  if ownedLine then
    SendLine(channel, ownedLine)
  end
end

function KC.KeyReporter:AnnounceNewKey(key)
  local line = "Keystone Council: new key " .. KC.Util:FormatKeystoneLink(key)
  local config = ReportingConfig()

  if config.announceNewKeyParty and IsInGroup and IsInGroup() then
    SendLine("PARTY", line)
  end

  if config.announceNewKeyGuild and IsInGuild and IsInGuild() then
    SendLine("GUILD", line)
  end
end

function KC.KeyReporter:CheckLocalKey(shouldAnnounce)
  local key = KC.Util:GetOwnedKey()
  local signature = KC.Util:KeySignature(key)
  local previous = self.lastSignature
  self.lastSignature = signature

  if shouldAnnounce and key and previous ~= "unknown" and previous ~= signature then
    self:AnnounceNewKey(key)
  end
end

function KC.KeyReporter:ScheduleLocalKeyCheck(shouldAnnounce)
  if InCombatLockdown and InCombatLockdown() then
    self.refreshAfterCombat = true
    return
  end

  local function RunCheck()
    if C_MythicPlus and C_MythicPlus.RequestRewards then
      pcall(C_MythicPlus.RequestRewards)
    end
    self:CheckLocalKey(shouldAnnounce)
  end

  if C_Timer and C_Timer.After then
    C_Timer.After(3, RunCheck)
  else
    RunCheck()
  end
end

function KC.KeyReporter:HandleChat(event, text, sender)
  if not self:IsReportCommand(text) then
    return
  end

  local config = ReportingConfig()
  if event == "CHAT_MSG_GUILD" and config.respondGuild then
    self:ReplyToChat("GUILD", sender)
  elseif (event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER") and config.respondParty then
    self:ReplyToChat("PARTY", sender)
  elseif (event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER") and config.respondRaid then
    self:ReplyToChat("RAID", sender)
  elseif (event == "CHAT_MSG_INSTANCE_CHAT" or event == "CHAT_MSG_INSTANCE_CHAT_LEADER") and config.respondInstance then
    self:ReplyToChat("INSTANCE_CHAT", sender)
  elseif event == "CHAT_MSG_SAY" and config.respondSay then
    self:ReplyToChat("SAY", sender)
  end
end

function KC.KeyReporter:OnInitialize()
  if self.frame then
    return
  end

  if not CreateFrame then
    return
  end

  self.frame = CreateFrame("Frame")
  RegisterEventSafe(self.frame, "CHAT_MSG_GUILD")
  RegisterEventSafe(self.frame, "CHAT_MSG_PARTY")
  RegisterEventSafe(self.frame, "CHAT_MSG_PARTY_LEADER")
  RegisterEventSafe(self.frame, "CHAT_MSG_RAID")
  RegisterEventSafe(self.frame, "CHAT_MSG_RAID_LEADER")
  RegisterEventSafe(self.frame, "CHAT_MSG_INSTANCE_CHAT")
  RegisterEventSafe(self.frame, "CHAT_MSG_INSTANCE_CHAT_LEADER")
  RegisterEventSafe(self.frame, "CHAT_MSG_SAY")
  RegisterEventSafe(self.frame, "PLAYER_ENTERING_WORLD")
  RegisterEventSafe(self.frame, "CHALLENGE_MODE_COMPLETED")
  RegisterEventSafe(self.frame, "CHALLENGE_MODE_RESET")
  RegisterEventSafe(self.frame, "ITEM_CHANGED")
  RegisterEventSafe(self.frame, "GOSSIP_CLOSED")
  RegisterEventSafe(self.frame, "PLAYER_REGEN_ENABLED")

  self.frame:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_GUILD" or event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" or event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" or event == "CHAT_MSG_INSTANCE_CHAT" or event == "CHAT_MSG_INSTANCE_CHAT_LEADER" or event == "CHAT_MSG_SAY" then
      self:HandleChat(event, ...)
      return
    end

    if event == "PLAYER_ENTERING_WORLD" then
      self:CheckLocalKey(false)
      return
    end

    if event == "PLAYER_REGEN_ENABLED" then
      if self.refreshAfterCombat then
        self.refreshAfterCombat = false
        self:ScheduleLocalKeyCheck(true)
      end
      return
    end

    if event == "GOSSIP_CLOSED" then
      local guid = UnitGUID and UnitGUID("target")
      local npcID = ParseNpcID(guid)
      if npcID == MYTHIC_KEY_CITY_NPCID then
        self:ScheduleLocalKeyCheck(true)
      end
      return
    end

    if event == "ITEM_CHANGED" or event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
      self:ScheduleLocalKeyCheck(true)
    end
  end)
end

KC:RegisterModule("KeyReporter", KC.KeyReporter)
