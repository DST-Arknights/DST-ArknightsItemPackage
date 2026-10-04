-- 默认账户货币只奖励玩家最终击杀的普通生物；巨兽改由世界掉落事件生成钱包。
local function DefaultKillCurrencyFn(inst, victim, is_kill, is_participated)
  if not is_kill or not inst:HasTag("player") then
    return nil
  end
  if victim:HasTag("epic") then
    return nil
  end
  local health = victim.components and victim.components.health
  if health == nil then
    return nil
  end
  local maxhealth = health.maxhealth or 0
  if maxhealth <= 0 then
    return nil
  end
  local gold = math.floor((maxhealth ^ 1.1) * 0.3)
  if gold < 1 then
    gold = 1
  end
  return { ark_gold = gold }
end

local ArkCurrency = Class(function(self, inst)
  self.inst = inst
  self._killCurrencyFn = DefaultKillCurrencyFn
end)

-- fn(inst, victim, is_kill, is_participated) 返回 { [currency_type] = amount } 或 nil。
-- 货币种类使用 TUNING.ARK_CURRENCY_TYPES 中已配置的名称；仅正数奖励到账。
-- 返回 nil 不奖励账户货币；设置 nil 完全退出货币击杀及参与结算。
-- 此接口不影响巨兽钱包，也不影响其他货币来源。
function ArkCurrency:SetKillCurrencyFn(fn)
  assert(fn == nil or type(fn) == "function", "kill currency calculator must be a function or nil")
  self._killCurrencyFn = fn
end

function ArkCurrency:IsKillRewardEnabled()
  return self._killCurrencyFn ~= nil
end

function ArkCurrency:OnKill(victim, is_kill, is_participated)
  if not self:IsKillRewardEnabled() or victim == nil or not (is_kill or is_participated) then
    return
  end
  local rewards = self._killCurrencyFn(self.inst, victim, is_kill == true, is_participated == true)
  assert(rewards == nil or type(rewards) == "table", "kill currency calculator must return a table or nil")
  if rewards ~= nil then
    for _, currency_type in ipairs(TUNING.ARK_CURRENCY_TYPES) do
      local amount = rewards[currency_type]
      if type(amount) == "number" and amount > 0 then
        self:AddArkCurrencyByType(currency_type, amount)
      end
    end
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
