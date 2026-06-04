local KC = KeystoneCouncil

KC.DungeonRegistry = {
  byID = {},
  byName = {}
}

local seasonDungeons = {
  { id = 499, name = "Priory of the Sacred Flame", shortName = "Priory" },
  { id = 500, name = "The Rookery", shortName = "Rookery" },
  { id = 501, name = "The Stonevault", shortName = "Stonevault" },
  { id = 502, name = "City of Threads", shortName = "Threads" },
  { id = 503, name = "Ara-Kara, City of Echoes", shortName = "Ara-Kara" },
  { id = 504, name = "Darkflame Cleft", shortName = "Darkflame" },
  { id = 505, name = "The Dawnbreaker", shortName = "Dawnbreaker" },
  { id = 506, name = "Cinderbrew Meadery", shortName = "Cinderbrew" },
  { id = 507, name = "Grim Batol", shortName = "Grim Batol" },
  { id = 508, name = "Siege of Boralus", shortName = "Siege" },
  { id = 509, name = "Mists of Tirna Scithe", shortName = "Mists" },
  { id = 510, name = "Necrotic Wake", shortName = "Wake" },
  { id = 511, name = "Operation: Floodgate", shortName = "Floodgate" },
  { id = 512, name = "Theater of Pain", shortName = "Theater" },
}

local function BuildShortName(name)
  if not name or name == "" then
    return nil
  end

  local cleaned = tostring(name)
  cleaned = string.gsub(cleaned, ",.*$", "")
  cleaned = string.gsub(cleaned, "^Operation:%s*", "")
  cleaned = string.gsub(cleaned, "^The%s+", "")
  cleaned = string.gsub(cleaned, "^Priory of the ", "")
  cleaned = string.gsub(cleaned, "^City of ", "")
  cleaned = string.gsub(cleaned, "^Siege of ", "")
  cleaned = string.gsub(cleaned, "^Caverns of ", "")
  return cleaned
end

function KC.DungeonRegistry:OnInitialize()
  for _, dungeon in ipairs(seasonDungeons) do
    self.byID[dungeon.id] = dungeon
    self.byName[string.lower(dungeon.name)] = dungeon
    self.byName[string.lower(dungeon.shortName)] = dungeon
  end
end

function KC.DungeonRegistry:GetName(id)
  local existing = self.byID[id]
  if existing and existing.name then
    return existing.name
  end

  local apiName
  if id and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
    apiName = KC.Util:SafeCall("C_ChallengeMode.GetMapUIInfo", C_ChallengeMode.GetMapUIInfo, id)
  end

  if apiName and apiName ~= "" then
    local dungeon = {
      id = id,
      name = apiName,
      shortName = BuildShortName(apiName) or apiName,
    }
    self.byID[id] = dungeon
    self.byName[string.lower(dungeon.name)] = dungeon
    self.byName[string.lower(dungeon.shortName)] = dungeon
    return dungeon.name
  end

  return "Dungeon " .. tostring(id or "?")
end

function KC.DungeonRegistry:GetShortName(id)
  local dungeon = self.byID[id]
  if dungeon and dungeon.shortName then
    return dungeon.shortName
  end

  self:GetName(id)
  dungeon = self.byID[id]
  return dungeon and dungeon.shortName or ("Dungeon " .. tostring(id or "?"))
end

function KC.DungeonRegistry:FindByName(name)
  if not name then
    return nil
  end
  return self.byName[string.lower(name)]
end

KC:RegisterModule("DungeonRegistry", KC.DungeonRegistry)
