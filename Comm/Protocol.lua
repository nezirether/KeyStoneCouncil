local KC = KeystoneCouncil

KC.Protocol = {}

local separator = "\031"
local maxPayloadLength = 900

local function Escape(value)
  value = tostring(value or "")
  value = string.gsub(value, separator, " ")
  return value
end

function KC.Protocol:EncodeKey(key)
  local payload = table.concat({
    "KEY",
    KC.PROTOCOL_VERSION,
    Escape(key.ownerGUID),
    Escape(key.ownerName),
    Escape(key.ownerRealm),
    Escape(key.classFile),
    Escape(key.dungeonID),
    Escape(key.dungeonName),
    Escape(key.level),
    Escape(key.updatedAt),
    Escape(key.score),
    Escape(key.weeklyBest)
  }, separator)

  return string.sub(payload, 1, maxPayloadLength)
end

function KC.Protocol:EncodeLedgerKey(key)
  local payload = table.concat({
    "LEDGER",
    KC.PROTOCOL_VERSION,
    Escape(key.ownerGUID),
    Escape(key.ownerName),
    Escape(key.ownerRealm),
    Escape(key.classFile),
    Escape(key.dungeonID),
    Escape(key.dungeonName),
    Escape(key.level),
    Escape(key.updatedAt or key.lastSeenAt),
    Escape(key.source),
    Escape(key.resetWeek),
    Escape(key.score),
    Escape(key.weeklyBest)
  }, separator)

  return string.sub(payload, 1, maxPayloadLength)
end

function KC.Protocol:EncodeVote(unitName, keyID)
  return string.sub(table.concat({ "VOTE", KC.PROTOCOL_VERSION, Escape(unitName), Escape(keyID) }, separator), 1, maxPayloadLength)
end

function KC.Protocol:EncodeVoteOpen(mode, token)
  return string.sub(table.concat({ "VOTE_OPEN", KC.PROTOCOL_VERSION, Escape(mode), Escape(token), Escape(KC.Util:PlayerFullName()) }, separator), 1, maxPayloadLength)
end

function KC.Protocol:EncodeHello()
  return table.concat({ "HELLO", KC.PROTOCOL_VERSION, Escape(KC.VERSION), Escape(KC.Util:PlayerFullName()) }, separator)
end

function KC.Protocol:EncodeAck(kind, token)
  return table.concat({ "ACK", KC.PROTOCOL_VERSION, Escape(kind), Escape(token), Escape(KC.Util:PlayerFullName()) }, separator)
end

function KC.Protocol:EncodeResult(result)
  local payload = table.concat({
    "RESULT",
    KC.PROTOCOL_VERSION,
    Escape(result.winnerKeyID),
    Escape(result.mode),
    Escape(result.seed),
    Escape(result.reason),
    Escape(result.timestamp),
    Escape(result.ownerName),
    Escape(result.dungeonName),
    Escape(result.level)
  }, separator)

  return string.sub(payload, 1, maxPayloadLength)
end

function KC.Protocol:Decode(payload)
  if not payload or payload == "" or string.len(payload) > maxPayloadLength then
    return nil, nil, "Invalid payload length"
  end

  local parts = {}
  for part in string.gmatch((payload or "") .. separator, "(.-)" .. separator) do
    parts[#parts + 1] = part
  end

  local kind = parts[1]
  local version = parts[2]

  if version ~= KC.PROTOCOL_VERSION then
    return nil, nil, "Unsupported protocol version"
  end

  if kind == "KEY" and #parts >= 10 then
    return kind, {
      ownerGUID = parts[3],
      ownerName = parts[4],
      ownerRealm = parts[5],
      classFile = parts[6],
      dungeonID = tonumber(parts[7]) or 0,
      dungeonName = parts[8],
      level = tonumber(parts[9]) or 0,
      updatedAt = tonumber(parts[10]) or time(),
      score = tonumber(parts[11]),
      weeklyBest = tonumber(parts[12]),
      source = "PartySync",
    }
  end

  if kind == "LEDGER" and #parts >= 12 then
    return kind, {
      ownerGUID = parts[3],
      ownerName = parts[4],
      ownerRealm = parts[5],
      classFile = parts[6],
      dungeonID = tonumber(parts[7]) or 0,
      dungeonName = parts[8],
      level = tonumber(parts[9]) or 0,
      updatedAt = tonumber(parts[10]) or time(),
      originalSource = parts[11],
      resetWeek = parts[12],
      score = tonumber(parts[13]),
      weeklyBest = tonumber(parts[14]),
      source = "PartySyncLedger",
    }
  end

  if kind == "VOTE" and #parts >= 4 then
    return kind, {
      unitName = parts[3],
      keyID = parts[4],
    }
  end

  if kind == "VOTE_OPEN" and #parts >= 5 then
    return kind, {
      mode = parts[3],
      token = parts[4],
      playerName = parts[5],
      source = "PartySync",
    }
  end

  if kind == "HELLO" and #parts >= 4 then
    return kind, {
      addonVersion = parts[3],
      playerName = parts[4],
      source = "PartySync",
    }
  end

  if kind == "ACK" and #parts >= 5 then
    return kind, {
      ackKind = parts[3],
      token = parts[4],
      playerName = parts[5],
      source = "PartySync",
    }
  end

  if kind == "RESULT" and #parts >= 10 then
    return kind, {
      winnerKeyID = parts[3],
      mode = parts[4],
      seed = tonumber(parts[5]) or 0,
      reason = parts[6],
      timestamp = tonumber(parts[7]) or time(),
      ownerName = parts[8],
      dungeonName = parts[9],
      level = tonumber(parts[10]),
      source = "PartySync",
    }
  end

  return nil, nil, "Malformed payload"
end
