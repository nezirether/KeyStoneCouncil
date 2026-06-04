local KC = KeystoneCouncil

KC.VotePanel = {}

function KC.VotePanel:Create(parent)
  local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 18, 52)
  frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -30, 52)
  frame:SetHeight(26)
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(0.10, 0.08, 0.04, 0.74)
  frame:SetBackdropBorderColor(0.42, 0.36, 0.22, 0.75)

  frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.text:SetPoint("LEFT", 8, 0)
  frame.text:SetPoint("RIGHT", -8, 0)
  frame.text:SetJustifyH("LEFT")
  frame.text:SetTextColor(0.62, 0.62, 0.66)
  self.frame = frame
end

function KC.VotePanel:Refresh()
  if not self.frame then
    return
  end

  local count = 0
  for _ in pairs(KeystoneCouncilDB.session.votes or {}) do
    count = count + 1
  end

  if KC.SessionStore and KC.SessionStore:IsVoteOpen() then
    local mode = KC.Modes and KC.Modes:GetMode() or "raffle"
    local label = mode == "majority" and "Majority vote" or "Raffle"
    self.frame.text:SetText(label .. " open: click Vote on an eligible row. " .. tostring(count) .. " vote" .. (count == 1 and "" or "s") .. " recorded.")
    self.frame.text:SetTextColor(1, 0.78, 0.24)
  else
    self.frame.text:SetText(tostring(count) .. " vote" .. (count == 1 and "" or "s") .. " recorded")
    self.frame.text:SetTextColor(0.62, 0.62, 0.66)
  end
end

KC:RegisterModule("VotePanel", KC.VotePanel)
