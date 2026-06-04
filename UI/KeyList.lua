local KC = KeystoneCouncil

KC.KeyList = {
  rows = {},
  tabs = {},
  currentView = "party",
  filteredKeys = {},
  rowHeight = 28,
  rowSpacing = 4,
}

local views = {
  { id = "all", label = "All" },
  { id = "party", label = "Party" },
  { id = "friends", label = "Friends" },
  { id = "guild", label = "Guild" },
}

local function ClassColor(classFile)
  local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if color then
    return color.r, color.g, color.b
  end
  return 0.95, 0.92, 0.84
end

local SafeSetBackdrop
local SafeSetBackdropColor
local SafeSetBackdropBorderColor

local function StyleTab(tab, selected)
  if selected then
    SafeSetBackdropColor(tab, 0.34, 0.08, 0.08, 0.92)
    SafeSetBackdropBorderColor(tab, 0.78, 0.56, 0.16, 0.95)
    tab.text:SetTextColor(1, 0.82, 0.28)
  else
    SafeSetBackdropColor(tab, 0.13, 0.14, 0.17, 0.82)
    SafeSetBackdropBorderColor(tab, 0.42, 0.36, 0.22, 0.85)
    tab.text:SetTextColor(0.78, 0.74, 0.64)
  end
end

SafeSetBackdrop = function(frame, backdrop)
  if frame and frame.SetBackdrop then
    frame:SetBackdrop(backdrop)
  end
end

SafeSetBackdropColor = function(frame, ...)
  if frame and frame.SetBackdropColor then
    frame:SetBackdropColor(...)
  end
end

SafeSetBackdropBorderColor = function(frame, ...)
  if frame and frame.SetBackdropBorderColor then
    frame:SetBackdropBorderColor(...)
  end
end

local function ValueOrDash(value)
  value = tonumber(value)
  if value and value > 0 then
    return tostring(math.floor(value + 0.5))
  end
  return "-"
end

function KC.KeyList:Create(parent)
  self.parent = parent
  self.container = CreateFrame("Frame", nil, parent)
  self.container:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, -124)
  self.container:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -30, 116)

  local level = self.container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  level:SetPoint("TOPLEFT", 6, 0)
  level:SetWidth(46)
  level:SetJustifyH("LEFT")
  level:SetTextColor(0.62, 0.62, 0.66)
  level:SetText("Level")

  local dungeon = self.container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  dungeon:SetPoint("TOPLEFT", 66, 0)
  dungeon:SetWidth(160)
  dungeon:SetJustifyH("LEFT")
  dungeon:SetTextColor(0.62, 0.62, 0.66)
  dungeon:SetText("Dungeon")

  local character = self.container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  character:SetPoint("TOPLEFT", 240, 0)
  character:SetWidth(130)
  character:SetJustifyH("LEFT")
  character:SetTextColor(0.62, 0.62, 0.66)
  character:SetText("Character")

  local score = self.container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  score:SetPoint("TOPRIGHT", -104, 0)
  score:SetWidth(76)
  score:SetJustifyH("RIGHT")
  score:SetTextColor(0.62, 0.62, 0.66)
  score:SetText("M+ Score")

  local weekly = self.container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  weekly:SetPoint("TOPRIGHT", -28, 0)
  weekly:SetWidth(70)
  weekly:SetJustifyH("RIGHT")
  weekly:SetTextColor(0.62, 0.62, 0.66)
  weekly:SetText("Weekly Best")

  self.status = self.container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  self.status:SetPoint("BOTTOMLEFT", self.container, "BOTTOMLEFT", 0, 0)
  self.status:SetPoint("BOTTOMRIGHT", self.container, "BOTTOMRIGHT", 0, 0)
  self.status:SetJustifyH("LEFT")
  self.status:SetTextColor(0.62, 0.62, 0.66)

  self:CreateTabs()
  self:CreateScrollArea()

  for index = 1, 16 do
    self.rows[index] = self:CreateRow(index)
  end

  self:SetView("party")
end

function KC.KeyList:CreateTabs()
  local previous
  for _, view in ipairs(views) do
    local tab = CreateFrame("Button", nil, self.container, "BackdropTemplate")
    tab:SetSize(72, 22)
    if previous then
      tab:SetPoint("TOPLEFT", previous, "TOPRIGHT", 6, 0)
    else
      tab:SetPoint("TOPLEFT", self.container, "TOPLEFT", 0, -18)
    end

    SafeSetBackdrop(tab, {
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
    })

    tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.text:SetPoint("CENTER")
    tab.text:SetText(view.label)

    tab:SetScript("OnClick", function()
      self:SetView(view.id)
    end)

    self.tabs[view.id] = tab
    previous = tab
  end
end

function KC.KeyList:CreateScrollArea()
  self.viewport = CreateFrame("Frame", nil, self.container, "BackdropTemplate")
  self.viewport:SetPoint("TOPLEFT", self.container, "TOPLEFT", 0, -46)
  self.viewport:SetPoint("BOTTOMRIGHT", self.container, "BOTTOMRIGHT", -18, 18)
  self.viewport:SetClipsChildren(true)
  self.viewport:EnableMouseWheel(true)
  SafeSetBackdrop(self.viewport, { bgFile = "Interface\\Buttons\\WHITE8X8" })
  SafeSetBackdropColor(self.viewport, 0.09, 0.1, 0.13, 0.3)
  self.viewport:SetScript("OnMouseWheel", function(_, delta)
    self:ScrollBy(-delta * (self.rowHeight + self.rowSpacing))
  end)

  self.content = CreateFrame("Frame", nil, self.viewport)
  self.content:SetPoint("TOPLEFT", self.viewport, "TOPLEFT", 0, 0)
  self.content:SetPoint("TOPRIGHT", self.viewport, "TOPRIGHT", 0, 0)
  self.content:SetHeight(self.viewport:GetHeight())

  self.scrollBar = CreateFrame("Slider", nil, self.container, "BackdropTemplate")
  self.scrollBar:SetPoint("TOPLEFT", self.viewport, "TOPRIGHT", 3, -2)
  self.scrollBar:SetPoint("BOTTOMLEFT", self.viewport, "BOTTOMRIGHT", 3, 2)
  self.scrollBar:SetWidth(12)
  self.scrollBar:SetMinMaxValues(0, 0)
  self.scrollBar:SetValueStep(1)
  self.scrollBar:SetObeyStepOnDrag(false)
  self.scrollBar:SetOrientation("VERTICAL")
  self.scrollBar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
  SafeSetBackdrop(self.scrollBar, {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
  })
  SafeSetBackdropColor(self.scrollBar, 0.08, 0.09, 0.11, 0.86)
  SafeSetBackdropBorderColor(self.scrollBar, 0.24, 0.22, 0.2, 0.9)
  self.scrollBar:SetScript("OnValueChanged", function(_, value)
    self:SetScrollOffset(value or 0)
  end)
  self.scrollBar:Hide()
end

function KC.KeyList:CreateRow(index)
  local row = CreateFrame("Button", nil, self.content, "BackdropTemplate")
  row:SetHeight(self.rowHeight)
  row:SetPoint("TOPLEFT", 0, -((index - 1) * (self.rowHeight + self.rowSpacing)))
  row:SetPoint("TOPRIGHT", 0, -((index - 1) * (self.rowHeight + self.rowSpacing)))
  SafeSetBackdrop(row, { bgFile = "Interface\\Buttons\\WHITE8X8" })
  SafeSetBackdropColor(row, 0.13, 0.14, 0.17, 0.78)

  row.owner = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.owner:SetPoint("LEFT", 240, 0)
  row.owner:SetWidth(124)
  row.owner:SetJustifyH("LEFT")

  row.dungeon = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.dungeon:SetPoint("LEFT", 66, 0)
  row.dungeon:SetWidth(160)
  row.dungeon:SetJustifyH("LEFT")
  row.dungeon:SetTextColor(0.95, 0.92, 0.84)

  row.level = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  row.level:SetPoint("LEFT", 10, 0)
  row.level:SetWidth(42)
  row.level:SetJustifyH("LEFT")
  row.level:SetTextColor(1, 0.78, 0.24)

  row.score = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.score:SetPoint("RIGHT", -104, 0)
  row.score:SetWidth(72)
  row.score:SetJustifyH("RIGHT")
  row.score:SetTextColor(1, 0.78, 0.24)

  row.weeklyBest = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.weeklyBest:SetPoint("RIGHT", -34, 0)
  row.weeklyBest:SetWidth(54)
  row.weeklyBest:SetJustifyH("RIGHT")
  row.weeklyBest:SetTextColor(0.95, 0.92, 0.84)

  row.vote = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  row.vote:SetSize(48, 22)
  row.vote:SetPoint("RIGHT", -6, 0)
  row.vote:SetText("Vote")
  row.vote:Hide()
  row.vote:SetScript("OnClick", function()
    if row.keyID then
      KC.VoteEngine:Vote(row.keyID)
      KC.Toasts:Show("Vote recorded.")
    end
  end)

  return row
end

function KC.KeyList:SetView(view)
  self.currentView = self.tabs[view] and view or "party"
  self.scrollOffset = 0
  if self.scrollBar then
    self.scrollBar:SetValue(0)
  end

  for id, tab in pairs(self.tabs) do
    StyleTab(tab, id == self.currentView)
  end

  self:Refresh()
end

function KC.KeyList:SetScrollOffset(offset)
  if not self.content then
    return
  end

  offset = math.max(0, math.floor(offset or 0))
  self.scrollOffset = offset
  self:Refresh(self.filteredKeys)
end

function KC.KeyList:ScrollBy(delta)
  if not self.scrollBar or not self.scrollBar:IsShown() then
    return
  end

  local _, maxValue = self.scrollBar:GetMinMaxValues()
  local nextValue = math.max(0, math.min(maxValue, (self.scrollBar:GetValue() or 0) + delta))
  self.scrollBar:SetValue(nextValue)
end

local function MergeVisibleKeys(view)
  local merged = {}

  local function AddRows(rows)
    for _, key in ipairs(rows or {}) do
      merged[#merged + 1] = key
    end
  end

  -- Always include live session keys first. These are the most reliable keys
  -- for the current player and current party. The old All view could appear
  -- empty when the ledger had not hydrated yet even though KeyStore had keys.
  if KC.KeyStore and KC.KeyStore.GetByView then
    AddRows(KC.KeyStore:GetByView(view))
  end

  -- Then include the persistent ledger so All/Friends/Guild can still show
  -- keys learned earlier this week. Deduplicate below keeps one row per owner.
  if KC.KeyLedger and KC.KeyLedger.GetByView then
    AddRows(KC.KeyLedger:GetByView(view))
  end

  if KC.KeyStore and KC.KeyStore.DeduplicateByOwner then
    return KC.KeyStore:DeduplicateByOwner(merged)
  end

  return merged
end

function KC.KeyList:Refresh(keys)
  if not self.container then
    return
  end

  if keys then
  else
    keys = MergeVisibleKeys(self.currentView or "party")
  end
  self.filteredKeys = keys or {}
  keys = self.filteredKeys

  if self.status then
    local ledgerLine = KC.KeyLedger and KC.KeyLedger:GetStatusLine() or tostring(#keys) .. " visible keys"
    local sortMode = KC.KeyStore and KC.KeyStore.GetSortMode and KC.KeyStore:GetSortMode() or "level"
    if #keys == 0 then
      self.status:SetText("No " .. tostring(self.currentView or "party") .. " keys visible. Run /kc refresh or join a party with visible keys. Sort: " .. tostring(sortMode))
    else
      self.status:SetText(ledgerLine .. " | view " .. tostring(self.currentView or "party") .. " | sort " .. tostring(sortMode))
    end
  end

  local rowSpan = self.rowHeight + self.rowSpacing
  local totalHeight = math.max(self.viewport:GetHeight() or 1, #keys * rowSpan)
  self.content:SetHeight(totalHeight)

  local maxOffset = math.max(0, totalHeight - (self.viewport:GetHeight() or 1))
  self.scrollBar:SetMinMaxValues(0, maxOffset)

  if maxOffset > 0 then
    self.scrollBar:Show()
  else
    self.scrollBar:Hide()
  end

  local currentOffset = math.max(0, math.min(maxOffset, self.scrollOffset or self.scrollBar:GetValue() or 0))
  self.scrollOffset = currentOffset
  if self.scrollBar:GetValue() ~= currentOffset then
    self.scrollBar:SetValue(currentOffset)
    return
  end

  local startIndex = math.floor(currentOffset / rowSpan) + 1
  local rowOffset = currentOffset % rowSpan
  local votingOpen = KC.Modes and KC.Modes.IsVoteMode and KC.Modes:IsVoteMode() and KC.SessionStore and KC.SessionStore:IsVoteOpen()
  local voteCandidates = {}
  if votingOpen and KC.Modes and KC.Modes.GetCandidateKeys then
    local candidates = KC.Modes:GetCandidateKeys()
    for _, candidate in ipairs(candidates or {}) do
      voteCandidates[candidate.id] = true
    end
  end

  for index, row in ipairs(self.rows) do
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -(((index - 1) * rowSpan) + rowOffset))
    row:SetPoint("TOPRIGHT", 0, -(((index - 1) * rowSpan) + rowOffset))

    local key = keys[startIndex + index - 1]
    if key then
      local isOnline = KC.Util:IsOwnerOnline(key)
      local r, g, b = ClassColor(key.classFile)
      if key.isStale then
        r, g, b = 0.64, 0.54, 0.36
        row:SetAlpha(0.62)
      elseif self.currentView ~= "party" and not isOnline then
        r, g, b = 0.62, 0.62, 0.66
        row:SetAlpha(0.75)
      else
        row:SetAlpha(1)
      end
      row.owner:SetText(key.ownerName or "Unknown")
      row.owner:SetTextColor(r, g, b)
      row.dungeon:SetText(KC.DungeonRegistry:GetShortName(key.dungeonID))
      row.level:SetText(tostring(key.level or "?"))
      row.score:SetText(ValueOrDash(key.score))
      row.weeklyBest:SetText(ValueOrDash(key.weeklyBest))
      row.keyID = key.id
      if not key.isStale and votingOpen and voteCandidates[key.id] then
        row.vote:Enable()
        row.vote:SetAlpha(1)
        row.vote:Show()
      else
        row.vote:Disable()
        row.vote:SetAlpha(0.45)
        row.vote:Hide()
      end
      row:Show()
    else
      row.keyID = nil
      row:SetAlpha(1)
      row.vote:Hide()
      row:Hide()
    end
  end
end

function KC.KeyList:SetVisible(isVisible)
  if not self.container then
    return
  end

  if isVisible then
    self.container:Show()
  else
    self.container:Hide()
  end
end

KC:RegisterModule("KeyList", KC.KeyList)
