local EXCLUDE_TAGS = {"INLIMBO", "FX", "NOCLICK", "DECOR", "playerghost"}

local function ClampNonNegative(value)
  value = tonumber(value) or 0
  if value < 0 then
    return 0
  end
  return value
end

local function GetFuelAmount(inst)
  local fueled = inst.components.fueled
  if fueled == nil then
    return 0
  end

  return math.max(0, fueled.currentfuel or 0)
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
  self.range = math.max(0, ClampNonNegative(range))
end

function ArkSupplyCharger:SetScanInterval(interval)
  self.scanInterval = math.max(0.1, ClampNonNegative(interval))
  self:_RefreshTask()
end

function ArkSupplyCharger:SetChargeAmount(amount)
  self.chargeAmount = math.max(0, ClampNonNegative(amount))
end

function ArkSupplyCharger:GetFuelAmount()
  if self.getfuelamountfn ~= nil then
    return ClampNonNegative(self.getfuelamountfn(self.inst))
  end
  return GetFuelAmount(self.inst)
end

function ArkSupplyCharger:ConsumeFuel(amount)
  amount = ClampNonNegative(amount)
  if amount <= 0 then
    return 0
  end

  if self.consumefuelfn ~= nil then
    return ClampNonNegative(self.consumefuelfn(self.inst, amount))
  end

  local fueled = self.inst.components.fueled
  if fueled == nil then
    return 0
  end

  local consumed = math.min(amount, self:GetFuelAmount())
  if consumed <= 0 then
    return 0
  end

  fueled:DoDelta(-consumed)
  fueled:StopConsuming()
  return consumed
end

function ArkSupplyCharger:GetRechargeOffer(target)
  local rechargeable = target ~= nil and target.components ~= nil and target.components.ark_supply_rechargeable or nil
  if rechargeable == nil then
    return 0
  end

  local offered = math.min(self.chargeAmount, self:GetFuelAmount())
  if offered <= 0 then
    return 0
  end

  local demand = rechargeable:GetRechargeAmount(self.inst, {
    charger = self.inst,
    requested = offered,
  })
  if demand > 0 then
    offered = math.min(offered, demand)
  end
  return offered
end

function ArkSupplyCharger:TryChargeTarget(target)
  local rechargeable = target ~= nil and target.components ~= nil and target.components.ark_supply_rechargeable or nil
  if rechargeable == nil then
    return 0
  end

  local offered = self:GetRechargeOffer(target)
  if offered <= 0 then
    return 0
  end

  local data = {
    charger = self.inst,
    requested = offered,
  }
  if not rechargeable:CanRecharge(self.inst, offered, data) then
    return 0
  end

  local accepted = ClampNonNegative(rechargeable:Recharge(self.inst, offered, data))
  if accepted <= 0 then
    return 0
  end

  accepted = math.min(accepted, offered)
  return self:ConsumeFuel(accepted)
end

function ArkSupplyCharger:ScanAndCharge()
  if not self.enabled or self.range <= 0 or self.chargeAmount <= 0 then
    return
  end
  if self:GetFuelAmount() <= 0 then
    return
  end

  local x, y, z = self.inst.Transform:GetWorldPosition()
  local targets = TheSim:FindEntities(x, y, z, self.range, nil, EXCLUDE_TAGS)
  for _, target in ipairs(targets) do
    if self:GetFuelAmount() <= 0 then
      break
    end
    if target ~= self.inst then
      self:TryChargeTarget(target)
    end
  end
end

function ArkSupplyCharger:_RefreshTask()
  if self._task ~= nil then
    self._task:Cancel()
    self._task = nil
  end

  if self.enabled and self.scanInterval > 0 then
    self._task = self.inst:DoPeriodicTask(self.scanInterval, function()
      self:ScanAndCharge()
    end)
  end
end

function ArkSupplyCharger:OnRemoveFromEntity()
  if self._task ~= nil then
    self._task:Cancel()
    self._task = nil
  end
end

return ArkSupplyCharger