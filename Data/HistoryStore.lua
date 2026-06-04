local KC = KeystoneCouncil

KC.HistoryStore = {}

local function EnsureHistory()
  KeystoneCouncilDB.global.history = KeystoneCouncilDB.global.history or {}
  if type(KeystoneCouncilDB.global.history) ~= "table" then
    KeystoneCouncilDB.global.history = {}
  end
  return KeystoneCouncilDB.global.history
end

function KC.HistoryStore:Record(result)
  local history = EnsureHistory()
  local resultID = result.id or result.resultID

  if resultID then
    for _, item in ipairs(history) do
      if item.id == resultID or item.resultID == resultID then
        return false
      end
    end
  end

  history[#history + 1] = result

  while #history > 100 do
    table.remove(history, 1)
  end

  return true
end

function KC.HistoryStore:GetRecent(limit)
  local history = EnsureHistory()
  local result = {}
  local start = math.max(1, #history - (limit or 10) + 1)

  for index = start, #history do
    result[#result + 1] = history[index]
  end

  return result
end

function KC.HistoryStore:WasRecentlySelected(ownerGUID, dungeonID, ownerName, ownerRealm)
  local recent = self:GetRecent(3)
  local targetName = KC.Util and KC.Util:NormalizePlayerName(KC.Util:BuildFullName(ownerName, ownerRealm) or ownerName)
  for _, item in ipairs(recent) do
    local sameOwner = ownerGUID and ownerGUID ~= "" and item.ownerGUID == ownerGUID
    if not sameOwner and targetName then
      sameOwner = targetName == KC.Util:NormalizePlayerName(KC.Util:BuildFullName(item.ownerName, item.ownerRealm) or item.ownerName)
    end
    local sameDungeon = dungeonID and dungeonID ~= 0 and item.dungeonID == dungeonID
    if sameOwner or sameDungeon then
      return true
    end
  end
  return false
end

KC:RegisterModule("HistoryStore", KC.HistoryStore)
