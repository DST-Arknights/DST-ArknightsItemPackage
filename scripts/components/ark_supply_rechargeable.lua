local function NonNegative(value)
  if type(value) ~= "number" or value ~= value or value <= 0 or value == math.huge then
    return 0
  end
  return value
end

local ArkSupplyRechargeable = Class(function(self, inst)
  self.inst = inst
  self.rechargehandlers = {}
  self.rechargeorder = {}
end)

-- AddRechargeHandler(key, fn) or AddRechargeHandler(fn).
-- fn(inst, charger, availableCharge) returns consumedCharge.
-- A fresh opaque key makes anonymous registrations independent without collisions.
function ArkSupplyRechargeable:AddRechargeHandler(key, fn)
  if type(key) == "function" and fn == nil then
    fn = key
    key = nil
  end
  assert(type(fn) == "function", "Recharge handler must be a function.")
  if key == nil then
    key = {}
  end

  if self.rechargehandlers[key] == nil then
    self.rechargeorder[#self.rechargeorder + 1] = key
  end
  self.rechargehandlers[key] = fn
  return key
end

function ArkSupplyRechargeable:RemoveRechargeHandler(key)
  if self.rechargehandlers[key] == nil then
    return
  end
  self.rechargehandlers[key] = nil
  for index, registered in ipairs(self.rechargeorder) do
    if registered == key then
      table.remove(self.rechargeorder, index)
      return
    end
  end
end

function ArkSupplyRechargeable:Recharge(charger, availableCharge)
  local remaining = NonNegative(availableCharge)
  if remaining <= 0 then
    return 0
  end

  -- Keep this round's order stable if a callback changes registrations.
  local order = {}
  for index, key in ipairs(self.rechargeorder) do
    order[index] = key
  end

  local total = 0
  for _, key in ipairs(order) do
    if remaining <= 0 then
      break
    end
    local fn = self.rechargehandlers[key]
    if fn ~= nil then
      local consumedCharge = math.min(remaining, NonNegative(fn(self.inst, charger, remaining)))
      total = total + consumedCharge
      remaining = remaining - consumedCharge
    end
  end
  return math.min(total, availableCharge)
end

return ArkSupplyRechargeable
