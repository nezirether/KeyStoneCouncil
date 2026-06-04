local KC = KeystoneCouncil

KC.StreamerOverlay = {}

function KC.StreamerOverlay:Create()
  if self.frame then
    return
  end

  local frame = CreateFrame("Frame", "KeystoneCouncilStreamerOverlay", UIParent, "BackdropTemplate")
  frame:SetSize(520, 150)
  frame:SetPoint("TOP", UIParent, "TOP", 0, -90)
  frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
  frame:SetBackdropColor(0.05, 0.05, 0.06, 0.88)
  frame:Hide()

  frame.kicker = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.kicker:SetPoint("TOP", 0, -18)
  frame.kicker:SetTextColor(1, 0.78, 0.24)
  frame.kicker:SetText("THE COUNCIL HAS SPOKEN")

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  frame.title:SetPoint("TOP", frame.kicker, "BOTTOM", 0, -14)
  frame.title:SetTextColor(1, 0.95, 0.82)

  frame.owner = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.owner:SetPoint("TOP", frame.title, "BOTTOM", 0, -10)
  frame.owner:SetTextColor(0.62, 0.75, 1)

  self.frame = frame
end

function KC.StreamerOverlay:ShowResult(result, force)
  if not force and not KeystoneCouncilDB.profile.streamerMode then
    return
  end

  self:Create()
  if not self.frame then
    return
  end

  self.frame.title:SetText("+" .. tostring(result.level or "?") .. " " .. tostring(result.dungeonName or "Unknown"))
  self.frame.owner:SetText(tostring(result.ownerName or "Unknown"))
  self.frame:Show()
  local function HideOverlay()
    if self.frame then
      self.frame:Hide()
    end
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(8, HideOverlay)
  end
end

function KC.StreamerOverlay:Preview()
  self:ShowResult({
    level = 16,
    dungeonName = "Nexus-Point Xenas",
    ownerName = "Nezmonk",
  }, true)
end

KC:RegisterModule("StreamerOverlay", KC.StreamerOverlay)
