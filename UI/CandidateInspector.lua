local KC = KeystoneCouncil

KC.CandidateInspector = {
  frame = nil,
  rows = {},
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

function KC.CandidateInspector:BuildRows()
  local candidates = {}
  local candidateMap = {}
  local candidateSource = "party"
  if KC.Modes and KC.Modes.GetCandidateKeys then
    candidates, candidateSource = KC.Modes:GetCandidateKeys()
  end

  for _, key in ipairs(candidates or {}) do
    candidateMap[key.id] = true
  end

  local rows = {}
  for _, key in ipairs(KC.KeyStore:GetAll()) do
    local bucket = KC.Util:GetSocialBucket(key.ownerName, key.ownerRealm)
    local eligible = candidateMap[key.id] == true
    local reason = eligible and ("eligible: " .. tostring(candidateSource or "party")) or ("excluded: " .. tostring(key.isStale and "stale" or bucket or "other"))
    rows[#rows + 1] = {
      owner = key.ownerName or "Unknown",
      dungeon = KC.DungeonRegistry:GetShortName(key.dungeonID),
      level = key.level or 0,
      source = key.source or "Unknown",
      bucket = bucket or "other",
      eligible = eligible,
      reason = reason,
    }
  end

  return rows
end

function KC.CandidateInspector:Create()
  if self.frame then
    return
  end

  local frame = CreateFrame("Frame", "KeystoneCouncilCandidateInspector", UIParent, "BackdropTemplate")
  frame:SetSize(620, 390)
  frame:SetPoint("CENTER", 100, 20)
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
  frame.title:SetText("Candidate Inspector")

  frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 1, -4)
  frame.subtitle:SetTextColor(0.62, 0.62, 0.66)
  frame.subtitle:SetText("Shows every known key and whether Council modes can choose it.")

  frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  frame.close:SetPoint("TOPRIGHT", -6, -6)

  local headers = {
    { text = "Owner", x = 18 },
    { text = "Key", x = 140 },
    { text = "Source", x = 300 },
    { text = "Bucket", x = 408 },
    { text = "Status", x = 490 },
  }

  for _, header in ipairs(headers) do
    local font = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    font:SetPoint("TOPLEFT", header.x, -70)
    font:SetTextColor(0.62, 0.62, 0.66)
    font:SetText(header.text)
  end

  for index = 1, 10 do
    local row = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    row:SetHeight(26)
    row:SetPoint("TOPLEFT", 18, -88 - ((index - 1) * 28))
    row:SetPoint("TOPRIGHT", -18, -88 - ((index - 1) * 28))
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    row:SetBackdropColor(0.13, 0.14, 0.17, 0.78)

    row.owner = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.owner:SetPoint("LEFT", 8, 0)
    row.owner:SetWidth(110)
    row.owner:SetJustifyH("LEFT")

    row.key = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.key:SetPoint("LEFT", 122, 0)
    row.key:SetWidth(150)
    row.key:SetJustifyH("LEFT")

    row.source = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.source:SetPoint("LEFT", 282, 0)
    row.source:SetWidth(100)
    row.source:SetJustifyH("LEFT")

    row.bucket = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.bucket:SetPoint("LEFT", 390, 0)
    row.bucket:SetWidth(74)
    row.bucket:SetJustifyH("LEFT")

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.status:SetPoint("LEFT", 472, 0)
    row.status:SetWidth(120)
    row.status:SetJustifyH("LEFT")

    self.rows[index] = row
  end

  self.frame = frame
end

function KC.CandidateInspector:Refresh()
  if not self.frame then
    return
  end

  local rows = self:BuildRows()
  for index, row in ipairs(self.rows) do
    local data = rows[index]
    if data then
      row.owner:SetText(data.owner)
      row.key:SetText("+" .. tostring(data.level) .. " " .. tostring(data.dungeon))
      row.source:SetText(data.source)
      row.bucket:SetText(data.bucket)
      row.status:SetText(data.reason)
      if data.eligible then
        row.status:SetTextColor(0.25, 0.85, 0.55)
      else
        row.status:SetTextColor(0.95, 0.45, 0.35)
      end
      row:Show()
    else
      row:Hide()
    end
  end
end

function KC.CandidateInspector:Toggle()
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

KC:RegisterModule("CandidateInspector", KC.CandidateInspector)
