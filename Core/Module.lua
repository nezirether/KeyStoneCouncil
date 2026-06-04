local KC = KeystoneCouncil

KC.modules = KC.modules or {}
KC.moduleOrder = KC.moduleOrder or {}
KC.moduleStatus = KC.moduleStatus or {}

function KC:RegisterModule(name, module)
  if not name or name == "" or type(module) ~= "table" then
    if KC.Logger then
      KC.Logger:Error("Invalid module registration ignored: " .. tostring(name))
    end
    return
  end

  if self.modules[name] then
    KC.Logger:Error("Duplicate module ignored: " .. tostring(name))
    return
  end

  module.name = name
  self.modules[name] = module
  self.moduleStatus[name] = "registered"
  table.insert(self.moduleOrder, name)
end

function KC:InitializeModules()
  for _, name in ipairs(self.moduleOrder) do
    local module = self.modules[name]
    if module and module.OnInitialize then
      local ok, err = pcall(module.OnInitialize, module)
      if not ok then
        self.moduleStatus[name] = "initialize-failed"
        KC.Logger:Error("Initialize failed for " .. name .. ": " .. tostring(err))
      else
        self.moduleStatus[name] = "initialized"
      end
    elseif module then
      self.moduleStatus[name] = "initialized"
    end
  end
end

function KC:EnableModules()
  for _, name in ipairs(self.moduleOrder) do
    local module = self.modules[name]
    if module and module.OnEnable then
      local ok, err = pcall(module.OnEnable, module)
      if not ok then
        self.moduleStatus[name] = "enable-failed"
        KC.Logger:Error("Enable failed for " .. name .. ": " .. tostring(err))
      else
        self.moduleStatus[name] = "enabled"
      end
    elseif module then
      self.moduleStatus[name] = "enabled"
    end
  end
end

function KC:GetModuleStatusRows()
  local rows = {}
  for _, name in ipairs(self.moduleOrder or {}) do
    rows[#rows + 1] = {
      name = name,
      status = self.moduleStatus and self.moduleStatus[name] or "unknown",
    }
  end
  return rows
end
