local function ClampNonNegative(value)
  value = tonumber(value) or 0
  if value < 0 then
    return 0
  end
  return value
end

local function ClampAcceptedAmount(value, limit)
  value = ClampNonNegative(value)
  if limit ~= nil then
    value = math.min(value, ClampNonNegative(limit))
  end
  return value
end

local ArkSupplyRechargeable = Class(function(self, inst)
  self.inst = inst
  self.canrechargefn = nil
  self.getrechargeamountfn = nil
  self.rechargefn = nil
  self.rechargeamountproviders = {}
  self.rechargehandlers = {}
  self.rechargegroups = {}
end)

function ArkSupplyRechargeable:SetCanRechargeFn(fn)
  self.canrechargefn = fn
end

function ArkSupplyRechargeable:SetGetRechargeAmountFn(fn)
  self.getrechargeamountfn = fn
end

function ArkSupplyRechargeable:SetRechargeFn(fn)
  self.rechargefn = fn
end

function ArkSupplyRechargeable:AddRechargeGroup(key, defs)
  if key == nil then
    return
  end

  if defs == nil then
    self.rechargegroups[key] = nil
    return
  end

  self.rechargegroups[key] = {
    getrechargeamountfn = defs.getrechargeamountfn,
    rechargefn = defs.rechargefn,
  }
end

function ArkSupplyRechargeable:RemoveRechargeGroup(key)
  self.rechargegroups[key] = nil
end

function ArkSupplyRechargeable:AddRechargeAmountProvider(key, fn)
  self.rechargeamountproviders[key] = fn
end

function ArkSupplyRechargeable:RemoveRechargeAmountProvider(key)
  self.rechargeamountproviders[key] = nil
end

function ArkSupplyRechargeable:AddRechargeHandler(key, fn)
  self.rechargehandlers[key] = fn
end

function ArkSupplyRechargeable:RemoveRechargeHandler(key)
  self.rechargehandlers[key] = nil
end

function ArkSupplyRechargeable:GetRechargeAmount(charger, data)
  local total = 0

  if self.getrechargeamountfn ~= nil then
    total = total + ClampNonNegative(self.getrechargeamountfn(self.inst, charger, data))
  end

  for _, fn in pairs(self.rechargeamountproviders) do
    total = total + ClampNonNegative(fn(self.inst, charger, data))
  end

  for _, group in pairs(self.rechargegroups) do
    if group.getrechargeamountfn ~= nil then
      total = total + ClampNonNegative(group.getrechargeamountfn(self.inst, charger, data))
    end
  end

  return total
end

function ArkSupplyRechargeable:CanRecharge(charger, amount, data)
  amount = ClampNonNegative(amount)
  if amount <= 0 then
    return false
  end

  if self.canrechargefn ~= nil then
    return self.canrechargefn(self.inst, charger, amount, data) == true
  end

  local hasgroupamountprovider = false
  for _, group in pairs(self.rechargegroups) do
    if group.getrechargeamountfn ~= nil then
      hasgroupamountprovider = true
      break
    end
  end

  local hasamountprovider = self.getrechargeamountfn ~= nil
    or next(self.rechargeamountproviders) ~= nil
    or hasgroupamountprovider
  if hasamountprovider then
    return self:GetRechargeAmount(charger, data) > 0
  end

  if self.rechargefn ~= nil or next(self.rechargehandlers) ~= nil then
    return true
  end

  for _, group in pairs(self.rechargegroups) do
    if group.rechargefn ~= nil then
      return true
    end
  end

  return false
end

function ArkSupplyRechargeable:Recharge(charger, amount, data)
  amount = ClampNonNegative(amount)
  if amount <= 0 or not self:CanRecharge(charger, amount, data) then
    return 0
  end

  local rechargeamount = self:GetRechargeAmount(charger, data)
  if rechargeamount > 0 then
    amount = math.min(amount, rechargeamount)
  end
  if amount <= 0 then
    return 0
  end

  local accepted = 0
  local remaining = amount

  if self.rechargefn ~= nil and remaining > 0 then
    local used = ClampAcceptedAmount(self.rechargefn(self.inst, charger, remaining, data), remaining)
    accepted = accepted + used
    remaining = remaining - used
  end

  for _, fn in pairs(self.rechargehandlers) do
    if remaining <= 0 then
      break
    end
    local used = ClampAcceptedAmount(fn(self.inst, charger, remaining, data), remaining)
    accepted = accepted + used
    remaining = remaining - used
  end

  for _, group in pairs(self.rechargegroups) do
    if remaining <= 0 then
      break
    end
    if group.rechargefn ~= nil then
      local used = ClampAcceptedAmount(group.rechargefn(self.inst, charger, remaining, data), remaining)
      accepted = accepted + used
      remaining = remaining - used
    end
  end

  return accepted
end

return ArkSupplyRechargeable