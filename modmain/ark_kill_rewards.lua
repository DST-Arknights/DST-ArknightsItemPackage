local MAX_CREDIT_DEPTH = 5
local PARTICIPATION_TIMEOUT = 60
local CLEANUP_INTERVAL = 10

-- 注册的奖励组件统一提供 IsKillRewardEnabled() 和 OnKill(victim, is_kill, is_participated)。
local reward_components = {}
local registered_components = {}

function GLOBAL.ArkRegisterKillRewardComponent(component_name)
  assert(type(component_name) == "string" and component_name ~= "", "kill reward component name must be a non-empty string")
  if not registered_components[component_name] then
    registered_components[component_name] = true
    reward_components[#reward_components + 1] = component_name
  end
end

GLOBAL.ArkRegisterKillRewardComponent("ark_elite")
GLOBAL.ArkRegisterKillRewardComponent("ark_currency")
GLOBAL.ArkRegisterKillRewardComponent("ark_kill_loot")

-- 世界 -> 目标 -> 奖励组件名 -> 参与者 -> 最近命中时间，所有实体均只作为弱键保存。
local world_attacks = setmetatable({}, { __mode = "k" })

local function NewWeakKeyTable()
  return setmetatable({}, { __mode = "k" })
end

-- 最多访问五个实体，分别取其中最后一个持有各奖励组件的实体。
local function ResolveCreditTargets(source, victim)
  local credit_targets = {}
  local visited = {}
  for depth = 1, MAX_CREDIT_DEPTH do
    if source == nil or not source:IsValid() or visited[source] then
      break
    end
    visited[source] = true
    for _, component_name in ipairs(reward_components) do
      if source.components[component_name] ~= nil then
        credit_targets[component_name] = source
      end
    end
    local transfer = source.components.ark_kill_transfer
    if transfer == nil or depth == MAX_CREDIT_DEPTH then
      break
    end
    source = transfer:GetCreditTarget(victim)
  end
  return credit_targets
end

local function GetEnabledReward(credit_target, component_name)
  if credit_target == nil or not credit_target:IsValid() then
    return nil
  end
  local reward = credit_target.components[component_name]
  return reward ~= nil and reward:IsKillRewardEnabled() and reward or nil
end

local function OnHealthDelta(victim, data)
  local attacks = TheWorld ~= nil and world_attacks[TheWorld] or nil
  local health = victim.components.health
  -- 致命伤害的死亡结算早于 healthdelta，不再给已死亡的目标重建记录。
  if attacks == nil or data == nil or health == nil or health:IsDead()
      or not victim:IsValid() or data.afflicter == nil
      or data.amount == nil or data.amount >= 0
      or data.newpercent >= data.oldpercent then
    return
  end
  local credit_targets = ResolveCreditTargets(data.afflicter, victim)
  local now = GetTime()
  for _, component_name in ipairs(reward_components) do
    local credit_target = credit_targets[component_name]
    if GetEnabledReward(credit_target, component_name) ~= nil then
      local rewards = attacks[victim]
      if rewards == nil then
        rewards = {}
        attacks[victim] = rewards
      end
      local participants = rewards[component_name]
      if participants == nil then
        participants = NewWeakKeyTable()
        rewards[component_name] = participants
      end
      participants[credit_target] = now
    end
  end
end

local function OnEntityDeath(world, data)
  local attacks = world_attacks[world]
  local victim = data ~= nil and data.inst or nil
  if attacks == nil or victim == nil then
    return
  end
  local rewards = attacks[victim]
  -- 先移除记录，避免奖励回调内触发其他事件时重复使用本次参与关系。
  attacks[victim] = nil
  local now = GetTime()
  local credit_targets = ResolveCreditTargets(data.afflicter, victim)
  for _, component_name in ipairs(reward_components) do
    local participants = rewards ~= nil and rewards[component_name] or nil
    local killer = credit_targets[component_name]
    local reward = GetEnabledReward(killer, component_name)
    if reward ~= nil then
      local last_hit_time = participants ~= nil and participants[killer] or nil
      reward:OnKill(victim, true, last_hit_time ~= nil and now - last_hit_time <= PARTICIPATION_TIMEOUT)
    end
    -- 每种奖励独立判断开关；来源缺失也不阻断已有参与者的结算。
    if participants ~= nil then
      for participant, last_hit_time in pairs(participants) do
        if participant ~= killer and now - last_hit_time <= PARTICIPATION_TIMEOUT then
          local participant_reward = GetEnabledReward(participant, component_name)
          if participant_reward ~= nil then
            participant_reward:OnKill(victim, false, true)
          end
        end
      end
    end
  end
end

local function CleanupExpired(world)
  local attacks = world_attacks[world]
  if attacks == nil then
    return
  end
  local now = GetTime()
  for victim, rewards in pairs(attacks) do
    if not victim:IsValid() or victim.components.health == nil or victim.components.health:IsDead() then
      attacks[victim] = nil
    else
      for component_name, participants in pairs(rewards) do
        for participant, last_hit_time in pairs(participants) do
          if GetEnabledReward(participant, component_name) == nil or now - last_hit_time > PARTICIPATION_TIMEOUT then
            participants[participant] = nil
          end
        end
        if next(participants) == nil then
          rewards[component_name] = nil
        end
      end
      if next(rewards) == nil then
        attacks[victim] = nil
      end
    end
  end
end

local function OnWorldRemoved(world)
  world_attacks[world] = nil
end

-- 玩家默认拥有额外击杀掉落策略，与经验和账户货币分别配置、分别关闭。
AddPlayerPostInit(function(inst)
  if TheWorld.ismastersim and inst.components.ark_kill_loot == nil then
    inst:AddComponent("ark_kill_loot")
  end
end)

-- MakeWorld 在地面和洞穴均设置 prefab 名为 world；此时 TheWorld 已构造完成。
AddPrefabPostInit("world", function(world)
  if not world.ismastersim then
    return
  end
  world_attacks[world] = NewWeakKeyTable()
  world:ListenForEvent("entity_death", OnEntityDeath)
  world:ListenForEvent("onremove", OnWorldRemoved)
  -- 任务归世界所有，世界移除时游戏自动取消它。
  world:DoPeriodicTask(CLEANUP_INTERVAL, CleanupExpired)
end)

AddComponentPostInit("health", function(self)
  if TheWorld ~= nil and TheWorld.ismastersim then
    self.inst:ListenForEvent("healthdelta", OnHealthDelta)
  end
end)
