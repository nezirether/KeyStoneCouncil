local KC = KeystoneCouncil

KC.Wheel = {
  spinning = false,
  tickToggle = false,
  activeTicker = nil,
}

local revealDelaySeconds = 3.6

function KC.Wheel:GetRevealDelay()
  return revealDelaySeconds
end

function KC.Wheel:Create(parent)
  local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  frame:SetSize(190, 190)
  frame:SetPoint("TOP", parent, "TOP", 0, -164)
  frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
  frame:SetBackdropColor(0.08, 0.09, 0.11, 0.72)

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("CENTER", 0, 18)
  frame.title:SetTextColor(1, 0.78, 0.24)
  frame.title:SetText("Council")

  frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.subtitle:SetPoint("TOP", frame.title, "BOTTOM", 0, -8)
  frame.subtitle:SetTextColor(0.62, 0.62, 0.66)
  frame.subtitle:SetText("Awaiting keys")

  frame:Hide()
  self.frame = frame
end

function KC.Wheel:Spin(result)
  if not self.frame then
    return
  end

  if self.activeTicker then
    self.activeTicker:Cancel()
    self.activeTicker = nil
  end

  if KC.KeyList then
    KC.KeyList:SetVisible(false)
  end
  if KC.VotePanel and KC.VotePanel.frame then
    KC.VotePanel.frame:Hide()
  end
  if KC.StatsPanel and KC.StatsPanel.frame then
    KC.StatsPanel.frame:Hide()
  end

  self.frame:Show()
  self.spinning = true
  self.frame.title:SetText("Deliberating")
  self.frame.subtitle:SetText("The Council weighs destiny...")

  local ticks = 0
  local function FinishSpin()
    self.activeTicker = nil
    self.spinning = false
    self.frame.title:SetText("Chosen")
    self.frame.subtitle:SetText(tostring(result.ownerName or "Unknown") .. " +" .. tostring(result.level or "?"))
    local function Reveal()
      self.frame:Hide()
      KC.WinnerBanner:ShowResult(result)
      if KC.KeyList then
        KC.KeyList:SetVisible(true)
      end
      if KC.VotePanel and KC.VotePanel.frame then
        KC.VotePanel.frame:Show()
        KC.VotePanel:Refresh()
      end
      if KC.StatsPanel and KC.StatsPanel.frame then
        KC.StatsPanel.frame:Show()
        KC.StatsPanel:Refresh()
      end
    end
    if C_Timer and C_Timer.After then
      C_Timer.After(0.35, Reveal)
    else
      Reveal()
    end
  end

  if not C_Timer or not C_Timer.NewTicker then
    FinishSpin()
    return
  end

  local ticker
  ticker = C_Timer.NewTicker(0.18, function()
    ticks = ticks + 1

    if ticks >= 13 and ticks <= 18 then
      local countdown = math.max(1, math.ceil((19 - ticks) / 2))
      self.frame.title:SetText("Decision in " .. tostring(countdown))
      self.frame.subtitle:SetText("The Council counts down...")
    else
      local dots = string.rep(".", (ticks % 3) + 1)
      self.frame.subtitle:SetText("The Council deliberates" .. dots)
    end

    if ticks % 2 == 0 then
      self.tickToggle = not self.tickToggle
      if KC.CountdownProviderA and not KC.CountdownProviderA:PlayTick() and KC.CountdownProviderB then
        KC.CountdownProviderB:PlayTick()
      end
    end

    if ticks >= 18 then
      ticker:Cancel()
      FinishSpin()
    end
  end)
  self.activeTicker = ticker
end

KC:RegisterModule("Wheel", KC.Wheel)
