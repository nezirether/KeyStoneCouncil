local KC = KeystoneCouncil

KC.MajorityEngine = {}

function KC.MajorityEngine:Pick(keys)
  local counts = {}
  local highest = 0
  local leaders = {}

  for _, key in ipairs(keys) do
    counts[key.id] = 0
  end

  for _, keyID in pairs(KeystoneCouncilDB.session.votes or {}) do
    if counts[keyID] then
      counts[keyID] = counts[keyID] + 1
    end
  end

  for _, key in ipairs(keys) do
    local count = counts[key.id] or 0
    if count > highest then
      highest = count
      leaders = { key }
    elseif count == highest then
      leaders[#leaders + 1] = key
    end
  end

  local weights = {}
  for _, key in ipairs(leaders) do
    weights[key.id] = 1
  end

  return KC.SpinEngine:BuildResult("majority", leaders, weights, highest > 0 and "Most votes wins." or "No votes cast. The Council broke the tie.")
end

KC:RegisterModule("MajorityEngine", KC.MajorityEngine)
