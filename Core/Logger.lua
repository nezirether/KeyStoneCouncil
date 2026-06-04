local KC = KeystoneCouncil

KC.Logger = {}

function KC.Logger:Print(message)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffc857Keystone Council:|r " .. tostring(message))
  end
end

function KC.Logger:Debug(message)
  if KeystoneCouncilDB and KeystoneCouncilDB.profile and KeystoneCouncilDB.profile.debug then
    self:Print("|cff9ca3af" .. tostring(message) .. "|r")
  end
end

function KC.Logger:Error(message)
  self:Print("|cffff5555" .. tostring(message) .. "|r")
end
