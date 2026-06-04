local KC = KeystoneCouncil

KC.Diagnostics = {}

local function Bool(value)
  return value and "yes" or "no"
end

local function RoundKB(value)
  value = tonumber(value)
  if not value then
    return nil
  end
  return tostring(math.floor(value + 0.5)) .. " KB"
end

local function GetAddonMemoryKB()
  if UpdateAddOnMemoryUsage then
    pcall(UpdateAddOnMemoryUsage)
  end

  if not GetAddOnMemoryUsage then
    return nil
  end

  local ok, memory = pcall(GetAddOnMemoryUsage, KC.ADDON_NAME)
  if ok and tonumber(memory) then
    return tonumber(memory)
  end

  local count
  if C_AddOns and C_AddOns.GetNumAddOns then
    ok, count = pcall(C_AddOns.GetNumAddOns)
  elseif _G["GetNumAddOns"] then
    ok, count = pcall(_G["GetNumAddOns"])
  end

  if not ok or not count then
    return nil
  end

  for index = 1, count do
    local name
    if C_AddOns and C_AddOns.GetAddOnInfo then
      ok, name = pcall(C_AddOns.GetAddOnInfo, index)
    elseif _G["GetAddOnInfo"] then
      ok, name = pcall(_G["GetAddOnInfo"], index)
    end

    if ok and name == KC.ADDON_NAME then
      ok, memory = pcall(GetAddOnMemoryUsage, index)
      if ok and tonumber(memory) then
        return tonumber(memory)
      end
    end
  end

  return nil
end

local function CountRows(provider, methodName)
  if provider and provider[methodName] then
    local ok, rows = pcall(provider[methodName], provider)
    if ok and type(rows) == "table" then
      return #rows
    end
  end
  return 0
end

local function CountCandidateKeys()
  if KC.Modes and KC.Modes.GetCandidateKeys then
    local ok, rows = pcall(KC.Modes.GetCandidateKeys, KC.Modes)
    if ok and type(rows) == "table" then
      return #rows
    end
  end
  return 0
end

local function AddReadinessRow(rows, status, label, detail)
  rows[#rows + 1] = {
    status = status,
    label = label,
    detail = detail,
  }
end

local function HasTable(value)
  return type(value) == "table"
end

local function HasFunction(value, methodName)
  return type(value) == "table" and type(value[methodName]) == "function"
end

local function CountModuleIssues()
  local rows = KC.GetModuleStatusRows and KC:GetModuleStatusRows() or {}
  local failures = 0
  local warnings = 0

  for _, row in ipairs(rows) do
    if row.status == "error" then
      failures = failures + 1
    elseif row.status ~= "enabled" then
      warnings = warnings + 1
    end
  end

  return #rows, failures, warnings
end

function KC.Diagnostics:GetReadinessRows()
  local rows = {}
  local db = KeystoneCouncilDB or {}
  local profile = db.profile or {}
  local options = profile.options or {}
  local session = db.session or {}

  if KC.VERSION and KC.PROTOCOL_VERSION then
    AddReadinessRow(rows, "PASS", "Version", "KSC " .. tostring(KC.VERSION) .. ", protocol " .. tostring(KC.PROTOCOL_VERSION))
  else
    AddReadinessRow(rows, "FAIL", "Version", "Missing version or protocol metadata.")
  end

  if HasTable(db) and HasTable(profile) and HasTable(db.global) and HasTable(session) then
    local expectedVersion = KC.Defaults and KC.Defaults.profileVersion
    local actualVersion = db.profileVersion
    if expectedVersion and actualVersion ~= expectedVersion then
      AddReadinessRow(rows, "WARN", "Saved data", "Profile schema is " .. tostring(actualVersion) .. "; expected " .. tostring(expectedVersion) .. ". A reload may finish migration.")
    else
      AddReadinessRow(rows, "PASS", "Saved data", "Profile, global, and session tables are available.")
    end
  else
    AddReadinessRow(rows, "FAIL", "Saved data", "SavedVariables tables are missing or damaged.")
  end

  local moduleCount, moduleFailures, moduleWarnings = CountModuleIssues()
  if moduleFailures > 0 then
    AddReadinessRow(rows, "FAIL", "Modules", tostring(moduleFailures) .. " module error(s), " .. tostring(moduleWarnings) .. " warning(s), " .. tostring(moduleCount) .. " total.")
  elseif moduleWarnings > 0 then
    AddReadinessRow(rows, "WARN", "Modules", tostring(moduleWarnings) .. " module(s) not fully enabled, " .. tostring(moduleCount) .. " total.")
  else
    AddReadinessRow(rows, "PASS", "Modules", tostring(moduleCount) .. " modules enabled.")
  end

  if HasFunction(KC.KeyStore, "GetAll") and HasFunction(KC.KeyStore, "SetSortMode") then
    local keyCount = #(KC.KeyStore:GetAll() or {})
    if keyCount > 0 then
      AddReadinessRow(rows, "PASS", "Key table", tostring(keyCount) .. " visible key row(s).")
    else
      AddReadinessRow(rows, "WARN", "Key table", "No visible keys yet. Run /kc refresh or join a party with visible keys.")
    end
  else
    AddReadinessRow(rows, "FAIL", "Key table", "Key storage module is unavailable.")
  end

  if HasFunction(KC.KeyLedger, "GetAuditSummary") then
    local summary = KC.KeyLedger:GetAuditSummary()
    AddReadinessRow(rows, "PASS", "Key ledger", tostring(summary.total or 0) .. " stored row(s), " .. tostring(summary.stale or 0) .. " stale.")
  else
    AddReadinessRow(rows, "FAIL", "Key ledger", "Persistent key ledger is unavailable.")
  end

  if C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel then
    AddReadinessRow(rows, "PASS", "Local key API", "Blizzard keystone API is available.")
  else
    AddReadinessRow(rows, "WARN", "Local key API", "WoW has not exposed local keystone data yet.")
  end

  if KC.PartySync and KC.PartySync.prefixRegistered then
    AddReadinessRow(rows, "PASS", "Party sync", "Message prefix registered; peers " .. tostring(KC.PartySync:GetPeerCount()) .. ".")
  elseif KC.PartySync then
    AddReadinessRow(rows, "WARN", "Party sync", "Sync module loaded, but prefix registration is not confirmed yet.")
  else
    AddReadinessRow(rows, "FAIL", "Party sync", "Party sync module is unavailable.")
  end

  if HasFunction(KC.Modes, "NormalizeMode") and KC.SpinEngine and KC.VoteEngine and KC.MajorityEngine and KC.SmartEngine then
    AddReadinessRow(rows, "PASS", "Decision modes", "Spin, Raffle, Majority, and Smart are available.")
  else
    AddReadinessRow(rows, "FAIL", "Decision modes", "One or more decision engines are unavailable.")
  end

  if HasTable(session.votes) and HasTable(session.selections) and HasTable(session.closedVoteTokens) then
    AddReadinessRow(rows, "PASS", "Vote session", "Vote tables are initialized.")
  else
    AddReadinessRow(rows, "FAIL", "Vote session", "Vote session tables are missing.")
  end

  if KC.KeyReporter and KC.KeyReporter.frame then
    AddReadinessRow(rows, "PASS", "Chat reporting", "!key and !keys listeners are registered.")
  elseif KC.KeyReporter then
    AddReadinessRow(rows, "WARN", "Chat reporting", "Reporter module loaded, but chat events are not confirmed.")
  else
    AddReadinessRow(rows, "FAIL", "Chat reporting", "Reporter module is unavailable.")
  end

  if HasFunction(KC.SeasonBest, "GetStatusLine") then
    AddReadinessRow(rows, "PASS", "Season best", KC.SeasonBest:GetStatusLine())
  else
    AddReadinessRow(rows, "WARN", "Season best", "Season best framework is unavailable.")
  end

  if HasFunction(KC.PortalActions, "GetStatusLine") then
    AddReadinessRow(rows, "PASS", "Portal action", KC.PortalActions:GetStatusLine())
  else
    AddReadinessRow(rows, "WARN", "Portal action", "Portal action framework is unavailable.")
  end

  if HasFunction(KC.ChaosMode, "GetStatusLine") then
    AddReadinessRow(rows, "PASS", "Chaos Mode", KC.ChaosMode:GetStatusLine())
  else
    AddReadinessRow(rows, "WARN", "Chaos Mode", "Chaos Mode is unavailable.")
  end

  if KC.MainFrame and KC.KeyList and KC.VotePanel and KC.Settings then
    AddReadinessRow(rows, "PASS", "UI", "Main frame, key list, vote panel, and settings are available.")
  else
    AddReadinessRow(rows, "FAIL", "UI", "One or more required UI modules are unavailable.")
  end

  if not KC.ExternalScoreProvider then
    AddReadinessRow(rows, "WARN", "External scores", "External score provider module is unavailable.")
  elseif options.useExternalScores ~= true then
    AddReadinessRow(rows, "PASS", "External scores", "Optional score enrichment is off.")
  elseif KC.ExternalScoreProvider.RefreshAvailability and KC.ExternalScoreProvider:RefreshAvailability() then
    AddReadinessRow(rows, "PASS", "External scores", KC.ExternalScoreProvider:GetStatusLine())
  else
    AddReadinessRow(rows, "WARN", "External scores", "Score enrichment is on, but no compatible score provider is loaded.")
  end

  if InCombatLockdown and InCombatLockdown() then
    AddReadinessRow(rows, "WARN", "Combat lockdown", "In combat. Secure button updates may be deferred.")
  else
    AddReadinessRow(rows, "PASS", "Combat lockdown", "Not in combat.")
  end

  return rows
end

function KC.Diagnostics:GetReadinessSummary(rows)
  local summary = {
    PASS = 0,
    WARN = 0,
    FAIL = 0,
  }

  for _, row in ipairs(rows or {}) do
    summary[row.status] = (summary[row.status] or 0) + 1
  end

  return summary
end

function KC.Diagnostics:PrintReadiness()
  local rows = self:GetReadinessRows()
  local summary = self:GetReadinessSummary(rows)

  KC.Logger:Print("Readiness: " .. tostring(summary.PASS or 0) .. " pass, " .. tostring(summary.WARN or 0) .. " warn, " .. tostring(summary.FAIL or 0) .. " fail.")
  for _, row in ipairs(rows) do
    KC.Logger:Print(tostring(row.status) .. " - " .. tostring(row.label) .. ": " .. tostring(row.detail))
  end

  if (summary.FAIL or 0) > 0 then
    KC.Logger:Print("Fix FAIL rows before beta testing.")
  elseif (summary.WARN or 0) > 0 then
    KC.Logger:Print("WARN rows may be normal while solo, unguilded, or before keys are visible.")
  else
    KC.Logger:Print("Ready for live smoke testing.")
  end
end

local function GetGuildRosterCount()
  if GetNumGuildMembers then
    local ok, count = pcall(GetNumGuildMembers)
    if ok and tonumber(count) then
      return tonumber(count)
    end
  end
  return 0
end

local function GetGuildOnlineCount()
  local total = GetGuildRosterCount()
  local onlineCount = 0
  if not GetGuildRosterInfo then
    return 0
  end

  for index = 1, total do
    local ok, _, _, _, _, _, _, _, _, online = pcall(GetGuildRosterInfo, index)
    if ok and online ~= false then
      onlineCount = onlineCount + 1
    end
  end

  return onlineCount
end

function KC.Diagnostics:GetGuildValidation()
  local summary = KC.KeyLedger and KC.KeyLedger.GetAuditSummary and KC.KeyLedger:GetAuditSummary() or {}
  return {
    rosterCount = GetGuildRosterCount(),
    onlineCount = GetGuildOnlineCount(),
    guildKeys = tonumber(summary.guild) or 0,
    partyKeys = tonumber(summary.party) or 0,
    friendKeys = tonumber(summary.friends) or 0,
    otherKeys = tonumber(summary.other) or 0,
    duplicateDisplayOwners = tonumber(summary.duplicateDisplayOwners) or 0,
    realmVariants = tonumber(summary.realmVariants) or 0,
    sourceCounts = summary.sources or {},
  }
end

function KC.Diagnostics:GetResetValidation()
  local summary = KC.KeyLedger and KC.KeyLedger.GetAuditSummary and KC.KeyLedger:GetAuditSummary() or {}
  return {
    currentWeek = tostring(summary.currentWeek or "unknown"),
    total = tonumber(summary.total) or 0,
    stale = tonumber(summary.stale) or 0,
    active = math.max(0, (tonumber(summary.total) or 0) - (tonumber(summary.stale) or 0)),
  }
end

function KC.Diagnostics:PrintGuildValidation()
  local guild = self:GetGuildValidation()
  KC.Logger:Print("Guild validation: roster " .. tostring(guild.rosterCount) .. ", online " .. tostring(guild.onlineCount) .. ", guild keys " .. tostring(guild.guildKeys) .. ", party keys " .. tostring(guild.partyKeys) .. ", friend keys " .. tostring(guild.friendKeys) .. ", other keys " .. tostring(guild.otherKeys))
  KC.Logger:Print("Owner audit: duplicate display names " .. tostring(guild.duplicateDisplayOwners) .. ", realm variants " .. tostring(guild.realmVariants))
  for source, count in pairs(guild.sourceCounts) do
    KC.Logger:Print("Source " .. tostring(source) .. ": " .. tostring(count))
  end
end

function KC.Diagnostics:PrintResetValidation()
  local reset = self:GetResetValidation()
  KC.Logger:Print("Weekly reset validation: current week " .. tostring(reset.currentWeek) .. ", active " .. tostring(reset.active) .. ", stale " .. tostring(reset.stale) .. ", total " .. tostring(reset.total))
  if reset.stale > 0 then
    KC.Logger:Print("Run /kc cleanup after confirming stale rows are old or duplicate.")
  end
end

function KC.Diagnostics:GetPerformanceSnapshot()
  local addonMemory = GetAddonMemoryKB()
  local totalMemory
  if collectgarbage then
    local ok, value = pcall(collectgarbage, "count")
    if ok and tonumber(value) then
      totalMemory = tonumber(value)
    end
  end

  local keys = KC.KeyStore and KC.KeyStore:GetAll() or {}
  local ledgerRows = KC.KeyLedger and KC.KeyLedger.GetAll and KC.KeyLedger:GetAll() or {}
  local staleLedger = 0
  for _, entry in ipairs(ledgerRows) do
    if entry.isStale then
      staleLedger = staleLedger + 1
    end
  end

  return {
    version = KC.VERSION,
    addonMemoryKB = addonMemory,
    totalMemoryKB = totalMemory,
    keyCount = #keys,
    ledgerCount = #ledgerRows,
    staleLedgerCount = staleLedger,
    peerCount = KC.PartySync and KC.PartySync.GetPeerCount and KC.PartySync:GetPeerCount() or 0,
    pendingSyncCount = CountRows(KC.PartySync, "GetPendingRows"),
    ackRowCount = CountRows(KC.PartySync, "GetAckRows"),
    failedSyncCount = CountRows(KC.PartySync, "GetFailedRows"),
    candidateCount = CountCandidateKeys(),
    externalScoreLoaded = KC.ExternalScoreProvider and KC.ExternalScoreProvider.available == true,
    externalScoreEnabled = KC.ExternalScoreProvider and KC.ExternalScoreProvider.IsEnabled and KC.ExternalScoreProvider:IsEnabled() == true,
    externalScoreLookups = KC.ExternalScoreProvider and KC.ExternalScoreProvider.lastLookupCount or 0,
    externalScoreSkipped = KC.ExternalScoreProvider and KC.ExternalScoreProvider.lastSkipCount or 0,
    timestamp = time and time() or 0,
  }
end

function KC.Diagnostics:PrintPerformanceSnapshot()
  local snapshot = self:GetPerformanceSnapshot()
  KC.Logger:Print("Performance snapshot: v" .. tostring(snapshot.version))
  KC.Logger:Print("KSC addon memory: " .. tostring(RoundKB(snapshot.addonMemoryKB) or "unavailable"))
  KC.Logger:Print("Total UI Lua memory: " .. tostring(RoundKB(snapshot.totalMemoryKB) or "unavailable"))
  KC.Logger:Print("Memory note: total UI Lua memory includes every addon, not just KSC.")
  KC.Logger:Print("Keys: visible " .. tostring(snapshot.keyCount) .. ", ledger " .. tostring(snapshot.ledgerCount) .. ", stale " .. tostring(snapshot.staleLedgerCount))
  KC.Logger:Print("Candidates: " .. tostring(snapshot.candidateCount))
  KC.Logger:Print("PartySync: peers " .. tostring(snapshot.peerCount) .. ", pending " .. tostring(snapshot.pendingSyncCount) .. ", failed " .. tostring(snapshot.failedSyncCount) .. ", ACK rows " .. tostring(snapshot.ackRowCount))
  KC.Logger:Print("External score provider: loaded " .. Bool(snapshot.externalScoreLoaded) .. ", KSC enrichment " .. Bool(snapshot.externalScoreEnabled) .. ", lookups " .. tostring(snapshot.externalScoreLookups) .. ", skipped " .. tostring(snapshot.externalScoreSkipped))
  self:PrintResetValidation()
end

function KC.Diagnostics:BuildReport()
  local keys = KC.KeyStore and KC.KeyStore:GetAll() or {}
  local guild = self:GetGuildValidation()
  local reset = self:GetResetValidation()
  local votes = KeystoneCouncilDB and KeystoneCouncilDB.session and KeystoneCouncilDB.session.votes or {}
  local voteCount = 0
  for _ in pairs(votes) do
    voteCount = voteCount + 1
  end

  local report = {
    "Keystone Council " .. tostring(KC.VERSION),
    "Mode: " .. tostring(KC.Modes and KC.Modes.GetModeLabel and KC.Modes:GetModeLabel() or (KC.Modes and KC.Modes:GetMode() or "unknown")),
    "Vote session: open " .. Bool(KeystoneCouncilDB and KeystoneCouncilDB.session and KeystoneCouncilDB.session.voteOpen == true) .. ", mode " .. tostring(KeystoneCouncilDB and KeystoneCouncilDB.session and KeystoneCouncilDB.session.voteMode or "") .. ", token " .. tostring(KeystoneCouncilDB and KeystoneCouncilDB.session and KeystoneCouncilDB.session.voteToken or ""),
    "Sort: " .. tostring(KC.KeyStore and KC.KeyStore.GetSortMode and KC.KeyStore:GetSortMode() or "level"),
    "Keys: " .. tostring(#keys),
    "Votes: " .. tostring(voteCount),
    "Guild validation: roster " .. tostring(guild.rosterCount) .. ", online " .. tostring(guild.onlineCount) .. ", guild keys " .. tostring(guild.guildKeys) .. ", party keys " .. tostring(guild.partyKeys) .. ", friend keys " .. tostring(guild.friendKeys) .. ", other keys " .. tostring(guild.otherKeys),
    "Owner audit: duplicate display names " .. tostring(guild.duplicateDisplayOwners) .. ", realm variants " .. tostring(guild.realmVariants),
    "Weekly reset: week " .. tostring(reset.currentWeek) .. ", active " .. tostring(reset.active) .. ", stale " .. tostring(reset.stale),
    KC.ExternalKeyProvider and KC.ExternalKeyProvider.GetStatusLine and KC.ExternalKeyProvider:GetStatusLine() or "External key provider: unavailable",
    KC.AstralBridge and KC.AstralBridge.GetStatusLine and KC.AstralBridge:GetStatusLine() or "Astral bridge: unavailable",
    KC.KeyNetwork and KC.KeyNetwork.GetStatusLine and KC.KeyNetwork:GetStatusLine() or "KC guild network: unavailable",
    KC.ExternalScoreProvider and KC.ExternalScoreProvider.GetStatusLine and KC.ExternalScoreProvider:GetStatusLine() or "External score provider: unavailable",
    KC.SharedKeyProvider and KC.SharedKeyProvider.GetStatusLine and KC.SharedKeyProvider:GetStatusLine() or "Shared key provider: unavailable",
    KC.GroupKeyProvider and KC.GroupKeyProvider.GetStatusLine and KC.GroupKeyProvider:GetStatusLine() or "Group key provider: unavailable",
    KC.PartySync and KC.PartySync.GetStatusLine and KC.PartySync:GetStatusLine() or "PartySync: unavailable",
    KC.KeyLedger and KC.KeyLedger.GetStatusLine and KC.KeyLedger:GetStatusLine() or "Key ledger: unavailable",
    KC.SeasonBest and KC.SeasonBest.GetStatusLine and KC.SeasonBest:GetStatusLine() or "Season Best: unavailable",
    KC.PortalActions and KC.PortalActions.GetStatusLine and KC.PortalActions:GetStatusLine() or "Portal Action: unavailable",
    KC.ChaosMode and KC.ChaosMode.GetStatusLine and KC.ChaosMode:GetStatusLine() or "Chaos Mode: unavailable",
    "Primary countdown provider: " .. Bool(KC.CountdownProviderA and KC.CountdownProviderA:IsAvailable()),
    "Secondary countdown provider: " .. Bool(KC.CountdownProviderB and KC.CountdownProviderB:IsAvailable()),
    "Group: " .. Bool(IsInGroup and IsInGroup()),
    "Raid: " .. Bool(IsInRaid and IsInRaid()),
    "Player: " .. tostring(KC.Util and KC.Util:PlayerFullName() or UnitName("player")),
    "Party winner post: " .. Bool(KeystoneCouncilDB and KeystoneCouncilDB.profile and KeystoneCouncilDB.profile.announceWinnerToParty ~= false),
    "Friend sync: " .. Bool(KeystoneCouncilDB and KeystoneCouncilDB.profile and KeystoneCouncilDB.profile.options and KeystoneCouncilDB.profile.options.syncFriends ~= false),
    "Minimap button: " .. Bool(KeystoneCouncilDB and KeystoneCouncilDB.profile and KeystoneCouncilDB.profile.options and KeystoneCouncilDB.profile.options.showMinimapButton ~= false),
  }

  if KC.refreshStatus and #KC.refreshStatus > 0 then
    report[#report + 1] = "Last refresh:"
    for _, line in ipairs(KC.refreshStatus) do
      report[#report + 1] = " - " .. line
    end
  end

  if KC.PartySync and KC.PartySync.GetPeerRows then
    local peers = KC.PartySync:GetPeerRows()
    if #peers > 0 then
      report[#report + 1] = "PartySync peers:"
      for _, peer in ipairs(peers) do
        local status = peer.versionMismatch and "version mismatch" or "ok"
        report[#report + 1] = " - " .. tostring(peer.name) .. " | " .. tostring(peer.addonVersion) .. " | protocol " .. tostring(peer.protocolVersion) .. " | " .. status
      end
    end
  end

  if KC.PartySync and KC.PartySync.GetTrafficRows then
    local trafficRows = KC.PartySync:GetTrafficRows()
    if #trafficRows > 0 then
      report[#report + 1] = "PartySync traffic:"
      for _, row in ipairs(trafficRows) do
        report[#report + 1] = " - " .. tostring(row.kind) .. " sent " .. tostring(row.sent) .. ", received " .. tostring(row.received)
      end
    end
  end

  if KC.ExternalKeyProvider and KC.ExternalKeyProvider.GetProbeLines then
    local probeLines = KC.ExternalKeyProvider:GetProbeLines()
    if #probeLines > 0 then
      report[#report + 1] = "External key provider probes:"
      for _, line in ipairs(probeLines) do
        report[#report + 1] = " - " .. tostring(line)
      end
    end
  end

  return report
end

function KC.Diagnostics:PrintModuleStatus()
  local rows = KC.GetModuleStatusRows and KC:GetModuleStatusRows() or {}
  KC.Logger:Print("Module health: " .. tostring(#rows) .. " modules")
  for _, row in ipairs(rows) do
    KC.Logger:Print(tostring(row.name) .. ": " .. tostring(row.status))
  end
end

function KC.Diagnostics:Print()
  for _, line in ipairs(self:BuildReport()) do
    KC.Logger:Print(line)
  end
end

function KC.Diagnostics:PrintStatus()
  local config = KeystoneCouncilDB and KeystoneCouncilDB.profile and KeystoneCouncilDB.profile.keyReporting or {}
  local currentKey = KC.Util and KC.Util:GetOwnedKey() or nil
  local keyLine = currentKey and KC.Util:FormatKeystoneLink(currentKey) or "none"
  local moduleCount = KC.moduleOrder and #KC.moduleOrder or 0
  local ledgerLine = KC.KeyLedger and KC.KeyLedger:GetStatusLine() or "Key ledger: unavailable"

  KC.Logger:Print("Status: loaded, v" .. tostring(KC.VERSION))
  KC.Logger:Print("Modules loaded: " .. tostring(moduleCount))
  local addonMemory = GetAddonMemoryKB()
  if addonMemory then
    KC.Logger:Print("Addon memory: " .. RoundKB(addonMemory))
  end
  if collectgarbage then
    local ok, totalMemoryKB = pcall(collectgarbage, "count")
    if ok and totalMemoryKB then
      KC.Logger:Print("Total UI Lua memory: " .. RoundKB(totalMemoryKB))
    end
  end
  KC.Logger:Print("Memory note: addon memory is KSC only; total UI Lua memory includes every loaded addon.")
  KC.Logger:Print("Current key: " .. tostring(keyLine))
  KC.Logger:Print(ledgerLine)
  KC.Logger:Print("Key sort: " .. tostring(KC.KeyStore and KC.KeyStore.GetSortMode and KC.KeyStore:GetSortMode() or "level"))
  KC.Logger:Print("Chat listeners: say " .. Bool(config.respondSay ~= false) .. ", guild " .. Bool(config.respondGuild ~= false) .. ", party " .. Bool(config.respondParty ~= false) .. ", raid " .. Bool(config.respondRaid ~= false) .. ", instance " .. Bool(config.respondInstance ~= false))
  KC.Logger:Print("New-key posts: guild " .. Bool(config.announceNewKeyGuild ~= false) .. ", party " .. Bool(config.announceNewKeyParty ~= false))
  KC.Logger:Print(KC.ExternalKeyProvider and KC.ExternalKeyProvider.GetStatusLine and KC.ExternalKeyProvider:GetStatusLine() or "External key provider: unavailable")
  KC.Logger:Print(KC.AstralBridge and KC.AstralBridge.GetStatusLine and KC.AstralBridge:GetStatusLine() or "Astral bridge: unavailable")
  KC.Logger:Print(KC.KeyNetwork and KC.KeyNetwork.GetStatusLine and KC.KeyNetwork:GetStatusLine() or "KC guild network: unavailable")
  KC.Logger:Print(KC.ExternalScoreProvider and KC.ExternalScoreProvider.GetStatusLine and KC.ExternalScoreProvider:GetStatusLine() or "External score provider: unavailable")
  KC.Logger:Print(KC.SharedKeyProvider and KC.SharedKeyProvider.GetStatusLine and KC.SharedKeyProvider:GetStatusLine() or "Shared key provider: unavailable")
  KC.Logger:Print(KC.GroupKeyProvider and KC.GroupKeyProvider.GetStatusLine and KC.GroupKeyProvider:GetStatusLine() or "Group key provider: unavailable")
  KC.Logger:Print(KC.PartySync and KC.PartySync.GetStatusLine and KC.PartySync:GetStatusLine() or "PartySync: unavailable")
  KC.Logger:Print(KC.SeasonBest and KC.SeasonBest.GetStatusLine and KC.SeasonBest:GetStatusLine() or "Season Best: unavailable")
  KC.Logger:Print(KC.PortalActions and KC.PortalActions.GetStatusLine and KC.PortalActions:GetStatusLine() or "Portal Action: unavailable")
  KC.Logger:Print(KC.ChaosMode and KC.ChaosMode.GetStatusLine and KC.ChaosMode:GetStatusLine() or "Chaos Mode: unavailable")
  self:PrintGuildValidation()
  self:PrintPerformanceSnapshot()
end

function KC.Diagnostics:Validate()
  local issues = {}

  if not KC.KeyStore then
    issues[#issues + 1] = "KeyStore missing"
  end

  if not KC.Modes then
    issues[#issues + 1] = "Modes missing"
  end

  if not C_ChatInfo then
    issues[#issues + 1] = "C_ChatInfo unavailable"
  end

  if KC.KeyStore and KC.KeyStore.GetSortMode then
    local sortMode = KC.KeyStore:GetSortMode()
    if sortMode == "level" and KeystoneCouncilDB and KeystoneCouncilDB.profile and KeystoneCouncilDB.profile.options and KeystoneCouncilDB.profile.options.keySortMode ~= "level" then
      issues[#issues + 1] = "Invalid key sort mode was reset to level"
    end
  end

  if KC.KeyLedger and KC.KeyLedger.GetAuditSummary then
    local summary = KC.KeyLedger:GetAuditSummary()
    if summary.total and KC.KeyLedger.maxRows and summary.total > KC.KeyLedger.maxRows then
      issues[#issues + 1] = "Key ledger exceeds configured row cap"
    end
  end

  if #issues == 0 then
    KC.Logger:Print("Diagnostics passed.")
  else
    for _, issue in ipairs(issues) do
      KC.Logger:Error(issue)
    end
  end
end

function KC.Diagnostics:Export()
  local lines = self:BuildReport()
  lines[#lines + 1] = "Files: " .. tostring(#(KC.FileManifest or {}))
  if self.GetReadinessRows and self.GetReadinessSummary then
    local readinessRows = self:GetReadinessRows()
    local readinessSummary = self:GetReadinessSummary(readinessRows)
    lines[#lines + 1] = "Readiness: " .. tostring(readinessSummary.PASS or 0) .. " pass, " .. tostring(readinessSummary.WARN or 0) .. " warn, " .. tostring(readinessSummary.FAIL or 0) .. " fail"
    for _, row in ipairs(readinessRows) do
      lines[#lines + 1] = " - " .. tostring(row.status) .. " | " .. tostring(row.label) .. " | " .. tostring(row.detail)
    end
  end

  if KC.CandidateInspector and KC.CandidateInspector.BuildRows then
    local rows = KC.CandidateInspector:BuildRows()
    lines[#lines + 1] = "Candidates: " .. tostring(#rows)
    for _, row in ipairs(rows) do
      lines[#lines + 1] = tostring(row.owner) .. " +" .. tostring(row.level) .. " " .. tostring(row.dungeon) .. " | " .. tostring(row.source) .. " | " .. tostring(row.bucket) .. " | " .. tostring(row.reason)
    end
  end

  if KC.PartySync and KC.PartySync.GetAckRows then
    local rows = KC.PartySync:GetAckRows()
    lines[#lines + 1] = "ACKs: " .. tostring(#rows)
    for _, row in ipairs(rows) do
      lines[#lines + 1] = tostring(row.token) .. " | " .. tostring(row.count)
    end
  end

  if KC.PartySync and KC.PartySync.GetPendingRows then
    local rows = KC.PartySync:GetPendingRows()
    lines[#lines + 1] = "Pending sync: " .. tostring(#rows)
    for _, row in ipairs(rows) do
      lines[#lines + 1] = tostring(row.id) .. " | " .. tostring(row.status) .. " | attempts " .. tostring(row.attempts) .. " | ack " .. tostring(row.ackCount) .. "/" .. tostring(row.expectedAckCount)
    end
  end

  if KC.PartySync and KC.PartySync.GetFailedRows then
    local rows = KC.PartySync:GetFailedRows()
    lines[#lines + 1] = "Failed sync: " .. tostring(#rows)
    for _, row in ipairs(rows) do
      lines[#lines + 1] = tostring(row.id) .. " | attempts " .. tostring(row.attempts) .. " | ack " .. tostring(row.ackCount) .. "/" .. tostring(row.expectedAckCount)
    end
  end

  if KC.GetModuleStatusRows then
    local rows = KC:GetModuleStatusRows()
    lines[#lines + 1] = "Modules: " .. tostring(#rows)
    for _, row in ipairs(rows) do
      lines[#lines + 1] = tostring(row.name) .. " | " .. tostring(row.status)
    end
  end

  if self.GetPerformanceSnapshot then
    local snapshot = self:GetPerformanceSnapshot()
    lines[#lines + 1] = "Performance:"
    lines[#lines + 1] = " - KSC addon memory: " .. tostring(RoundKB(snapshot.addonMemoryKB) or "unavailable")
    lines[#lines + 1] = " - Total UI Lua memory: " .. tostring(RoundKB(snapshot.totalMemoryKB) or "unavailable")
    lines[#lines + 1] = " - Keys: visible " .. tostring(snapshot.keyCount) .. ", ledger " .. tostring(snapshot.ledgerCount) .. ", stale " .. tostring(snapshot.staleLedgerCount)
    lines[#lines + 1] = " - Candidates: " .. tostring(snapshot.candidateCount)
    lines[#lines + 1] = " - PartySync: peers " .. tostring(snapshot.peerCount) .. ", pending " .. tostring(snapshot.pendingSyncCount) .. ", failed " .. tostring(snapshot.failedSyncCount) .. ", ACK rows " .. tostring(snapshot.ackRowCount)
    lines[#lines + 1] = " - External score provider: loaded " .. Bool(snapshot.externalScoreLoaded) .. ", KSC enrichment " .. Bool(snapshot.externalScoreEnabled) .. ", lookups " .. tostring(snapshot.externalScoreLookups) .. ", skipped " .. tostring(snapshot.externalScoreSkipped)
  end

  KC.Logger:Print("Diagnostic export:")
  for _, line in ipairs(lines) do
    KC.Logger:Print(line)
  end
end

KC:RegisterModule("Diagnostics", KC.Diagnostics)
