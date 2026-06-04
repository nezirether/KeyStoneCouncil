local KC = KeystoneCouncil

KC.ChaosMode = {
  lastResult = nil,
}

local function RandomIndex(count)
  if count <= 0 then
    return nil
  end
  return math.random(1, count)
end

local function AddUniqueMember(rows, seen, name, realm)
  local fullName = KC.Util and KC.Util:BuildFullName(name, realm) or name
  local normalized = KC.Util and KC.Util:NormalizePlayerName(fullName) or tostring(fullName)
  if not fullName or fullName == "" or seen[normalized] then
    return
  end

  seen[normalized] = true
  rows[#rows + 1] = fullName
end

function KC.ChaosMode:GetCandidates()
  local keys
  if KC.Modes and KC.Modes.GetCandidateKeys then
    keys = KC.Modes:GetCandidateKeys()
  end
  keys = keys or (KC.KeyStore and KC.KeyStore:GetByView("party")) or {}

  local result = {}
  for _, key in ipairs(keys) do
    if key and not key.isStale then
      result[#result + 1] = key
    end
  end
  return result
end

function KC.ChaosMode:GetPartyMembers()
  local rows = {}
  local seen = {}

  if UnitName then
    local name, realm = UnitName("player")
    AddUniqueMember(rows, seen, name, realm)
  end

  if IsInRaid and IsInRaid() then
    for index = 1, 40 do
      local name, realm = UnitName("raid" .. tostring(index))
      AddUniqueMember(rows, seen, name, realm)
    end
  else
    for index = 1, 4 do
      local name, realm = UnitName("party" .. tostring(index))
      AddUniqueMember(rows, seen, name, realm)
    end
  end

  return rows
end

function KC.ChaosMode:Shuffle(values)
  local shuffled = {}
  for index, value in ipairs(values or {}) do
    shuffled[index] = value
  end

  for index = #shuffled, 2, -1 do
    local swapIndex = math.random(1, index)
    shuffled[index], shuffled[swapIndex] = shuffled[swapIndex], shuffled[index]
  end
  return shuffled
end

function KC.ChaosMode:AssignRoles(members)
  local shuffled = self:Shuffle(members or {})
  local roles = {
    tank = nil,
    healer = nil,
    dps = {},
  }

  for index, member in ipairs(shuffled) do
    if index == 1 then
      roles.tank = member
    elseif index == 2 then
      roles.healer = member
    else
      roles.dps[#roles.dps + 1] = member
    end
  end

  return roles
end

function KC.ChaosMode:BuildResult()
  local candidates = self:GetCandidates()
  if #candidates == 0 then
    return nil, "No eligible keys are visible for Chaos Mode."
  end

  local members = self:GetPartyMembers()
  if #members == 0 then
    return nil, "No party members are visible for Chaos Mode."
  end

  local key = candidates[RandomIndex(#candidates)]
  return {
    key = key,
    roles = self:AssignRoles(members),
    memberCount = #members,
    timestamp = time and time() or 0,
  }
end

function KC.ChaosMode:GetRoleNote(result)
  local count = tonumber(result and result.memberCount) or 0
  if count < 2 then
    return "solo roll"
  end
  if count < 5 then
    return "short-party roll"
  end
  return "full-party roll"
end

function KC.ChaosMode:FormatResult(result)
  local key = result and result.key or {}
  local roles = result and result.roles or {}
  local dps = #((roles and roles.dps) or {}) > 0 and table.concat(roles.dps, ", ") or "none"

  return "Chaos Mode is optional and just for fun (" .. self:GetRoleNote(result) .. ", info-only roles): " ..
    tostring(key.ownerName or "Unknown") .. "'s +" .. tostring(key.level or "?") .. " " .. tostring(key.dungeonName or "Unknown") ..
    " | Tank: " .. tostring(roles.tank or "none") ..
    " | Healer: " .. tostring(roles.healer or "none") ..
    " | DPS: " .. dps
end

function KC.ChaosMode:GetStatusLine()
  if not self.lastResult then
    return "Chaos Mode: ready, optional and info-only"
  end
  return self:FormatResult(self.lastResult)
end

function KC.ChaosMode:Run()
  local result, errorMessage = self:BuildResult()
  if not result then
    KC.Logger:Print(errorMessage or "Chaos Mode could not run.")
    return false
  end

  self.lastResult = result
  local line = self:FormatResult(result)
  KC.Logger:Print(line)
  if KC.Toasts then
    KC.Toasts:Show("Chaos Mode rolled. Optional and for fun.")
  end
  return true
end

KC:RegisterModule("ChaosMode", KC.ChaosMode)
