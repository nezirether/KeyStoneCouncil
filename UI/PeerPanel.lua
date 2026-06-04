local KC = KeystoneCouncil

KC.PeerPanel = {
  frame = nil,
  peerRows = {},
  ackRows = {},
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

local function AgeText(timestamp)
  local age = math.max(0, time() - (tonumber(timestamp) or time()))
  if age < 60 then
    return tostring(age) .. "s"
  end
  return tostring(math.floor(age / 60)) .. "m"
end

function KC.PeerPanel:Create()
  if self.frame then
    return
  end

  local frame = CreateFrame("Frame", "KeystoneCouncilPeerPanel", UIParent, "BackdropTemplate")
  frame:SetSize(560, 390)
  frame:SetPoint("CENTER", 140, 40)
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
  frame.title:SetText("Party Sync Peers")

  frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 1, -4)
  frame.subtitle:SetTextColor(0.62, 0.62, 0.66)
  frame.subtitle:SetText("Shows KSC users, version mismatches, and acknowledgement activity.")

  frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  frame.close:SetPoint("TOPRIGHT", -6, -6)

  local headers = {
    { text = "Player", x = 18, y = -72 },
    { text = "Version", x = 174, y = -72 },
    { text = "Protocol", x = 282, y = -72 },
    { text = "Seen", x = 386, y = -72 },
    { text = "Status", x = 450, y = -72 },
  }

  for _, header in ipairs(headers) do
    local font = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    font:SetPoint("TOPLEFT", header.x, header.y)
    font:SetTextColor(0.62, 0.62, 0.66)
    font:SetText(header.text)
  end

  for index = 1, 6 do
    local row = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    row:SetHeight(26)
    row:SetPoint("TOPLEFT", 18, -90 - ((index - 1) * 28))
    row:SetPoint("TOPRIGHT", -18, -90 - ((index - 1) * 28))
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    row:SetBackdropColor(0.13, 0.14, 0.17, 0.78)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.name:SetPoint("LEFT", 8, 0)
    row.name:SetWidth(145)
    row.name:SetJustifyH("LEFT")

    row.version = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.version:SetPoint("LEFT", 156, 0)
    row.version:SetWidth(100)
    row.version:SetJustifyH("LEFT")

    row.protocol = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.protocol:SetPoint("LEFT", 264, 0)
    row.protocol:SetWidth(90)
    row.protocol:SetJustifyH("LEFT")

    row.seen = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.seen:SetPoint("LEFT", 368, 0)
    row.seen:SetWidth(58)
    row.seen:SetJustifyH("LEFT")

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.status:SetPoint("LEFT", 432, 0)
    row.status:SetWidth(90)
    row.status:SetJustifyH("LEFT")

    self.peerRows[index] = row
  end

  frame.ackTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.ackTitle:SetPoint("TOPLEFT", 18, -258)
  frame.ackTitle:SetTextColor(1, 0.78, 0.24)
  frame.ackTitle:SetText("Recent ACKs")

  for index = 1, 3 do
    local row = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row:SetPoint("TOPLEFT", 18, -280 - ((index - 1) * 20))
    row:SetTextColor(0.62, 0.62, 0.66)
    row:SetWidth(240)
    row:SetJustifyH("LEFT")
    self.ackRows[index] = row
  end

  frame.pendingTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.pendingTitle:SetPoint("TOPLEFT", 290, -258)
  frame.pendingTitle:SetTextColor(1, 0.78, 0.24)
  frame.pendingTitle:SetText("Pending / Failed")

  self.pendingRows = {}
  for index = 1, 3 do
    local row = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row:SetPoint("TOPLEFT", 290, -280 - ((index - 1) * 20))
    row:SetTextColor(0.62, 0.62, 0.66)
    row:SetWidth(240)
    row:SetJustifyH("LEFT")
    self.pendingRows[index] = row
  end

  self.frame = frame
end

function KC.PeerPanel:Refresh()
  if not self.frame then
    return
  end

  local peers = KC.PartySync and KC.PartySync:GetPeerRows() or {}
  for index, row in ipairs(self.peerRows) do
    local peer = peers[index]
    if peer then
      row.name:SetText(peer.name)
      row.version:SetText(peer.addonVersion)
      row.protocol:SetText(peer.protocolVersion)
      row.seen:SetText(AgeText(peer.lastSeen))
      row.status:SetText(peer.versionMismatch and "Mismatch" or "OK")
      if peer.versionMismatch then
        row.status:SetTextColor(0.95, 0.45, 0.35)
      else
        row.status:SetTextColor(0.25, 0.85, 0.55)
      end
      row:Show()
    else
      row:Hide()
    end
  end

  local acks = KC.PartySync and KC.PartySync:GetAckRows() or {}
  for index, row in ipairs(self.ackRows) do
    local ack = acks[index]
    if ack then
      row:SetText(tostring(ack.token) .. " | " .. tostring(ack.count))
    else
      row:SetText("")
    end
  end

  local pending = KC.PartySync and KC.PartySync:GetPendingRows() or {}
  local failed = KC.PartySync and KC.PartySync.GetFailedRows and KC.PartySync:GetFailedRows() or {}
  for index, row in ipairs(self.pendingRows or {}) do
    local item = pending[index] or failed[index - #pending]
    if item then
      local status = item.status or "failed"
      row:SetText(tostring(item.id) .. " | " .. tostring(status))
      if status == "failed" then
        row:SetTextColor(0.95, 0.45, 0.35)
      else
        row:SetTextColor(0.62, 0.62, 0.66)
      end
    else
      row:SetText("")
    end
  end
end

function KC.PeerPanel:Toggle()
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

KC:RegisterModule("PeerPanel", KC.PeerPanel)
