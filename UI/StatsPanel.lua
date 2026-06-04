local KC = KeystoneCouncil

KC.StatsPanel = {}

function KC.StatsPanel:Create(parent)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 18, 74)
  frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -30, 74)
  frame:SetHeight(18)

  frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.text:SetPoint("LEFT")
  frame.text:SetPoint("RIGHT")
  frame.text:SetJustifyH("LEFT")
  frame.text:SetTextColor(0.62, 0.62, 0.66)

  self.frame = frame
  self:Refresh()
end

function KC.StatsPanel:Refresh()
  if not self.frame then
    return
  end

  local summary = KC.StatsStore:GetSummary()
  if summary.totalSelections == 0 then
    self.frame.text:SetText("No Council history yet")
    return
  end

  local topDungeon = summary.topDungeon and summary.topDungeon.name or "None"
  self.frame.text:SetText(summary.totalSelections .. " selections recorded - most chosen: " .. topDungeon)
end

KC:RegisterModule("StatsPanel", KC.StatsPanel)
