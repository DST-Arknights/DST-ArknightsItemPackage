local GLOBAL = rawget(_G, "GLOBAL") or _G
local TUNING = rawget(_G, "TUNING")
local Symbol = rawget(_G, "Symbol")

local ControlDefinitionsSymbol = Symbol("ARK_CONTROL_DEFINITIONS")
TUNING[ControlDefinitionsSymbol] = TUNING[ControlDefinitionsSymbol] or {}

local function GetTheWorld()
  return rawget(_G, "TheWorld")
end

local function NormalizeFxEntry(entry)
  if type(entry) == "string" then
    return {
      prefab = entry,
      x = 0,
      y = 0,
      z = 0,
    }
  end

  assert(type(entry) == "table", "Control fx entry must be a string or table.")
  local offset = entry.offset or entry
  local prefab = entry.prefab
  assert(type(prefab) == "string" and prefab ~= "", "Control fx entry missing prefab.")
  return {
    prefab = prefab,
    x = offset.x or 0,
    y = offset.y or 0,
    z = offset.z or 0,
  }
end

local function NormalizeFxData(fx)
  if fx == nil then
    return {}
  end

  if type(fx) == "string" then
    return { NormalizeFxEntry(fx) }
  end

  assert(type(fx) == "table", "Control fx must be nil, string, or table.")

  if fx.prefab ~= nil or fx.offset ~= nil or fx.x ~= nil or fx.y ~= nil or fx.z ~= nil then
    return { NormalizeFxEntry(fx) }
  end

  local normalized = {}
  for index, entry in ipairs(fx) do
    normalized[index] = NormalizeFxEntry(entry)
  end
  return normalized
end

local function NormalizeControlDefinition(key, definition)
  assert(type(key) == "string" and key ~= "", "Control key is invalid.")
  assert(type(definition) == "table", "Control definition must be a table.")

  local duration = definition.duration
  if duration ~= nil then
    assert(type(duration) == "number", "Control duration must be a number.")
  end

  local onApply = definition.onApply
  local onRemove = definition.onRemove
  if onApply ~= nil then
    assert(type(onApply) == "function", "Control onApply must be a function.")
  end
  if onRemove ~= nil then
    assert(type(onRemove) == "function", "Control onRemove must be a function.")
  end

  return {
    key = key,
    duration = duration,
    fx = NormalizeFxData(definition.fx),
    onApply = onApply,
    onRemove = onRemove,
  }
end

function GLOBAL.RegisterControlDefinition(key, definition)
  assert(TUNING[ControlDefinitionsSymbol][key] == nil, "Control definition already registered: " .. tostring(key))
  TUNING[ControlDefinitionsSymbol][key] = NormalizeControlDefinition(key, definition)
end

function GLOBAL.GetControlDefinition(key)
  local definition = TUNING[ControlDefinitionsSymbol][key]
  assert(definition ~= nil, "No control definition found for key: " .. tostring(key))
  return definition
end

local function EnsureControllable(target)
  assert(target ~= nil and target:IsValid(), "ApplyControl target is invalid.")
  local world = GetTheWorld()
  assert(world == nil or world.ismastersim, "ApplyControl must run on master sim.")
  assert(target.AddComponent ~= nil, "ApplyControl target cannot receive components.")

  if target.components.controllable == nil then
    target:AddComponent("controllable")
  end
  return target.components.controllable
end

function GLOBAL.ApplyControl(target, key, duration)
  assert(type(key) == "string" and key ~= "", "ApplyControl missing key.")
  local component = EnsureControllable(target)
  return component:ApplyControl(key, duration)
end

function GLOBAL.RemoveControl(target, key)
  assert(target ~= nil and target:IsValid(), "RemoveControl target is invalid.")
  assert(type(key) == "string" and key ~= "", "RemoveControl missing key.")
  if target.components == nil or target.components.controllable == nil then
    return false
  end

  return target.components.controllable:RemoveControl(key)
end

function GLOBAL.ClearControls(target)
  assert(target ~= nil and target:IsValid(), "ClearControls target is invalid.")
  if target.components == nil or target.components.controllable == nil then
    return false
  end

  return target.components.controllable:ClearControls()
end