-- 默认击杀金币只奖励玩家的最终击杀，参与战斗本身不发金币。
local function DefaultKillGoldFn(inst, victim, is_kill, is_participated)
  if not is_kill or not inst:HasTag("player") then
    return 0
  end
  local health = victim.components and victim.components.health
  if health == nil then
    return 0
  end
  local maxhealth = health.maxhealth or 0
  if maxhealth <= 0 then
    return 0
  end
  local ratio = victim:HasTag("epic") and 0.4 or 0.3
  local gold = math.floor((maxhealth ^ 1.1) * ratio)
  if gold < 1 then
    gold = 1
  end
  return gold
end

local ArkCurrency = Class(function(self, inst)
  self.inst = inst
  self._killGoldFn = DefaultKillGoldFn
end)

-- fn(inst, victim, is_kill, is_participated) 返回基础金币；nil 或 0 不发金币。
-- 设置 nil 表示完全退出击杀及参与奖励结算，不影响其他货币来源。
function ArkCurrency:SetKillGoldFn(fn)
  assert(fn == nil or type(fn) == "function", "kill gold calculator must be a function or nil")
  self._killGoldFn = fn
end

function ArkCurrency:IsKillRewardEnabled()
  return self._killGoldFn ~= nil
end

function ArkCurrency:OnKill(victim, is_kill, is_participated)
  if not self:IsKillRewardEnabled() or victim == nil or not (is_kill or is_participated) then
    return
  end
  local gold = self._killGoldFn(self.inst, victim, is_kill == true, is_participated == true)
  if gold ~= nil and gold > 0 then
    self:AddArkGold(gold)
  end
end

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
end

return ArkCurrency
