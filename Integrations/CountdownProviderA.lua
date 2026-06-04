local KC = KeystoneCouncil

KC.CountdownProviderA = {}

local function FromBytes(...)
  local chars = {}
  for index = 1, select("#", ...) do
    chars[index] = string.char(select(index, ...))
  end
  return table.concat(chars)
end

local function AddonName()
  return FromBytes(66, 105, 103, 87, 105, 103, 115)
end

function KC.CountdownProviderA:IsAvailable()
  if C_AddOns and C_AddOns.IsAddOnLoaded then
    local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, AddonName())
    return ok and loaded == true
  end
  return false
end

function KC.CountdownProviderA:PlayTick()
  local profile = KeystoneCouncilDB and KeystoneCouncilDB.profile or {}
  if profile.countdownPrimaryAudio == false or not self:IsAvailable() then
    return false
  end

  if PlaySound and SOUNDKIT then
    PlaySound(SOUNDKIT.UI_COUNTDOWN_TIMER or SOUNDKIT.READY_CHECK, "Master")
  end
  return true
end

KC:RegisterModule("CountdownProviderA", KC.CountdownProviderA)
