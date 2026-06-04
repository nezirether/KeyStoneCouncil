local KC = KeystoneCouncil

KC.MinimapButton = {
  button = nil,
}

local function ApplyBackdrop(frame)
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(0.12, 0.13, 0.16, 0.96)
  frame:SetBackdropBorderColor(1, 0.78, 0.24, 0.9)
end

function KC.MinimapButton:Create()
  if self.button or not Minimap then
    return
  end

  local button = CreateFrame("Button", "KeystoneCouncilMinimapButton", Minimap, "BackdropTemplate")
  button:SetSize(30, 30)
  button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -6, 6)
  ApplyBackdrop(button)

  button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  button.text:SetPoint("CENTER")
  button.text:SetTextColor(1, 0.82, 0.28)
  button.text:SetText("KSC")

  button:SetScript("OnClick", function()
    KC.MainFrame:Toggle()
  end)

  self.button = button
  self:RefreshVisibility()
end

function KC.MinimapButton:RefreshVisibility()
  if not self.button then
    self:Create()
  end

  if not self.button then
    return
  end

  if KeystoneCouncilDB and KeystoneCouncilDB.profile and KeystoneCouncilDB.profile.options and KeystoneCouncilDB.profile.options.showMinimapButton ~= false then
    self.button:Show()
  else
    self.button:Hide()
  end
end

function KC.MinimapButton:OnEnable()
  self:Create()
end

KC:RegisterModule("MinimapButton", KC.MinimapButton)
