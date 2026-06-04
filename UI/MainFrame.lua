local KC = KeystoneCouncil

KC.MainFrame = {}

local modes = {
  { id = "spin", label = "Spin" },
  { id = "raffle", label = "Raffle" },
  { id = "majority", label = "Majority" },
  { id = "smart", label = "Smart" },
}

local function ApplyBackdrop(frame)
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(0.08, 0.09, 0.11, 0.96)
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

local function AddResizeGrip(frame, onResizeDone)
  frame:SetResizable(true)
  SetResizeLimits(frame, 620, 330, 940, 760)

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
    if onResizeDone then
      onResizeDone()
    end
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

function KC.MainFrame:Create()
  if self.frame then
    return
  end

  local frame = CreateFrame("Frame", "KeystoneCouncilFrame", UIParent, "BackdropTemplate")
  frame:SetSize(640, 430)
  frame:SetPoint("CENTER")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetScale(KeystoneCouncilDB.profile.scale or 1)
  RaiseFrame(frame)
  frame:SetScript("OnMouseDown", function()
    RaiseFrame(frame)
  end)
  ApplyBackdrop(frame)
  AddResizeGrip(frame, function()
    if KC.KeyList then KC.KeyList:Refresh() end
  end)

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  frame.title:SetPoint("TOPLEFT", 18, -18)
  frame.title:SetTextColor(1, 0.78, 0.24)
  frame.title:SetText("Keystone Council")

  frame.mode = CreateFrame("Frame", nil, frame)
  frame.mode:SetPoint("TOPRIGHT", -42, -20)
  frame.mode:SetSize(164, 24)

  frame.modeLabel = frame.mode:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.modeLabel:SetPoint("RIGHT", frame.mode, "LEFT", -8, 0)
  frame.modeLabel:SetTextColor(0.62, 0.62, 0.66)
  frame.modeLabel:SetText("Mode")

  frame.modeButton = CreateFrame("Button", nil, frame.mode, "UIPanelButtonTemplate")
  frame.modeButton:SetAllPoints()
  frame.modeButton:SetScript("OnClick", function()
    self:CycleMode()
  end)

  frame.tagline = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.tagline:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 1, -4)
  frame.tagline:SetPoint("RIGHT", frame.modeLabel, "LEFT", -14, 0)
  frame.tagline:SetJustifyH("LEFT")
  frame.tagline:SetTextColor(0.62, 0.62, 0.66)
  if KC.Quotes then
    KC.Quotes:Apply(frame.tagline)
  else
    frame.tagline:SetText("Stop Arguing. Start Pushing.")
  end

  frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  frame.close:SetPoint("TOPRIGHT", -6, -6)

  KC.WinnerBanner:Create(frame)
  KC.KeyList:Create(frame)
  KC.VotePanel:Create(frame)
  KC.StatsPanel:Create(frame)
  if KC.SeasonBest then
    KC.SeasonBest:Create(frame)
  end
  KC.Wheel:Create(frame)

  frame.refresh = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.refresh:SetSize(76, 26)
  frame.refresh:SetPoint("BOTTOMLEFT", 18, 18)
  frame.refresh:SetText("Refresh")
  frame.refresh:SetScript("OnClick", function()
    if KC.RefreshKeys then
      KC:RefreshKeys()
    end
    KC.KeyList:Refresh()
  end)

  frame.ready = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.ready:SetSize(96, 26)
  frame.ready:SetPoint("LEFT", frame.refresh, "RIGHT", 8, 0)
  frame.ready:SetText("Ready Check")
  frame.ready:SetScript("OnClick", function()
    KC.ReadyCheck:Start()
  end)

  frame.streamer = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.streamer:SetSize(86, 26)
  frame.streamer:SetPoint("LEFT", frame.ready, "RIGHT", 8, 0)
  frame.streamer:SetText("Streamer")
  frame.streamer:SetScript("OnClick", function()
    KC.Settings:ToggleStreamerMode()
  end)

  frame.options = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.options:SetSize(64, 22)
  frame.options:SetPoint("TOPRIGHT", frame.mode, "BOTTOMRIGHT", 0, -8)
  frame.options:SetText("Options")
  frame.options:SetScript("OnClick", function()
    KC.Settings:TogglePanel()
  end)

  frame.inspect = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.inspect:SetSize(62, 22)
  frame.inspect:SetPoint("RIGHT", frame.options, "LEFT", -8, 0)
  frame.inspect:SetText("Inspect")
  frame.inspect:SetScript("OnClick", function()
    KC.CandidateInspector:Toggle()
  end)

  frame.peers = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.peers:SetSize(54, 22)
  frame.peers:SetPoint("RIGHT", frame.inspect, "LEFT", -8, 0)
  frame.peers:SetText("Peers")
  frame.peers:SetScript("OnClick", function()
    KC.PeerPanel:Toggle()
  end)

  frame.chaos = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.chaos:SetSize(62, 22)
  frame.chaos:SetPoint("RIGHT", frame.peers, "LEFT", -8, 0)
  frame.chaos:SetText("Chaos")
  frame.chaos:SetScript("OnClick", function()
    if KC.ChaosMode then
      KC.ChaosMode:Run()
    end
  end)

  frame.start = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.start:SetSize(122, 28)
  frame.start:SetPoint("BOTTOMRIGHT", -30, 18)
  frame.start:SetText("Convene")
  frame.start:SetScript("OnClick", function()
    KC.Modes:Start()
  end)

  if KC.PortalActions then
    KC.PortalActions:Create(frame)
    KC.PortalActions:AnchorTo(frame.start)
  elseif KC.TeleportButton then
    KC.TeleportButton:Create(frame)
    KC.TeleportButton:AnchorTo(frame.start)
  end

  frame:Hide()
  self.frame = frame
  self:RefreshMode()
  self:RefreshConveneButton()
end

function KC.MainFrame:RefreshMode()
  if not self.frame then
    return
  end

  local current = KC.Modes:GetMode()
  local label = current
  for _, mode in ipairs(modes) do
    if mode.id == current then
      label = mode.label
    end
  end
  self.frame.modeButton:SetText(label)
  self:RefreshConveneButton()
end

function KC.MainFrame:RefreshConveneButton()
  if not self.frame or not self.frame.start then
    return
  end

  local label = "Convene"
  if KC.Modes and KC.Modes:IsVoteMode() then
    local mode = KC.Modes:GetMode()
    if mode == "majority" then
      label = (KC.SessionStore and KC.SessionStore:IsVoteOpen()) and "Resolve Majority" or "Start Majority"
    else
      label = (KC.SessionStore and KC.SessionStore:IsVoteOpen()) and "Resolve Raffle" or "Start Raffle"
    end
  end

  self.frame.start:SetText(label)
end

function KC.MainFrame:CycleMode()
  local current = KC.Modes:GetMode()
  local index = 1

  for i, mode in ipairs(modes) do
    if mode.id == current then
      index = i
    end
  end

  local nextMode = modes[(index % #modes) + 1]
  KC.Modes:SetMode(nextMode.id)
  self:RefreshMode()
end

function KC.MainFrame:Toggle()
  if not self.frame then
    self:Create()
  end

  if self.frame:IsShown() then
    self.frame:Hide()
  else
    RaiseFrame(self.frame)
    self.frame:Show()
    KC.KeyList:Refresh()
    KC.VotePanel:Refresh()
    if KC.RefreshKeys then
      KC:RefreshKeys()
    end
  end
end

function KC.MainFrame:Show()
  if not self.frame then
    self:Create()
  end

  self.frame:Show()
  RaiseFrame(self.frame)
  KC.KeyList:Refresh()
  KC.VotePanel:Refresh()
  if KC.RefreshKeys then
    KC:RefreshKeys()
  end
end

function KC.MainFrame:OnEnable()
  KC.EventBus:On(KC.EVENTS.KEYS_CHANGED, self, function()
    KC.KeyList:Refresh()
    if KC.CandidateInspector and KC.CandidateInspector.frame and KC.CandidateInspector.frame:IsShown() then
      KC.CandidateInspector:Refresh()
    end
  end)

  KC.EventBus:On(KC.EVENTS.VOTES_CHANGED, self, function(owner)
    KC.VotePanel:Refresh()
    owner:RefreshConveneButton()
  end)

  KC.EventBus:On(KC.EVENTS.COUNCIL_RESULT, self, function(owner, result)
    if KC.WinnerBanner.frame then
      KC.WinnerBanner.frame:Hide()
    end
    KC.Wheel:Spin(result)
    KC.StreamerOverlay:ShowResult(result)
    if KC.PortalActions then
      KC.PortalActions:ShowForResult(result)
    elseif KC.TeleportButton then
      KC.TeleportButton:ShowForResult(result)
    end
    if KC.SeasonBest then
      KC.SeasonBest:Refresh()
    end
    KC.StatsPanel:Refresh()
  end)

  KC.EventBus:On(KC.EVENTS.SESSION_CHANGED, self, function(owner)
    owner:RefreshConveneButton()
    KC.VotePanel:Refresh()
  end)
end

KC:RegisterModule("MainFrame", KC.MainFrame)
