local EXCLUDE_TAGS = { "INLIMBO", "FX", "NOCLICK", "DECOR", "playerghost" }

local function NonNegative(value)
  if type(value) ~= "number" or value ~= value or value <= 0 or value == math.huge then
    return 0
  end
  return value
end

local ArkSupplyCharger = Class(function(self, inst)
  self.inst = inst
  self.enabled = true
  self.range = 8
  self.scanInterval = 1
  self.chargeAmount = 5
  self.getfuelamountfn = nil
  self.consumefuelfn = nil
  self._task = nil
  self:_RefreshTask()
end)

function ArkSupplyCharger:SetFuelAmountFn(fn)
  self.getfuelamountfn = fn
end

function ArkSupplyCharger:SetConsumeFuelFn(fn)
  self.consumefuelfn = fn
end

function ArkSupplyCharger:SetEnabled(enabled)
  self.enabled = enabled ~= false
  self:_RefreshTask()
end

function ArkSupplyCharger:SetRange(range)
  self.range = NonNegative(range)
end

function ArkSupplyCharger:SetScanInterval(interval)
  self.scanInterval = math.max(0.1, NonNegative(interval))
  self:_RefreshTask()
end

function ArkSupplyCharger:SetChargeAmount(availableCharge)
  self.chargeAmount = NonNegative(availableCharge)
end

function ArkSupplyCharger:GetFuelAmount()
  if self.getfuelamountfn ~= nil then
    return NonNegative(self.getfuelamountfn(self.inst))
  end
  local fueled = self.inst.components.fueled
  return fueled ~= nil and NonNegative(fueled.currentfuel) or 0
end

function ArkSupplyCharger:ConsumeFuel(consumedCharge)
  consumedCharge = math.min(NonNegative(consumedCharge), self:GetFuelAmount())
  if consumedCharge <= 0 then
    return 0
  end

  if self.consumefuelfn ~= nil then
    return math.min(consumedCharge, NonNegative(self.consumefuelfn(self.inst, consumedCharge)))
  end
  local fueled = self.inst.components.fueled
  if fueled == nil then
    return 0
  end
  fueled:DoDelta(-consumedCharge)
  fueled:StopConsuming()
  return consumedCharge
end

function ArkSupplyCharger:TryChargeTarget(target)
  if target == nil or target == self.inst or not target:IsValid() then
    return 0
  end
  local rechargeable = target.components.ark_supply_rechargeable
  if rechargeable == nil then
    return 0
  end

  local availableCharge = math.min(self.chargeAmount, self:GetFuelAmount())
  if availableCharge <= 0 then
    return 0
  end

  local total = math.min(availableCharge, NonNegative(rechargeable:Recharge(self.inst, availableCharge)))
  if total <= 0 then
    return 0
  end

  -- Recharge returns the sum of all handlers for this entity, so settle and show it once.
  local consumedCharge = self:ConsumeFuel(total)
  if consumedCharge > 0 and target:IsValid() then
    local fx = SpawnPrefab("ark_supply_charge_number")
    if fx ~= nil then
      fx:SetCharge(target, consumedCharge)
    end
  end
  return consumedCharge
end

function ArkSupplyCharger:ScanAndCharge()
  if not self.enabled or self.range <= 0 or self.chargeAmount <= 0 or self:GetFuelAmount() <= 0 then
    return
  end

  local x, y, z = self.inst.Transform:GetWorldPosition()
  local targets = TheSim:FindEntities(x, y, z, self.range, nil, EXCLUDE_TAGS)
  for _, target in ipairs(targets) do
    if not self.enabled or not self.inst:IsValid() or self:GetFuelAmount() <= 0 then
      break
    end
    self:TryChargeTarget(target)
  end
end

function ArkSupplyCharger:_RefreshTask()
  if self._task ~= nil then
    self._task:Cancel()
    self._task = nil
  end
  if self.enabled then
    self._task = self.inst:DoPeriodicTask(self.scanInterval, function()
      self:ScanAndCharge()
    end)
  end
end

function ArkSupplyCharger:OnRemoveFromEntity()
  self.enabled = false
  self:_RefreshTask()
end

return ArkSupplyCharger
