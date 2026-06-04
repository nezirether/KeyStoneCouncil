local KC = KeystoneCouncil

KC.Modes = {}
KC.Modes.announcementToken = 0

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

local modeLabels = {
  spin = "Spin",
  raffle = "Raffle",
  majority = "Majority vote",
  smart = "Smart",
}

local function BuildWinnerLine(result)
  return "The Council Has Chosen: " .. tostring(result.ownerName or "Unknown") .. "'s +" .. tostring(result.level or "?") .. " " .. tostring(result.dungeonName or "Unknown")
end

local function SafeSendChatMessage(text, channel)
  if not text or not channel then
    return false
  end

  local ok = false
  if C_ChatInfo and C_ChatInfo.SendChatMessage then
    ok = pcall(C_ChatInfo.SendChatMessage, text, channel)
  elseif SendChatMessage then
    ok = pcall(SendChatMessage, text, channel)
  end

  if not ok and KC.Logger then
    KC.Logger:Print("WoW blocked the chat announcement. Result: " .. tostring(text))
  end
  return ok
end

function KC.Modes:GetMode()
  local mode = self:NormalizeMode(KeystoneCouncilDB.profile.mode) or "spin"
  KeystoneCouncilDB.profile.mode = mode
  return mode
end

function KC.Modes:NormalizeMode(mode)
  mode = string.lower(tostring(mode or ""))
  mode = modeAliases[mode] or mode
  return validModes[mode] and mode or nil
end

function KC.Modes:SetMode(mode)
  KeystoneCouncilDB.profile.mode = self:NormalizeMode(mode) or "spin"
  KC.EventBus:Emit(KC.EVENTS.SESSION_CHANGED, KeystoneCouncilDB.session)
end

function KC.Modes:IsVoteMode(mode)
  mode = self:NormalizeMode(mode or self:GetMode())
  return mode == "raffle" or mode == "majority"
end

function KC.Modes:GetModeLabel(mode)
  mode = self:NormalizeMode(mode or self:GetMode()) or "spin"
  return modeLabels[mode] or mode
end

function KC.Modes:BuildWeights(mode, keys)
  if mode == "raffle" then
    return KC.VoteEngine:GetWeights(keys), "Votes improve the odds, but the wheel still decides."
  end

  if mode == "smart" then
    return KC.SmartEngine:GetWeights(keys), nil
  end

  local weights = {}
  for _, key in ipairs(keys) do
    weights[key.id] = 1
  end
  return weights, "Every submitted key is equally eligible."
end

function KC.Modes:GetCandidateKeys()
  local result = {}
  for _, key in ipairs(KC.KeyStore:GetByView("party")) do
    if not key.isStale then
      result[#result + 1] = key
    end
  end

  return result, "party"
end

function KC.Modes:Start()
  local keys, source = self:GetCandidateKeys()
  if #keys == 0 then
    KC.Logger:Print("No party keystones found yet. Ask the group to refresh or open Keystone Council.")
    return
  end

  if #keys == 1 then
    KC.Logger:Print("Only one eligible " .. tostring(source or "party") .. " key is available, so the Council will choose it.")
  end

  local mode = self:GetMode()
  if self:IsVoteMode(mode) and KC.SessionStore and not KC.SessionStore:IsVoteOpen() then
    local voteToken = KC.SessionStore.StartVoteSession and KC.SessionStore:StartVoteSession(mode) or nil
    if KC.SessionStore.StartVoteSession and not voteToken then
      KC.Logger:Print("Could not start vote session.")
      return
    end
    if KC.PortalActions then
      KC.PortalActions:Hide()
    elseif KC.TeleportButton then
      KC.TeleportButton:Hide()
    end
    if KC.MainFrame and KC.MainFrame.frame then
      KC.MainFrame:Show()
    end
    if KC.KeyList and KC.KeyList.SetView then
      KC.KeyList:SetView("party")
    end
    local voteLabel = self:GetModeLabel(mode)
    KC.Logger:Print(voteLabel .. " opened. Party members can cast votes now.")
    KC.Toasts:Show(voteLabel .. " opened. Cast votes, then resolve it.")
    if KC.PartySync and KC.PartySync.BroadcastVoteOpen then
      KC.PartySync:BroadcastVoteOpen(mode, voteToken)
    end
    if IsInGroup and IsInGroup() then
      SafeSendChatMessage("Keystone Council: " .. string.lower(voteLabel) .. " is open. Cast your vote in the addon, then we'll resolve it.", "PARTY")
    end
    return
  end

  local result

  if mode == "majority" then
    result = KC.MajorityEngine:Pick(keys)
  else
    local weights, reason = self:BuildWeights(mode, keys)
    result = KC.SpinEngine:BuildResult(mode, keys, weights, reason)
  end

  if not result then
    KC.Logger:Print("The Council could not choose a key.")
    return
  end

  if mode == "smart" then
    result.reason = KC.SmartEngine:GetReason(result.winnerKeyID)
  end

  self:ApplyResult(result, true)
end

function KC.Modes:ApplyResult(result, shouldBroadcast)
  result.mode = self:NormalizeMode(result.mode) or result.mode
  result.id = result.id or result.resultID or (tostring(result.mode) .. ":" .. tostring(result.seed) .. ":" .. tostring(result.winnerKeyID))
  local voteToken = KeystoneCouncilDB and KeystoneCouncilDB.session and KeystoneCouncilDB.session.voteToken

  local recorded = KC.SessionStore:RecordSelection(result)
  if not recorded then
    KC.Logger:Debug("Duplicate Council result ignored: " .. tostring(result.id))
    return
  end

  KC.HistoryStore:Record(result)
  KC.StatsStore:Record(result)

  if shouldBroadcast and KC.PartySync then
    KC.PartySync:BroadcastResult(result)
  end

  if self:IsVoteMode(result.mode) and KC.SessionStore then
    if KC.PartySync and KC.PartySync.CancelReliable and voteToken and voteToken ~= "" then
      KC.PartySync:CancelReliable("VOTE_OPEN", voteToken)
    end
    KC.SessionStore:SetVoteOpen(false)
    KC.SessionStore:ClearVotes()
  end

  KC.EventBus:Emit(KC.EVENTS.COUNCIL_RESULT, result)

  if shouldBroadcast then
    self:ScheduleAnnouncements(result)
  elseif KeystoneCouncilDB.profile.announce then
    self:Announce(result)
  end
end

function KC.Modes:ScheduleAnnouncements(result)
  self.announcementToken = (self.announcementToken or 0) + 1
  local token = self.announcementToken
  local delay = KC.Wheel and KC.Wheel.GetRevealDelay and KC.Wheel:GetRevealDelay() or 3.6

  if C_Timer and C_Timer.After then
    C_Timer.After(delay, function()
      if self.announcementToken ~= token then
        return
      end

      KC.Logger:Print(BuildWinnerLine(result))
    end)
  else
    KC.Logger:Print(BuildWinnerLine(result))
  end
end

function KC.Modes:AnnouncePartyWinner(result)
  if not IsInGroup or not IsInGroup() then
    return
  end

  if not KC.Util:IsCurrentPlayerLeader() then
    return
  end

  if KeystoneCouncilDB and KeystoneCouncilDB.profile and KeystoneCouncilDB.profile.announceWinnerToParty == false then
    return
  end

  local requested = KeystoneCouncilDB and KeystoneCouncilDB.profile and KeystoneCouncilDB.profile.announceChannel or "PARTY"
  if KeystoneCouncilDB and KeystoneCouncilDB.profile and KeystoneCouncilDB.profile.announce then
    if requested == "PARTY" then
      return
    end

    if requested == "AUTO" and (not IsInRaid or not IsInRaid()) then
      return
    end
  end

  SafeSendChatMessage(BuildWinnerLine(result), "PARTY")
end

function KC.Modes:ApplyRemoteResult(result)
  local key = KC.KeyStore:Get(result.winnerKeyID)
  if key then
    result.ownerGUID = key.ownerGUID
    result.ownerName = key.ownerName
    result.dungeonID = key.dungeonID
    result.dungeonName = key.dungeonName
    result.level = key.level
  elseif not result.ownerName or not result.dungeonName or not result.level then
    KC.Logger:Debug("Remote Council result references an unknown key: " .. tostring(result.winnerKeyID))
    return
  end
  self:ApplyResult(result, false)
end

function KC.Modes:Announce(result)
  local requested = KeystoneCouncilDB.profile.announceChannel or "PARTY"
  local channel

  if requested == "PARTY" or requested == "RAID" or requested == "SAY" or requested == "GUILD" or requested == "INSTANCE_CHAT" then
    channel = requested
  end

  if requested == "AUTO" then
    if IsInRaid and IsInRaid() then
      channel = "RAID"
    elseif IsInGroup and IsInGroup() then
      channel = "PARTY"
    elseif KeystoneCouncilDB.profile.announceSelf then
      channel = "SAY"
    else
      return
    end
  end

  if channel == "RAID" and (not IsInRaid or not IsInRaid()) then
    channel = IsInGroup and IsInGroup() and "PARTY" or nil
  end

  if channel == "PARTY" and (not IsInGroup or not IsInGroup()) then
    channel = KeystoneCouncilDB.profile.announceSelf and "SAY" or nil
  end

  if channel == "PARTY" and not KC.Util:IsCurrentPlayerLeader() then
    return
  end

  if not channel then
    return
  end

  SafeSendChatMessage(BuildWinnerLine(result), channel)
end

KC:RegisterModule("Modes", KC.Modes)
