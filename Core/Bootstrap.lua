local KC = KeystoneCouncil

KC.frame = CreateFrame("Frame")

local function ShowHelp()
  KC.Logger:Print("/kc - open Keystone Council")
  KC.Logger:Print("/ksc - open Keystone Council")
  KC.Logger:Print("/key - open Keystone Council")
  KC.Logger:Print("/keys - open Keystone Council")
  KC.Logger:Print("/kc refresh - refresh your keystone")
  KC.Logger:Print("/kc settings - open KSC options")
  KC.Logger:Print("/kc spin - convene the Council")
  KC.Logger:Print("/kc chaos - roll optional-for-fun chaos assignments")
  KC.Logger:Print("/kc mode spin|raffle|majority|smart")
  KC.Logger:Print("/kc clear - clear test keys and votes")
  KC.Logger:Print("/kc streamer - toggle streamer mode")
  KC.Logger:Print("/kc stats - show Council statistics")
  KC.Logger:Print("/kc ledger - show all known keys")
  KC.Logger:Print("/kc dumpkeys - print every known key row")
  KC.Logger:Print("/kc pipeline - print key counts at every pipeline stage")
  KC.Logger:Print("/kc status - print tester status")
  KC.Logger:Print("/kc version - print addon version")
  KC.Logger:Print("/kc modules - print module health")
  KC.Logger:Print("/kc readiness - print beta readiness checks")
  KC.Logger:Print("/kc perf - print performance snapshot")
  KC.Logger:Print("/kc sort level|dungeon|owner|score|weekly|seen")
  KC.Logger:Print("/kc guildcheck - print guild/adoption key audit")
  KC.Logger:Print("/kc resetcheck - print weekly reset audit")
  KC.Logger:Print("/kc failures - print recent failed sync retries")
  KC.Logger:Print("/kc quote - roll a new subtitle quote")
  KC.Logger:Print("/kc quote guild - force a guild quote")
  KC.Logger:Print("/kc quote rare - force a rare quote")
  KC.Logger:Print("/kc quote generic - force a generic quote")
  KC.Logger:Print("/kc cleanup - remove duplicate and stale stored keys")
  KC.Logger:Print("/kc diag - print diagnostics")
  KC.Logger:Print("/kc inspect - show candidate inspector")
  KC.Logger:Print("/kc peers - show party sync peers")
  KC.Logger:Print("/kc dev <password> - open developer test area")
  KC.Logger:Print("/kc announce party|raid|auto|off")
  KC.Logger:Print("!key or !keys - reply with your current key in guild, party, or raid")
  KC.Logger:Print("/kc export - print a diagnostic export")
  KC.Logger:Print("/kc streamtest - preview streamer overlay")
  KC.Logger:Print("/kc test - add sample keys")
end

function KC:AddTestKeys()
  KC.KeyStore:ClearSource("Test")
  KC.KeyStore:Upsert({ ownerName = "Nez", classFile = "MAGE", dungeonID = 503, level = 15, source = "Test" })
  KC.KeyStore:Upsert({ ownerName = "Volk", classFile = "WARRIOR", dungeonID = 504, level = 14, source = "Test" })
  KC.KeyStore:Upsert({ ownerName = "Chopper", classFile = "ROGUE", dungeonID = 511, level = 15, source = "Test" })
  KC.KeyStore:Upsert({ ownerName = "Dym", classFile = "PRIEST", dungeonID = 505, level = 14, source = "Test" })
  KC.Logger:Print("Sample keys added.")
end

function KC:ScheduleRefreshKeys(delay)
  if self.refreshScheduled then
    return
  end

  self.refreshScheduled = true
  local function Run()
    self.refreshScheduled = false
    if self.initialized then
      self:RefreshKeys()
    end
  end

  if C_Timer and C_Timer.After then
    C_Timer.After(delay or 0.5, Run)
  else
    Run()
  end
end

function KC:RefreshKeys()
  self.refreshStatus = {}
  local function AddStatus(line)
    self.refreshStatus[#self.refreshStatus + 1] = line
  end

  if GuildRoster then
    pcall(GuildRoster)
    AddStatus("GuildRoster: requested")
  end
  if KeystoneCouncilDB and KeystoneCouncilDB.profile and KeystoneCouncilDB.profile.options and KeystoneCouncilDB.profile.options.syncFriends ~= false and C_FriendList and C_FriendList.ShowFriends then
    pcall(C_FriendList.ShowFriends)
    AddStatus("Friends: requested")
  end

  if KC.ExternalKeyProvider then
    -- Do not repeatedly scan external saved variables on every social event; this is expensive and optional.
    if KC.ExternalKeyProvider:IsLoaded() and ((KC.ExternalKeyProvider.lastImportAt or 0) == 0 or time() - (KC.ExternalKeyProvider.lastImportAt or 0) > 60) then
      KC.ExternalKeyProvider.lastImportAt = time()
      AddStatus("External key provider: " .. (KC.ExternalKeyProvider:Import() and "imported" or "no compatible import"))
    else
      AddStatus(KC.ExternalKeyProvider:GetStatusLine())
    end
  end
  if KC.ExternalScoreProvider then
    AddStatus(KC.ExternalScoreProvider:GetStatusLine())
  end
  if KC.BlizzardKeys then
    AddStatus("Blizzard: " .. (KC.BlizzardKeys:Refresh() and "local key found" or "no local key"))
  end
  if KC.SharedKeyProvider then
    AddStatus("Shared key provider party: " .. (KC.SharedKeyProvider:RequestPartyKeys() and "requested" or "unavailable"))
    AddStatus("Shared key provider guild: " .. (KC.SharedKeyProvider:RequestGuildKeys() and "requested" or "unavailable"))
  end
  if KC.GroupKeyProvider then
    AddStatus("Group key provider: " .. (KC.GroupKeyProvider:RequestPartyKeys() and "requested" or "unavailable"))
  end
  if KC.PartySync then
    KC.PartySync:BroadcastHello()
    KC.PartySync:BroadcastLedger()
    AddStatus("PartySync: hello sent")
  end
  if KC.KeyNetwork then
    AddStatus("KC guild network: " .. (KC.KeyNetwork:BroadcastLocalKey(false) and "broadcast sent" or "not sent"))
  end
  if KC.AstralBridge then
    if KC.AstralBridge.ImportSavedVariables then
      local imported = KC.AstralBridge:ImportSavedVariables() or 0
      AddStatus("Astral saved data: imported " .. tostring(imported))
    end
    AddStatus("Astral bridge guild: " .. (KC.AstralBridge:RequestAstralKeys() and "request sent" or "request skipped"))
    if KC.AstralBridge.RequestAstralFriends then
      AddStatus("Astral bridge friends: " .. (KC.AstralBridge:RequestAstralFriends() and "request sent" or "request skipped"))
    end
  end
end

function KC:HandleSlash(input)
  input = input or ""

  local command, rest = string.match(input, "^(%S*)%s*(.-)$")
  command = string.lower(command or "")
  rest = rest or ""
  local restLower = string.lower(rest)

  if command == "" then
    KC.MainFrame:Toggle()
  elseif command == "settings" or command == "options" then
    KC.Settings:TogglePanel()
  elseif command == "refresh" then
    self:RefreshKeys()
    KC.Logger:Print("Refreshed keys.")
  elseif command == "spin" or command == "convene" then
    KC.Modes:Start()
  elseif command == "chaos" then
    if KC.ChaosMode then
      KC.ChaosMode:Run()
    end
  elseif command == "help" then
    ShowHelp()
  elseif command == "mode" and restLower == "" then
    KC.Logger:Print("Current mode: " .. tostring(KC.Modes:GetMode()))
    KC.Logger:Print("Modes: spin, raffle, majority, smart")
  elseif command == "mode" and restLower == "chaos" then
    if KC.ChaosMode then
      KC.ChaosMode:Run()
      KC.Logger:Print("Chaos is a separate optional-for-fun action. Your Council mode is still " .. tostring(KC.Modes:GetMode()) .. ".")
    end
  elseif command == "mode" and restLower ~= "" then
    local normalizedMode = KC.Modes and KC.Modes.NormalizeMode and KC.Modes:NormalizeMode(restLower) or restLower
    if normalizedMode then
      KC.Modes:SetMode(normalizedMode)
      KC.MainFrame:RefreshMode()
      KC.Logger:Print("Mode set to " .. normalizedMode .. ".")
    else
      KC.Logger:Print("Unknown mode: " .. rest)
    end
  elseif command == "test" then
    self:AddTestKeys()
  elseif command == "status" then
    KC.Diagnostics:PrintStatus()
  elseif command == "version" or command == "about" then
    KC.Logger:Print("Version " .. tostring(KC.VERSION) .. " | protocol " .. tostring(KC.PROTOCOL_VERSION))
  elseif command == "modules" then
    if KC.Diagnostics and KC.Diagnostics.PrintModuleStatus then
      KC.Diagnostics:PrintModuleStatus()
    end
  elseif command == "readiness" or command == "selftest" or command == "readycheck" then
    if KC.Diagnostics and KC.Diagnostics.PrintReadiness then
      KC.Diagnostics:PrintReadiness()
    end
  elseif command == "perf" or command == "performance" then
    KC.Diagnostics:PrintPerformanceSnapshot()
  elseif command == "sort" then
    if restLower == "" then
      KC.Logger:Print("Current sort: " .. tostring(KC.KeyStore and KC.KeyStore.GetSortMode and KC.KeyStore:GetSortMode() or "level"))
      KC.Logger:Print("Sort modes: level, dungeon, owner, score, weekly, seen")
    elseif KC.KeyStore and KC.KeyStore:SetSortMode(restLower) then
      if KC.KeyList then
        KC.KeyList:Refresh()
      end
      KC.Logger:Print("Key table sort set to " .. tostring(restLower) .. ".")
    else
      KC.Logger:Print("Sort modes: level, dungeon, owner, score, weekly, seen")
    end
  elseif command == "guildcheck" or command == "guildaudit" then
    KC.Diagnostics:PrintGuildValidation()
  elseif command == "resetcheck" or command == "resetaudit" then
    KC.Diagnostics:PrintResetValidation()
  elseif command == "failures" or command == "failedsync" then
    local rows = KC.PartySync and KC.PartySync.GetFailedRows and KC.PartySync:GetFailedRows() or {}
    KC.Logger:Print("Failed sync retries: " .. tostring(#rows))
    for _, row in ipairs(rows) do
      KC.Logger:Print(tostring(row.id) .. " | attempts " .. tostring(row.attempts) .. " | ack " .. tostring(row.ackCount) .. "/" .. tostring(row.expectedAckCount))
    end
  elseif command == "quote" then
    if KC.Quotes then
      local subcommand = restLower or ""
      local quote
      if subcommand == "guild" or subcommand == "rare" or subcommand == "generic" then
        quote = KC.Quotes:ForceSelect(subcommand)
        KC.Logger:Print("Quote [" .. subcommand .. "]: " .. tostring(quote))
      else
        quote = KC.Quotes:Reroll()
        KC.Logger:Print("Quote: " .. tostring(quote))
      end
    end
  elseif command == "cleanup" or command == "clean" then
    if KC.KeyLedger then
      KC.KeyLedger:Cleanup()
    end
  elseif command == "streamtest" or command == "preview" then
    if KC.StreamerOverlay then
      KC.StreamerOverlay:Preview()
    end
  elseif command == "clear" then
    KC.KeyStore:ClearSource("Test")
    KC.SessionStore:ClearVotes()
    self:RefreshKeys()
    if KC.StatsPanel then
      KC.StatsPanel:Refresh()
    end
    KC.Logger:Print("Test keys and votes cleared.")
  elseif command == "announce" then
    if restLower == "off" then
      KeystoneCouncilDB.profile.announce = false
      KC.Logger:Print("Announcements disabled.")
    elseif restLower == "party" or restLower == "raid" or restLower == "auto" then
      KeystoneCouncilDB.profile.announce = true
      KeystoneCouncilDB.profile.announceChannel = string.upper(restLower)
      KC.Logger:Print("Announcements set to " .. string.upper(restLower) .. ".")
    else
      KC.Settings:ToggleAnnouncements()
    end
  elseif command == "streamer" then
    KC.Settings:ToggleStreamerMode()
  elseif command == "stats" then
    local summary = KC.StatsStore:GetSummary()
    KC.Logger:Print("Selections recorded: " .. tostring(summary.totalSelections))
    if summary.topPlayer then
      KC.Logger:Print("Most selected player: " .. summary.topPlayer.name .. " (" .. summary.topPlayer.selected .. ")")
    end
    if summary.topDungeon then
      KC.Logger:Print("Most selected dungeon: " .. summary.topDungeon.name .. " (" .. summary.topDungeon.selected .. ")")
    end
  elseif command == "ledger" or command == "all" then
    KC.MainFrame:Show()
    KC.KeyList:SetView("all")
  elseif command == "diag" then
    KC.Diagnostics:Print()
    KC.Diagnostics:Validate()
  elseif command == "astraldebug" then
    if KC.AstralBridge and KC.AstralBridge.GetDebugLines then
      for _, line in ipairs(KC.AstralBridge:GetDebugLines()) do
        KC.Logger:Print(line)
      end
    else
      KC.Logger:Print("Astral bridge: unavailable")
    end
  elseif command == "dumpkeys" then
    local rows = KC.KeyLedger and KC.KeyLedger.GetAll and KC.KeyLedger:GetAll() or {}
    KC.Logger:Print("Known key rows: " .. tostring(#rows))
    for index, key in ipairs(rows) do
      if index > 40 then
        KC.Logger:Print("...truncated after 40 rows")
        break
      end
      local onlineStr = KC.Util and KC.Util.IsOwnerOnline and (KC.Util:IsOwnerOnline(key) and "online" or "offline") or "?"
      KC.Logger:Print(
        tostring(index) .. ". " ..
        tostring(key.ownerName or "?") .. "-" .. tostring(key.ownerRealm or "") ..
        " | +" .. tostring(key.level or "?") .. " " .. tostring(key.dungeonName or key.dungeonID or "?") ..
        " | src=" .. tostring(key.source or "?") ..
        " bucket=" .. tostring(key.sourceBucket or "nil") ..
        " resolvedBucket=" .. tostring(key.bucket or "?") ..
        " | stale=" .. tostring(key.isStale == true) ..
        " " .. onlineStr
      )
    end
  elseif command == "pipeline" then
    -- Trace counts at every stage of the key pipeline.
    local ledgerAll = KC.KeyLedger and KC.KeyLedger.GetAll and KC.KeyLedger:GetAll() or {}
    local storeAll = KC.KeyStore and KC.KeyStore.GetAll and KC.KeyStore:GetAll() or {}
    KC.Logger:Print("=== Key Pipeline Snapshot ===")
    KC.Logger:Print("Ledger (raw):    " .. tostring(#ledgerAll) .. " entries")
    local bucketCounts = {}
    for _, entry in ipairs(ledgerAll) do
      local b = tostring(entry.bucket or "other")
      bucketCounts[b] = (bucketCounts[b] or 0) + 1
    end
    for b, n in pairs(bucketCounts) do
      KC.Logger:Print("  ledger[" .. b .. "]: " .. tostring(n))
    end
    KC.Logger:Print("KeyStore (live): " .. tostring(#storeAll) .. " entries")
    for _, v in ipairs({"all", "guild", "friends", "party"}) do
      local ledgerView = KC.KeyLedger and KC.KeyLedger.GetByView and KC.KeyLedger:GetByView(v) or {}
      local storeView = KC.KeyStore and KC.KeyStore.GetByView and KC.KeyStore:GetByView(v) or {}
      KC.Logger:Print("Filter[" .. v .. "]: ledger=" .. tostring(#ledgerView) .. " store=" .. tostring(#storeView))
    end
    local currentView = KC.KeyList and KC.KeyList.currentView or "?"
    local rendered = KC.KeyList and KC.KeyList.filteredKeys and #KC.KeyList.filteredKeys or 0
    KC.Logger:Print("Render: view=" .. tostring(currentView) .. " rows=" .. tostring(rendered))
    if KC.AstralBridge and KC.AstralBridge.GetStatusLine then
      KC.Logger:Print(KC.AstralBridge:GetStatusLine())
    end
  elseif command == "export" then
    KC.Diagnostics:Export()
  elseif command == "inspect" or command == "candidates" then
    KC.CandidateInspector:Toggle()
  elseif command == "peers" or command == "sync" then
    KC.PeerPanel:Toggle()
  elseif command == "dev" then
    if KC.DevTools and not KC.DevTools:IsUnlocked() then
      if KC.DevTools:Unlock(rest) then
        KC.DevTools:Open()
      end
    elseif KC.DevTools then
      if restLower == "fake" or restLower == "party" then
        KC.DevTools:AddFakeParty()
      elseif restLower == "ledger" then
        KC.DevTools:AddFakeLedger()
      elseif restLower == "stale" then
        KC.DevTools:AddStaleKey()
      elseif restLower == "clear" then
        KC.DevTools:ClearFakeData()
      else
        KC.DevTools:Open()
      end
    end
  else
    ShowHelp()
  end
end

function KC:OnAddonLoaded(addonName)
  if addonName ~= KC.ADDON_NAME then
    return
  end

  if self.initialized then
    return
  end
  self.initialized = true

  self:InitializeDatabase()
  self:InitializeModules()
  self:EnableModules()

  SLASH_KEYSTONECOUNCIL1 = "/kc"
  SLASH_KEYSTONECOUNCIL2 = "/keystonecouncil"
  SLASH_KEYSTONECOUNCIL3 = "/ksc"
  SLASH_KEYSTONECOUNCIL4 = "/key"
  SLASH_KEYSTONECOUNCIL5 = "/keys"
  SlashCmdList.KEYSTONECOUNCIL = function(input)
    KC:HandleSlash(input)
  end

  -- Keep the key table alive after login/reload. Mythic+ and social data can
  -- arrive after ADDON_LOADED, and keys can change after bags/group/guild/friend
  -- updates. Debouncing prevents spam while fixing empty All/Friends/Guild tabs.
  self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  self.frame:RegisterEvent("BAG_UPDATE_DELAYED")
  self.frame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
  self.frame:RegisterEvent("GROUP_ROSTER_UPDATE")
  self.frame:RegisterEvent("GUILD_ROSTER_UPDATE")
  self.frame:RegisterEvent("FRIENDLIST_UPDATE")

  if C_Timer and C_Timer.After then
    C_Timer.After(1.5, function()
      if self.initialized then
        self:RefreshKeys()
      end
    end)
  else
    self:RefreshKeys()
  end

  KC.Logger:Print("ready. Type /kc to convene.")
end

KC.frame:RegisterEvent("ADDON_LOADED")
KC.frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    KC:OnAddonLoaded(...)
    return
  end

  if event == "PLAYER_ENTERING_WORLD"
    or event == "BAG_UPDATE_DELAYED"
    or event == "CHALLENGE_MODE_MAPS_UPDATE"
    or event == "GROUP_ROSTER_UPDATE"
    or event == "GUILD_ROSTER_UPDATE"
    or event == "FRIENDLIST_UPDATE" then
    KC:ScheduleRefreshKeys(0.75)
  end
end)
