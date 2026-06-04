local KC = KeystoneCouncil

KC.ReadyCheck = {}

function KC.ReadyCheck:Start()
  if not IsInGroup or not IsInGroup() then
    KC.Logger:Print("You are not in a group.")
    return
  end

  if DoReadyCheck then
    DoReadyCheck()
  end
end

KC:RegisterModule("ReadyCheck", KC.ReadyCheck)
