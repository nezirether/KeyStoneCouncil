local KC = KeystoneCouncil

KC.SpinEngine = {}

local function RandomSeed()
  local now = time()
  if GetServerTime then
    now = GetServerTime()
  end

  return tonumber(string.sub(tostring(now) .. tostring(math.random(1000, 9999)), -8))
end

local function BuildRNG(seed)
  local value = seed or RandomSeed()
  return function()
    value = (1103515245 * value + 12345) % 2147483648
    return value / 2147483648
  end
end

function KC.SpinEngine:PickWeighted(keys, weights, seed)
  if #keys == 0 then
    return nil
  end

  local total = 0
  for _, key in ipairs(keys) do
    total = total + math.max(0, tonumber(weights[key.id]) or 0)
  end

  if total <= 0 then
    total = #keys
    for _, key in ipairs(keys) do
      weights[key.id] = 1
    end
  end

  local rng = BuildRNG(seed)
  local roll = rng() * total
  local cursor = 0

  for _, key in ipairs(keys) do
    cursor = cursor + math.max(0, tonumber(weights[key.id]) or 0)
    if roll <= cursor then
      return key
    end
  end

  return keys[#keys]
end

function KC.SpinEngine:BuildResult(mode, keys, weights, reason)
  local seed = RandomSeed()
  local winner = self:PickWeighted(keys, weights, seed)
  if not winner then
    return nil
  end

  local resultID = tostring(mode) .. ":" .. tostring(seed) .. ":" .. tostring(winner.id)

  return {
    id = resultID,
    winnerKeyID = winner.id,
    ownerGUID = winner.ownerGUID,
    ownerName = winner.ownerName,
    dungeonID = winner.dungeonID,
    dungeonName = winner.dungeonName,
    level = winner.level,
    mode = mode,
    weights = weights,
    seed = seed,
    reason = reason or "The Council has spoken.",
    timestamp = time(),
  }
end

KC:RegisterModule("SpinEngine", KC.SpinEngine)
