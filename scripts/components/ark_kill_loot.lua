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

-- 默认仅玩家的最终击杀掉落巨兽钱包。
local function DefaultKillLootFn(inst, victim, is_kill, is_participated)
  if not is_kill or not inst:HasTag("player") or not victim:HasTag("epic") then
    return
  end
  local health = victim.components and victim.components.health
  if health == nil then
    return
  end
  local maxhealth = health.maxhealth or 0
  if maxhealth <= 0 then
    return
  end
  DropEpicWallets(victim, maxhealth)
end

local ArkKillLoot = Class(function(self, inst)
  self.inst = inst
  self._killLootFn = DefaultKillLootFn
end)

-- fn(inst, victim, is_kill, is_participated) 自行执行实体掉落，不解读返回值。
-- 设置 nil 完全退出该组件的击杀和参战掉落奖励。
function ArkKillLoot:SetKillLootFn(fn)
  assert(fn == nil or type(fn) == "function", "kill loot handler must be a function or nil")
  self._killLootFn = fn
end

function ArkKillLoot:IsKillRewardEnabled()
  return self._killLootFn ~= nil
end

function ArkKillLoot:OnKill(victim, is_kill, is_participated)
  if not self:IsKillRewardEnabled() or victim == nil or not (is_kill or is_participated) then
    return
  end
  self._killLootFn(self.inst, victim, is_kill == true, is_participated == true)
end

return ArkKillLoot
