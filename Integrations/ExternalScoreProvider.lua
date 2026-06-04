local KC = KeystoneCouncil

-- Keystone Council 0.9.13
-- External score enrichment is intentionally fail-closed.
-- Previous builds could burn memory/CPU when "Use external scores" was enabled because
-- the provider probing path was too broad. KC already accepts score values from Blizzard,
-- Astral bridge payloads, and its own network payloads, so this module must never scan
-- external addon internals in the background.

KC.ExternalScoreProvider = {
  available = false,
  disabledForSafety = true,
  lastEnrichCount = 0,
  lastLookupCount = 0,
  lastSkipCount = 0,
  lastError = "External score enrichment disabled for safety",
  profileCache = nil,
  maxLookupsPerSession = 0,
}

function KC.ExternalScoreProvider:IsEnabled()
  return false
end

function KC.ExternalScoreProvider:IsLoaded()
  return false
end

function KC.ExternalScoreProvider:RefreshAvailability()
  self.available = false
  self.lastError = "External score enrichment disabled for safety"
  self.profileCache = nil
  return false
end

function KC.ExternalScoreProvider:EnrichKey(input)
  self.lastSkipCount = (self.lastSkipCount or 0) + 1
  return input
end

function KC.ExternalScoreProvider:OnEnable()
  self.available = false
  self.profileCache = nil
  self.lastLookupCount = 0
  self.lastSkipCount = 0
  self.lastEnrichCount = 0
  self.lastError = "External score enrichment disabled for safety"
end

function KC.ExternalScoreProvider:GetStatusLine()
  return "External score provider: disabled for safety"
end

KC:RegisterModule("ExternalScoreProvider", KC.ExternalScoreProvider)
