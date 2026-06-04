local KC = KeystoneCouncil

KC.DevPanel = {
  frame = nil,
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

function KC.DevPanel:CreateButton(parent, label, x, y, callback)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(150, 26)
  button:SetPoint("TOPLEFT", x, y)
  button:SetText(label)
  button:SetScript("OnClick", callback)
  return button
end

function KC.DevPanel:Refresh()
  if not self.frame or not self.frame.status then
    return
  end

  local keyCount = KC.KeyStore and #(KC.KeyStore:GetAll()) or 0
  local ledgerLine = KC.KeyLedger and KC.KeyLedger:GetStatusLine() or "Key ledger: unavailable"
  self.frame.status:SetText("Visible keys: " .. tostring(keyCount) .. " | " .. ledgerLine)
end

function KC.DevPanel:Create()
  if self.frame then
    return
  end

  local frame = CreateFrame("Frame", "KeystoneCouncilDevPanel", UIParent, "BackdropTemplate")
  frame:SetSize(430, 260)
  frame:SetPoint("CENTER", 120, -40)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  ApplyBackdrop(frame, 0.97)
  frame:Hide()

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  frame.title:SetPoint("TOPLEFT", 18, -18)
  frame.title:SetTextColor(1, 0.78, 0.24)
  frame.title:SetText("KSC Developer Area")

  frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 1, -6)
  frame.subtitle:SetTextColor(0.62, 0.62, 0.66)
  frame.subtitle:SetText("Fake players, keys, and stale ledger data for beta testing.")

  frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  frame.close:SetPoint("TOPRIGHT", -6, -6)

  self:CreateButton(frame, "Load Fake Party", 18, -78, function()
    KC.DevTools:AddFakeParty()
    KC.KeyList:SetView("all")
    self:Refresh()
  end)

  self:CreateButton(frame, "Load Fake Ledger", 178, -78, function()
    KC.DevTools:AddFakeLedger()
    KC.KeyList:SetView("all")
    self:Refresh()
  end)

  self:CreateButton(frame, "Add Stale Key", 18, -116, function()
    KC.DevTools:AddStaleKey()
    KC.KeyList:SetView("all")
    self:Refresh()
  end)

  self:CreateButton(frame, "Clear Dev Data", 178, -116, function()
    KC.DevTools:ClearFakeData()
    self:Refresh()
  end)

  self:CreateButton(frame, "Open Main UI", 18, -154, function()
    KC.MainFrame:Show()
    KC.KeyList:SetView("all")
    self:Refresh()
  end)

  self:CreateButton(frame, "Diagnostics", 178, -154, function()
    KC.Diagnostics:Print()
    KC.Diagnostics:Validate()
    self:Refresh()
  end)

  frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.status:SetPoint("BOTTOMLEFT", 18, 20)
  frame.status:SetTextColor(0.62, 0.62, 0.66)
  frame.status:SetWidth(388)
  frame.status:SetJustifyH("LEFT")

  self.frame = frame
end

function KC.DevPanel:Toggle()
  if not self.frame then
    self:Create()
  end

  if self.frame:IsShown() then
    self.frame:Hide()
  else
    self:Refresh()
    self.frame:Show()
  end
end

function KC.DevPanel:OnEnable()
  KC.EventBus:On(KC.EVENTS.KEYS_CHANGED, self, function(owner)
    owner:Refresh()
  end)
end

KC:RegisterModule("DevPanel", KC.DevPanel)
