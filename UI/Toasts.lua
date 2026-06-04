local KC = KeystoneCouncil

KC.Toasts = {
  active = nil
}

function KC.Toasts:Show(message)
  if not self.active then
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetSize(320, 44)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    frame:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
    })
    frame:SetBackdropColor(0.08, 0.09, 0.11, 0.94)
    frame:SetBackdropBorderColor(1, 0.78, 0.24, 0.85)
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.text:SetPoint("CENTER")
    self.active = frame
  end

  self.active.text:SetText(message)
  self.active:Show()
  local function HideToast()
    if self.active then
      self.active:Hide()
    end
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(3, HideToast)
  else
    HideToast()
  end
end

KC:RegisterModule("Toasts", KC.Toasts)
