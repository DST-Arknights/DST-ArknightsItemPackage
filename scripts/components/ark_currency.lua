local utils = require("ark_utils")

local function OnKilled(inst, data)
  if not inst:HasTag("player") then
    return
  end
  local target = data.victim
  if not target then
    return
  end
  if not inst.components.ark_currency then
    return
  end
  -- 获取目标血量, 指定用户增加被击杀生物的最大血量数量的金币
  local health = target.components.health.maxhealth
  local gold = math.floor(health / 1)
  inst.components.ark_currency:AddArkGold(gold)
end

local ArkCurrency = Class(function(self, inst)
  self.inst = inst
  self.inst:ListenForEvent("killed", OnKilled)
end)

function ArkCurrency:OnSave()
  return {
    currency = self.inst.replica.ark_currency:GetArkCurrency()
  }
end

function ArkCurrency:OnLoad(data)
  local save = data.currency or TheWorld.components.ark_currency_data:GetPlayerCurrency(self.inst.userid)
  self.inst.replica.ark_currency:SetArkCurrency(save)
end
function ArkCurrency:GetArkCurrency()
  return self.inst.replica.ark_currency:GetArkCurrency()
end

function ArkCurrency:SetArkCurrency(currency)
  self.inst.replica.ark_currency:SetArkCurrency(currency)
end

function ArkCurrency:GetArkCurrencyByType(currencyType)
  return self.inst.replica.ark_currency:GetArkCurrencyByType(currencyType)
end

function ArkCurrency:SetArkCurrencyByType(currencyType, value)
  self.inst.replica.ark_currency:SetArkCurrencyByType(currencyType, value)
end

function ArkCurrency:AddArkCurrencyByType(currencyType, value)
  self.inst.replica.ark_currency:AddArkCurrencyByType(currencyType, value)
end

function ArkCurrency:GetArkGold()
  return self.inst.replica.ark_currency:GetArkGold()
end

function ArkCurrency:SetArkGold(value)
  self.inst.replica.ark_currency:SetArkGold(value)
end

function ArkCurrency:AddArkGold(value)
  self.inst.replica.ark_currency:AddArkGold(value)
end

function ArkCurrency:GetArkDiamondShd()
  return self.inst.replica.ark_currency:GetArkDiamondShd()
end

function ArkCurrency:SetArkDiamondShd(value)
  self.inst.replica.ark_currency:SetArkDiamondShd(value)
end

function ArkCurrency:AddArkDiamondShd(value)
  self.inst.replica.ark_currency:AddArkDiamondShd(value)
end

function ArkCurrency:GetArkDiamond()
  return self.inst.replica.ark_currency:GetArkDiamond()
end

function ArkCurrency:SetArkDiamond(value)
  self.inst.replica.ark_currency:SetArkDiamond(value)
end

function ArkCurrency:AddArkDiamond(value)
  self.inst.replica.ark_currency:AddArkDiamond(value)
end

function ArkCurrency:GetArkExggShd()
  return self.inst.replica.ark_currency:GetArkExggShd()
end

function ArkCurrency:SetArkExggShd(value)
  self.inst.replica.ark_currency:SetArkExggShd(value)
end

function ArkCurrency:AddArkExggShd(value)
  self.inst.replica.ark_currency:AddArkExggShd(value)
end

function ArkCurrency:GetArkHggShd()
  return self.inst.replica.ark_currency:GetArkHggShd()
end

function ArkCurrency:SetArkHggShd(value)
  self.inst.replica.ark_currency:SetArkHggShd(value)
end

function ArkCurrency:AddArkHggShd(value)
  self.inst.replica.ark_currency:AddArkHggShd(value)
end

function ArkCurrency:OnRemoveFromEntity()
  TheWorld.components.ark_currency_data:SetPlayerCurrency(self.inst.userid, self.inst.replica.ark_currency:GetArkCurrency())
  self.inst:RemoveEventCallback("killed", OnKilled)
end

return ArkCurrency
