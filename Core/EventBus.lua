local KC = KeystoneCouncil

KC.EventBus = {
  listeners = {}
}

function KC.EventBus:On(eventName, owner, callback)
  if not self.listeners[eventName] then
    self.listeners[eventName] = {}
  end

  table.insert(self.listeners[eventName], {
    owner = owner,
    callback = callback
  })
end

function KC.EventBus:Emit(eventName, ...)
  local listeners = self.listeners[eventName]
  if not listeners then
    return
  end

  for _, listener in ipairs(listeners) do
    local ok, err = pcall(listener.callback, listener.owner, ...)
    if not ok then
      KC.Logger:Error("Event failed: " .. eventName .. " - " .. tostring(err))
    end
  end
end

