local KC = KeystoneCouncil

KC.SeasonBest = {
  frame = nil,
  maxRows = 100,
  syncVersion = 1,
}

local function EnsureStore()
  KeystoneCouncilDB.global = KeystoneCouncilDB.global or {}
  if type(KeystoneCouncilDB.global.seasonBest) ~= "table" then
    KeystoneCouncilDB.global.seasonBest = {}
  end
  return KeystoneCouncilDB.global.seasonBest
end

local function EntryID(entry)
  return tostring(entry.dungeonID or entry.dungeonName or "unknown")
end

local function IsBetter(existing, incoming)
  if not existing then
    return true
  end

  local existingLevel = tonumber(existing.level) or 0
  local incomingLevel = tonumber(incoming.level) or 0
  if incomingLevel ~= existingLevel then
    return incomingLevel > existingLevel
  end

  if incoming.timed ~= existing.timed then
    return incoming.timed == true
  end

  return (tonumber(incoming.timestamp) or 0) > (tonumber(existing.timestamp) or 0)
end

function KC.SeasonBest:Normalize(input)
  if type(input) ~= "table" then
    return nil
  end

  local dungeonID = tonumber(input.dungeonID)
  local dungeonName = input.dungeonName
  if dungeonID and (not dungeonName or dungeonName == "") and KC.DungeonRegistry then
    dungeonName = KC.DungeonRegistry:GetName(dungeonID)
  end

  local level = tonumber(input.level or input.keyLevel)
  if not level or level <= 0 or (not dungeonID and (not dungeonName or dungeonName == "")) then
    return nil
  end

  return {
    id = tostring(dungeonID or dungeonName),
    dungeonID = dungeonID,
    dungeonName = dungeonName or tostring(dungeonID),
    level = math.floor(level),
    timestamp = tonumber(input.timestamp) or (time and time() or 0),
    timed = input.timed == true,
    source = input.source or "Manual",
  }
end

function KC.SeasonBest:Record(input)
  local entry = self:Normalize(input)
  if not entry then
    return false
  end

  local store = EnsureStore()
  local id = EntryID(entry)
  if not IsBetter(store[id], entry) then
    return false
  end

  store[id] = entry
  self:Prune()
  self:Refresh()
  return true
end

function KC.SeasonBest:GetAll()
  local rows = {}
  for _, entry in pairs(EnsureStore()) do
    rows[#rows + 1] = entry
  end

  table.sort(rows, function(a, b)
    local aLevel = tonumber(a.level) or 0
    local bLevel = tonumber(b.level) or 0
    if aLevel ~= bLevel then
      return aLevel > bLevel
    end
    return tostring(a.dungeonName or "") < tostring(b.dungeonName or "")
  end)
  return rows
end

function KC.SeasonBest:GetBestForDungeon(dungeonID)
  return EnsureStore()[tostring(dungeonID or "")]
end

function KC.SeasonBest:Prune()
  local rows = self:GetAll()
  if #rows <= (self.maxRows or 100) then
    return 0
  end

  local store = EnsureStore()
  local removed = 0
  for index = (self.maxRows or 100) + 1, #rows do
    store[EntryID(rows[index])] = nil
    removed = removed + 1
  end
  return removed
end

function KC.SeasonBest:GetStatusLine()
  local rows = self:GetAll()
  if #rows == 0 then
    return "Season Best: no completed run data tracked yet"
  end

  local best = rows[1]
  local state = best.timed and "timed" or "depleted"
  return "Season Best: +" .. tostring(best.level) .. " " .. tostring(best.dungeonName or "Unknown") .. " (" .. state .. ")"
end

function KC.SeasonBest:ExportForSync()
  local rows = self:GetAll()
  local result = {}
  for _, row in ipairs(rows) do
    result[#result + 1] = {
      dungeonID = row.dungeonID,
      dungeonName = row.dungeonName,
      level = row.level,
      timestamp = row.timestamp,
      timed = row.timed == true,
      syncVersion = self.syncVersion,
    }
  end
  return result
end

function KC.SeasonBest:ImportFromSync(rows)
  if type(rows) ~= "table" then
    return 0
  end

  local changed = 0
  for _, row in ipairs(rows) do
    if self:Record({
      dungeonID = row.dungeonID,
      dungeonName = row.dungeonName,
      level = row.level,
      timestamp = row.timestamp,
      timed = row.timed == true,
      source = "Sync",
    }) then
      changed = changed + 1
    end
  end
  return changed
end

function KC.SeasonBest:RecordCompletedRun(mapID, level, timed, source)
  mapID = tonumber(mapID)
  level = tonumber(level)
  if not mapID or not level or level <= 0 then
    return false
  end

  return self:Record({
    dungeonID = mapID,
    level = level,
    timed = timed == true,
    timestamp = time and time() or 0,
    source = source or "CompletedRun",
  })
end

function KC.SeasonBest:RecordFromChallengeModeEvent(event, ...)
  if event == "MYTHIC_PLUS_NEW_WEEKLY_RECORD" then
    local mapID, _, level = ...
    return self:RecordCompletedRun(mapID, level, true, "WeeklyRecordEvent")
  end

  if not C_ChallengeMode then
    return false
  end

  local mapID
  if C_ChallengeMode.GetActiveChallengeMapID then
    local ok, activeMapID = pcall(C_ChallengeMode.GetActiveChallengeMapID)
    if ok then
      mapID = activeMapID
    end
  end

  local level
  if C_ChallengeMode.GetActiveKeystoneInfo then
    local ok, activeLevel = pcall(C_ChallengeMode.GetActiveKeystoneInfo)
    if ok then
      level = activeLevel
    end
  end

  return self:RecordCompletedRun(mapID, level, false, tostring(event or "ChallengeModeEvent"))
end

function KC.SeasonBest:Create(parent)
  if self.frame then
    return
  end

  local frame = CreateFrame("Frame", nil, parent)
  frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 18, 94)
  frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -30, 94)
  frame:SetHeight(18)

  frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.text:SetPoint("LEFT")
  frame.text:SetPoint("RIGHT")
  frame.text:SetJustifyH("LEFT")
  frame.text:SetTextColor(0.62, 0.62, 0.66)

  self.frame = frame
  self:Refresh()
end

function KC.SeasonBest:Refresh()
  if self.frame and self.frame.text then
    self.frame.text:SetText(self:GetStatusLine())
  end
end

function KC.SeasonBest:OnEnable()
  KC.EventBus:On(KC.EVENTS.COUNCIL_RESULT, self, function(owner)
    owner:Refresh()
  end)

  if CreateFrame then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    frame:RegisterEvent("CHALLENGE_MODE_COMPLETED_REWARDS")
    frame:RegisterEvent("MYTHIC_PLUS_NEW_WEEKLY_RECORD")
    frame:SetScript("OnEvent", function(_, event, ...)
      self:RecordFromChallengeModeEvent(event, ...)
    end)
    self.eventFrame = frame
  end
end

KC:RegisterModule("SeasonBest", KC.SeasonBest)
