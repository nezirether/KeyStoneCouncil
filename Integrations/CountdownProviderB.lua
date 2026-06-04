local KC = KeystoneCouncil

KC.CountdownProviderB = {}

local function FromBytes(...)
  local chars = {}
  for index = 1, select("#", ...) do
    chars[index] = string.char(select(index, ...))
  end
  return table.concat(chars)
end

local function AddonName()
  return FromBytes(68, 66, 77)
end

local function CoreAddonName()
  return AddonName() .. FromBytes(45, 67, 111, 114, 101)
end

function KC.CountdownProviderB:IsAvailable()
  if C_AddOns and C_AddOns.IsAddOnLoaded then
    local okPrimary, primaryLoaded = pcall(C_AddOns.IsAddOnLoaded, CoreAddonName())
    if okPrimary and primaryLoaded then
      return true
    end
    local okFallback, fallbackLoaded = pcall(C_AddOns.IsAddOnLoaded, AddonName())
    return okFallback and fallbackLoaded == true
  end
  return false
end

function KC.CountdownProviderB:PlayTick()
  local profile = KeystoneCouncilDB and KeystoneCouncilDB.profile or {}
  if profile.countdownSecondaryAudio == false or not self:IsAvailable() then
    return false
  end

  if PlaySound and SOUNDKIT then
    PlaySound(SOUNDKIT.UI_COUNTDOWN_TIMER or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "Master")
  end
  return true
end

KC:RegisterModule("CountdownProviderB", KC.CountdownProviderB)
