local function Clamp(value, min_value, max_value)
  return math.max(min_value, math.min(max_value, value))
end

local function DropEpicWallets(victim, maxhealth)
  local lootdropper = victim.components.lootdropper
  if lootdropper == nil then
    return
  end
  local health = math.max(1, maxhealth or 1)
  local scale = math.max(1, math.floor(math.sqrt(health) / 25))
  local drop_ratio = 2 / 3
  local gold2_min = math.max(1, math.floor((1 + math.floor(scale * 0.5)) * drop_ratio))
  local gold2_max = math.max(gold2_min, math.floor((2 + scale) * drop_ratio))
  local gold1_min = math.max(1, math.floor((2 + scale) * drop_ratio))
  local gold1_max = math.max(gold1_min, math.floor((4 + scale * 2) * drop_ratio))
  local gold3_chance = Clamp(Clamp(0.08 + scale * 0.02, 0.08, 0.35) * drop_ratio, 0.05, 0.35)
  local gold2_count = math.random(gold2_min, gold2_max)
  local gold1_count = math.random(gold1_min, gold1_max)
  local drop_gold3 = math.random() <= lootdropper:GetChance(gold3_chance)

  -- 直接落地，避免后续 lootsetupfn/SetLoot 清掉钱包；不进入巨兽尸体存储。
  for _ = 1, gold2_count do
    lootdropper:SpawnLootPrefab("ark_item_gold2")
  end
  for _ = 1, gold1_count do
    lootdropper:SpawnLootPrefab("ark_item_gold1")
  end
  if drop_gold3 then
    lootdropper:SpawnLootPrefab("ark_item_gold3")
  end
end

-- 默认只奖励玩家的最终击杀；巨兽钱包也由该函数决定是否掉落。
local function DefaultKillCurrencyFn(inst, victim, is_kill, is_participated)
  if not is_kill or not inst:HasTag("player") then
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
  local ratio = victim:HasTag("epic") and 0.4 or 0.3
  local gold = math.floor((maxhealth ^ 1.1) * ratio)
  if gold < 1 then
    gold = 1
  end
  if victim:HasTag("epic") then
    DropEpicWallets(victim, maxhealth)
  end
  return { ark_gold = gold }
end

local ArkCurrency = Class(function(self, inst)
  self.inst = inst
  self._killCurrencyFn = DefaultKillCurrencyFn
end)

-- fn(inst, victim, is_kill, is_participated) 返回 { [currency_type] = amount } 或 nil。
-- 货币种类使用 TUNING.ARK_CURRENCY_TYPES 中已配置的名称；仅正数奖励到账。
-- 函数可自行控制实体掉落并返回 nil；替换默认函数后不再自动掉巨兽钱包。
-- 设置 nil 完全退出货币及默认钱包奖励，不影响其他货币来源。
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
