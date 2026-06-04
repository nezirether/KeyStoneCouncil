local KC = KeystoneCouncil

KC.WinnerBanner = {}

function KC.WinnerBanner:Create(parent)
  local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, -56)
  frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, -56)
  frame:SetHeight(54)
  frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
  frame:SetBackdropColor(0.16, 0.12, 0.06, 0.92)

  frame.kicker = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.kicker:SetPoint("TOP", 0, -6)
  frame.kicker:SetTextColor(1, 0.78, 0.24)
  frame.kicker:SetText("THE COUNCIL HAS CHOSEN")

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("TOP", frame.kicker, "BOTTOM", 0, -4)
  frame.title:SetPoint("LEFT", frame, "LEFT", 14, 0)
  frame.title:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
  frame.title:SetJustifyH("CENTER")
  frame.title:SetTextColor(1, 0.95, 0.82)

  frame.reason = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.reason:SetPoint("TOP", frame.title, "BOTTOM", 0, -3)
  frame.reason:SetTextColor(0.72, 0.72, 0.76)

  frame:Hide()
  self.frame = frame
end

function KC.WinnerBanner:ShowResult(result)
  if not self.frame then
    return
  end

  local title = tostring(result.ownerName or "Unknown") .. "'s +" .. tostring(result.level or "?") .. " " .. tostring(result.dungeonName or "Unknown")
  self.frame.title:SetText(title)
  self.frame.reason:SetText(result.reason or "The Council has spoken.")
  self.frame:Show()
  if C_Timer and C_Timer.After then
    C_Timer.After(8, function()
      if self.frame then
        self.frame:Hide()
      end
    end)
  end
end

KC:RegisterModule("WinnerBanner", KC.WinnerBanner)
