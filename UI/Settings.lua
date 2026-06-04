local KC = KeystoneCouncil

KC.Settings = {
  frame = nil,
  pages = {},
  tabs = {},
  refreshers = {},
  activePage = "general",
}

local pageOrder = {
  { id = "general", label = "General" },
  { id = "chat", label = "Chat" },
  { id = "lists", label = "Lists" },
  { id = "help", label = "Help / Test" },
}

local function ApplyBackdrop(frame, alpha)
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(0.08, 0.09, 0.11, alpha or 0.96)
  frame:SetBackdropBorderColor(0.42, 0.36, 0.22, 0.9)
end

local function SetResizeLimits(frame, minWidth, minHeight, maxWidth, maxHeight)
  if frame.SetResizeBounds then
    frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
    return
  end
  if frame.SetMinResize then frame:SetMinResize(minWidth, minHeight) end
  if frame.SetMaxResize then frame:SetMaxResize(maxWidth, maxHeight) end
end

local function AddResizeGrip(frame)
  frame:SetResizable(true)
  SetResizeLimits(frame, 620, 420, 980, 760)

  local grip = CreateFrame("Button", nil, frame)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  grip:SetScript("OnMouseDown", function()
    frame:StartSizing("BOTTOMRIGHT")
  end)
  grip:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
  end)
end

local function RaiseFrame(frame)
  KC.frameLevel = (KC.frameLevel or 100) + 10
  if KC.frameLevel > 9000 then
    KC.frameLevel = 110
  end
  frame:SetFrameStrata("DIALOG")
  frame:SetFrameLevel(KC.frameLevel)
end

local function Profile()
  return KeystoneCouncilDB and KeystoneCouncilDB.profile or {}
end

local function ProfileOptions()
  local profile = Profile()
  if type(profile.options) ~= "table" then
    profile.options = {}
  end
  if type(profile.options.guildRankFilter) ~= "table" then
    profile.options.guildRankFilter = {}
  end
  return profile.options
end

local function KeyReporting()
  local profile = Profile()
  if type(profile.keyReporting) ~= "table" then
    profile.keyReporting = {}
  end
  return profile.keyReporting
end

function KC.Settings:NotifyChanged(message)
  self:RefreshPanel()
  if KC.KeyList then
    KC.KeyList:Refresh()
  end
  if KC.VotePanel then
    KC.VotePanel:Refresh()
  end
  if KC.MinimapButton and KC.MinimapButton.RefreshVisibility then
    KC.MinimapButton:RefreshVisibility()
  end
  if message and KC.Toasts then
    KC.Toasts:Show(message)
  end
end

function KC.Settings:ToggleStreamerMode()
  Profile().streamerMode = not Profile().streamerMode
  self:NotifyChanged("Streamer Mode " .. (Profile().streamerMode and "enabled" or "disabled") .. ".")
end

function KC.Settings:ToggleAnnouncements()
  Profile().announce = not Profile().announce
  self:NotifyChanged("Announcements " .. (Profile().announce and "enabled" or "disabled") .. ".")
end

function KC.Settings:EnsureGuildRankDefaults()
  local filter = ProfileOptions().guildRankFilter
  for _, rank in ipairs(KC.Util:GetAvailableGuildRanks()) do
    if filter[rank] == nil then
      filter[rank] = true
    end
  end
end

function KC.Settings:GetGuildRankSignature()
  return table.concat(KC.Util:GetAvailableGuildRanks(), "|")
end

function KC.Settings:CreateToggle(parent, x, y, label, getter, setter)
  local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  button:SetSize(18, 18)
  button:SetPoint("TOPLEFT", x, y)
  ApplyBackdrop(button, 0.92)

  button.mark = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  button.mark:SetPoint("CENTER", 0, 0)
  button.mark:SetTextColor(1, 0.78, 0.24)

  button.label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  button.label:SetPoint("LEFT", button, "RIGHT", 8, 0)
  button.label:SetTextColor(0.95, 0.92, 0.84)
  button.label:SetText(label)

  button:SetScript("OnClick", function()
    setter(not getter())
  end)

  self.refreshers[#self.refreshers + 1] = function()
    button.mark:SetText(getter() and "X" or "")
  end

  return button
end

function KC.Settings:CreateSectionTitle(parent, x, y, text)
  local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", x, y)
  title:SetTextColor(1, 0.78, 0.24)
  title:SetText(text)
  return title
end

function KC.Settings:CreateHint(parent, x, y, text)
  local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  hint:SetPoint("TOPLEFT", x, y)
  hint:SetTextColor(0.62, 0.62, 0.66)
  hint:SetText(text)
  return hint
end

function KC.Settings:CreateTab(parent, page, index)
  local tab = CreateFrame("Button", nil, parent, "BackdropTemplate")
  tab:SetSize(112, 30)
  tab:SetPoint("TOPLEFT", 18, -58 - ((index - 1) * 36))
  ApplyBackdrop(tab, 0.92)

  tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  tab.text:SetPoint("CENTER")
  tab.text:SetText(page.label)

  tab:SetScript("OnClick", function()
    self:ShowPage(page.id)
  end)

  self.tabs[page.id] = tab
end

function KC.Settings:CreateGeneralPage(parent)
  self:CreateSectionTitle(parent, 18, -18, "General Options")
  self:CreateHint(parent, 18, -42, "Core addon behavior and helpers.")

  self:CreateToggle(parent, 18, -70, "Show Minimap button", function()
    return ProfileOptions().showMinimapButton ~= false
  end, function(value)
    ProfileOptions().showMinimapButton = value
    self:NotifyChanged("Minimap button " .. (value and "shown." or "hidden."))
  end)

  self:CreateToggle(parent, 18, -100, "Sync with friends", function()
    return ProfileOptions().syncFriends ~= false
  end, function(value)
    ProfileOptions().syncFriends = value
    self:NotifyChanged("Friend sync " .. (value and "enabled." or "disabled."))
  end)

  self:CreateToggle(parent, 18, -130, "Show offline players", function()
    return ProfileOptions().showOfflinePlayers ~= false
  end, function(value)
    ProfileOptions().showOfflinePlayers = value
    self:NotifyChanged("Offline players " .. (value and "shown." or "hidden."))
  end)

  self:CreateToggle(parent, 18, -160, "Display offline below online", function()
    return ProfileOptions().displayOfflineBelowOnline ~= false
  end, function(value)
    ProfileOptions().displayOfflineBelowOnline = value
    self:NotifyChanged("Offline ordering updated.")
  end)

  self:CreateToggle(parent, 18, -190, "Announce Council result", function()
    return Profile().announce ~= false
  end, function(value)
    Profile().announce = value
    self:NotifyChanged("Council announcements " .. (value and "enabled." or "disabled."))
  end)

  self:CreateToggle(parent, 18, -220, "Post winner to party", function()
    return Profile().announceWinnerToParty ~= false
  end, function(value)
    Profile().announceWinnerToParty = value
    self:NotifyChanged("Party winner post " .. (value and "enabled." or "disabled."))
  end)

  self:CreateToggle(parent, 18, -250, "Announce New Key To Guild", function()
    return KeyReporting().announceNewKeyGuild ~= false
  end, function(value)
    KeyReporting().announceNewKeyGuild = value
    self:NotifyChanged("Guild new-key post " .. (value and "enabled." or "disabled."))
  end)

  self:CreateToggle(parent, 320, -70, "Streamer overlay", function()
    return Profile().streamerMode == true
  end, function(value)
    Profile().streamerMode = value
    self:NotifyChanged("Streamer Mode " .. (value and "enabled." or "disabled."))
  end)

  self:CreateToggle(parent, 320, -100, "Primary countdown audio", function()
    return Profile().countdownPrimaryAudio ~= false
  end, function(value)
    Profile().countdownPrimaryAudio = value
    self:NotifyChanged("Primary countdown audio " .. (value and "enabled." or "disabled."))
  end)

  self:CreateToggle(parent, 320, -130, "Secondary countdown audio", function()
    return Profile().countdownSecondaryAudio ~= false
  end, function(value)
    Profile().countdownSecondaryAudio = value
    self:NotifyChanged("Secondary countdown audio " .. (value and "enabled." or "disabled."))
  end)

  self:CreateToggle(parent, 320, -160, "Include Guild Meme Quotes", function()
    return ProfileOptions().includeGuildMemeQuotes == true
  end, function(value)
    ProfileOptions().includeGuildMemeQuotes = value
    if KC.Quotes then KC.Quotes:Reroll() end
    self:NotifyChanged("Guild meme quotes " .. (value and "enabled." or "disabled."))
  end)

  self:CreateToggle(parent, 320, -184, "Include Rare Quotes (~1% chance)", function()
    return ProfileOptions().includeRareQuotes == true
  end, function(value)
    ProfileOptions().includeRareQuotes = value
    self:NotifyChanged("Rare quotes " .. (value and "enabled." or "disabled."))
  end)

  self:CreateToggle(parent, 320, -208, "Use external scores (disabled)", function()
    ProfileOptions().useExternalScores = false
    return false
  end, function(value)
    ProfileOptions().useExternalScores = false
    self:NotifyChanged("External score enrichment is disabled for safety. Scores can still come from Astral bridge, KC network, and Blizzard data.")
  end)
end

function KC.Settings:CreateChatPage(parent)
  self:CreateSectionTitle(parent, 18, -18, "!keys Reporting")
  self:CreateHint(parent, 18, -42, "Chat replies and new-key reporting.")

  self:CreateToggle(parent, 18, -70, "Announce new keys to party", function()
    return KeyReporting().announceNewKeyParty ~= false
  end, function(value)
    KeyReporting().announceNewKeyParty = value
    self:NotifyChanged("Party new-key post " .. (value and "enabled." or "disabled."))
  end)

  self:CreateToggle(parent, 18, -100, "Announce New Key To Guild", function()
    return KeyReporting().announceNewKeyGuild ~= false
  end, function(value)
    KeyReporting().announceNewKeyGuild = value
    self:NotifyChanged("Guild new-key post " .. (value and "enabled." or "disabled."))
  end)

  self:CreateToggle(parent, 18, -130, "Respond in party", function()
    return KeyReporting().respondParty ~= false
  end, function(value)
    KeyReporting().respondParty = value
    self:NotifyChanged("Party !keys replies " .. (value and "enabled." or "disabled."))
  end)

  self:CreateToggle(parent, 18, -160, "Respond in guild", function()
    return KeyReporting().respondGuild ~= false
  end, function(value)
    KeyReporting().respondGuild = value
    self:NotifyChanged("Guild !keys replies " .. (value and "enabled." or "disabled."))
  end)

  self:CreateToggle(parent, 18, -190, "Respond in raid", function()
    return KeyReporting().respondRaid ~= false
  end, function(value)
    KeyReporting().respondRaid = value
    self:NotifyChanged("Raid !keys replies " .. (value and "enabled." or "disabled."))
  end)

  self:CreateToggle(parent, 18, -220, "Respond in instance", function()
    return KeyReporting().respondInstance ~= false
  end, function(value)
    KeyReporting().respondInstance = value
    self:NotifyChanged("Instance !keys replies " .. (value and "enabled." or "disabled."))
  end)

  self:CreateToggle(parent, 18, -250, "Respond in say", function()
    return KeyReporting().respondSay ~= false
  end, function(value)
    KeyReporting().respondSay = value
    self:NotifyChanged("Say !keys replies " .. (value and "enabled." or "disabled."))
  end)

  self:CreateToggle(parent, 18, -280, "Respond even if no key", function()
    return KeyReporting().includeNoKey ~= false
  end, function(value)
    KeyReporting().includeNoKey = value
    self:NotifyChanged("No-key replies " .. (value and "enabled." or "disabled."))
  end)

  self:CreateToggle(parent, 18, -310, "Respond with all visible keys", function()
    return KeyReporting().respondAllVisibleKeys == true
  end, function(value)
    KeyReporting().respondAllVisibleKeys = value
    self:NotifyChanged("Expanded !keys replies " .. (value and "enabled." or "disabled."))
  end)

  self:CreateHint(parent, 18, -346, "Chat aliases: !key, !keys")
  self:CreateHint(parent, 18, -364, "Slash aliases: /kc, /ksc, /key, /keys, /keystonecouncil")
end

function KC.Settings:CreateListsPage(parent)
  self:CreateSectionTitle(parent, 18, -18, "List Filters")
  self:CreateHint(parent, 18, -42, "Guild and friends tab filtering.")

  self:CreateHint(parent, 18, -70, "Key table sort")
  local sortModes = {
    { id = "level", label = "Level" },
    { id = "dungeon", label = "Dungeon" },
    { id = "owner", label = "Owner" },
    { id = "score", label = "Score" },
    { id = "weekly", label = "Weekly" },
    { id = "seen", label = "Seen" },
  }
  for index, sortMode in ipairs(sortModes) do
    local sortID = sortMode.id
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(78, 24)
    button:SetPoint("TOPLEFT", 18 + (((index - 1) % 3) * 86), -94 - (math.floor((index - 1) / 3) * 30))
    button:SetText(sortMode.label)
    button:SetScript("OnClick", function()
      if KC.KeyStore and KC.KeyStore:SetSortMode(sortID) then
        self:NotifyChanged("Sort set to " .. sortID .. ".")
      end
    end)
  end

  self:CreateHint(parent, 18, -164, "Guild rank filter")
  self.rankAnchor = { parent = parent, x = 18, y = -190 }
end

function KC.Settings:CreateHelpPage(parent)
  self:CreateSectionTitle(parent, 18, -18, "Help / Test")
  self:CreateHint(parent, 18, -42, "Quick checks for beta testers.")

  local lines = {
    "/kc refresh - refresh local, party, guild, and provider keys",
    "/kc status - print tester status",
    "/kc guildcheck - print guild/adoption audit",
    "/kc resetcheck - print weekly reset audit",
    "/kc failures - print recent failed sync retries",
    "/kc sort level|dungeon|owner|score|weekly|seen",
    "/kc cleanup - remove duplicate and stale stored keys",
    "/kc test - add fake test keys",
    "/kc streamtest - preview streamer overlay",
    "!keys - ask for keys in Say, Guild, Party, Raid, or Instance chat",
  }

  for index, line in ipairs(lines) do
    self:CreateHint(parent, 18, -70 - ((index - 1) * 20), line)
  end

  local buttonY = -88 - (#lines * 20)

  local statusButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  statusButton:SetSize(116, 24)
  statusButton:SetPoint("TOPLEFT", 18, buttonY)
  statusButton:SetText("Print Status")
  statusButton:SetScript("OnClick", function()
    KC.Diagnostics:PrintStatus()
  end)

  local cleanupButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  cleanupButton:SetSize(126, 24)
  cleanupButton:SetPoint("LEFT", statusButton, "RIGHT", 8, 0)
  cleanupButton:SetText("Clean Keys")
  cleanupButton:SetScript("OnClick", function()
    if KC.KeyLedger then
      KC.KeyLedger:Cleanup()
    end
  end)

  local refreshButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  refreshButton:SetSize(92, 24)
  refreshButton:SetPoint("LEFT", cleanupButton, "RIGHT", 8, 0)
  refreshButton:SetText("Refresh")
  refreshButton:SetScript("OnClick", function()
    KC:RefreshKeys()
    KC.Logger:Print("Refreshed keys.")
  end)

  local testButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  testButton:SetSize(96, 24)
  testButton:SetPoint("TOPLEFT", statusButton, "BOTTOMLEFT", 0, -10)
  testButton:SetText("Fake Keys")
  testButton:SetScript("OnClick", function()
    if KC.AddTestKeys then
      KC:AddTestKeys()
    end
  end)

  local streamButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  streamButton:SetSize(136, 24)
  streamButton:SetPoint("LEFT", testButton, "RIGHT", 8, 0)
  streamButton:SetText("Streamer Preview")
  streamButton:SetScript("OnClick", function()
    if KC.StreamerOverlay and KC.StreamerOverlay.Preview then
      KC.StreamerOverlay:Preview()
    end
  end)
end

function KC.Settings:RebuildRankToggles()
  if not self.rankAnchor then
    return
  end

  local signature = self:GetGuildRankSignature()
  if self.rankButtons and self.rankSignature == signature then
    return
  end

  if self.rankButtons then
    for _, button in ipairs(self.rankButtons) do
      button:Hide()
    end
  end

  self:EnsureGuildRankDefaults()
  local ranks = KC.Util:GetAvailableGuildRanks()
  self.rankButtons = {}
  for index, rank in ipairs(ranks) do
    local column = math.floor((index - 1) / 8)
    local row = (index - 1) % 8
    local x = self.rankAnchor.x + (column * 210)
    local y = self.rankAnchor.y - (row * 28)
    local button = self:CreateToggle(self.rankAnchor.parent, x, y, rank, function()
      return ProfileOptions().guildRankFilter[rank] ~= false
    end, function(value)
      ProfileOptions().guildRankFilter[rank] = value
      self:NotifyChanged(rank .. " " .. (value and "included." or "filtered."))
    end)
    button.label:SetWidth(170)
    button.label:SetJustifyH("LEFT")
    self.rankButtons[#self.rankButtons + 1] = button
  end
  self.rankSignature = signature
end

function KC.Settings:ShowPage(pageID)
  self.activePage = pageID
  for id, page in pairs(self.pages) do
    if id == pageID then
      page:Show()
    else
      page:Hide()
    end
  end

  for id, tab in pairs(self.tabs) do
    if id == pageID then
      tab:SetBackdropColor(0.34, 0.08, 0.08, 0.92)
      tab:SetBackdropBorderColor(0.78, 0.56, 0.16, 0.95)
      tab.text:SetTextColor(1, 0.82, 0.28)
    else
      tab:SetBackdropColor(0.13, 0.14, 0.17, 0.82)
      tab:SetBackdropBorderColor(0.42, 0.36, 0.22, 0.85)
      tab.text:SetTextColor(0.78, 0.74, 0.64)
    end
  end
end

function KC.Settings:CreatePanel()
  if self.frame then
    return
  end

  local frame = CreateFrame("Frame", "KeystoneCouncilOptionsFrame", UIParent, "BackdropTemplate")
  frame:SetSize(760, 520)
  frame:SetPoint("CENTER", 60, 0)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  RaiseFrame(frame)
  frame:SetScript("OnMouseDown", function()
    RaiseFrame(frame)
  end)
  ApplyBackdrop(frame, 0.97)
  AddResizeGrip(frame)
  frame:Hide()

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  frame.title:SetPoint("TOPLEFT", 18, -18)
  frame.title:SetTextColor(1, 0.78, 0.24)
  frame.title:SetText("Keystone Council Options")

  frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 1, -4)
  frame.subtitle:SetTextColor(0.62, 0.62, 0.66)
  frame.subtitle:SetText("Reporting, filtering, sync, and helpers.")

  frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  frame.close:SetPoint("TOPRIGHT", -6, -6)

  frame.sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.sidebar:SetPoint("TOPLEFT", 18, -56)
  frame.sidebar:SetPoint("BOTTOMLEFT", 18, 18)
  frame.sidebar:SetWidth(130)
  ApplyBackdrop(frame.sidebar, 0.72)

  frame.content = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.content:SetPoint("TOPLEFT", frame.sidebar, "TOPRIGHT", 12, 0)
  frame.content:SetPoint("BOTTOMRIGHT", -18, 18)
  ApplyBackdrop(frame.content, 0.64)

  self.frame = frame

  for index, page in ipairs(pageOrder) do
    self:CreateTab(frame.sidebar, page, index)

    local pageFrame = CreateFrame("Frame", nil, frame.content)
    pageFrame:SetAllPoints()
    self.pages[page.id] = pageFrame
  end

  self:CreateGeneralPage(self.pages.general)
  self:CreateChatPage(self.pages.chat)
  self:CreateListsPage(self.pages.lists)
  self:CreateHelpPage(self.pages.help)
  self:ShowPage(self.activePage)
end

function KC.Settings:RefreshPanel()
  if not self.frame then
    return
  end

  self:EnsureGuildRankDefaults()
  self:RebuildRankToggles()

  for _, refresh in ipairs(self.refreshers) do
    refresh()
  end
end

function KC.Settings:TogglePanel()
  if not self.frame then
    self:CreatePanel()
  end

  if self.frame:IsShown() then
    self.frame:Hide()
  else
    self:RefreshPanel()
    RaiseFrame(self.frame)
    self.frame:Show()
    self:ShowPage(self.activePage)
  end
end

KC:RegisterModule("Settings", KC.Settings)
