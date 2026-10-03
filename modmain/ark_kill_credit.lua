local MAX_CREDIT_DEPTH = 5
local PARTICIPATION_TIMEOUT = 60
local CLEANUP_INTERVAL = 10

-- 世界 -> 目标 -> 参与者 -> 最近命中时间，所有实体均只作为弱键保存。
local world_attacks = setmetatable({}, { __mode = "k" })

local function NewWeakKeyTable()
  return setmetatable({}, { __mode = "k" })
end

-- 最多访问五个实体，取其中最后一个持有 ark_elite 的实体。
local function ResolveCreditTarget(source, victim)
  local credit_target = nil
  local visited = {}
  for depth = 1, MAX_CREDIT_DEPTH do
    if source == nil or not source:IsValid() or visited[source] then
      break
    end
    visited[source] = true
    if source.components.ark_elite ~= nil then
      credit_target = source
    end
    local transfer = source.components.ark_kill_transfer
    if transfer == nil or depth == MAX_CREDIT_DEPTH then
      break
    end
    source = transfer:GetCreditTarget(victim)
  end
  return credit_target
end

local function GetEnabledElite(credit_target)
  if credit_target == nil or not credit_target:IsValid() then
    return nil
  end
  local elite = credit_target.components.ark_elite
  return elite ~= nil and elite:IsKillExpEnabled() and elite or nil
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
  local credit_target = ResolveCreditTarget(data.afflicter, victim)
  if GetEnabledElite(credit_target) == nil then
    return
  end
  local participants = attacks[victim]
  if participants == nil then
    participants = NewWeakKeyTable()
    attacks[victim] = participants
  end
  participants[credit_target] = GetTime()
end

local function OnEntityDeath(world, data)
  local attacks = world_attacks[world]
  local victim = data ~= nil and data.inst or nil
  if attacks == nil or victim == nil then
    return
  end
  local participants = attacks[victim]
  -- 先移除记录，避免奖励回调内触发其他事件时重复使用本次参与关系。
  attacks[victim] = nil
  local now = GetTime()
  local killer = ResolveCreditTarget(data.afflicter, victim)
  local elite = GetEnabledElite(killer)
  if elite ~= nil then
    local last_hit_time = participants ~= nil and participants[killer] or nil
    elite:OnKill(victim, true, last_hit_time ~= nil and now - last_hit_time <= PARTICIPATION_TIMEOUT)
  end
  -- 来源缺失或击杀者禁用经验时，仍分别结算其他有效参与者。
  if participants ~= nil then
    for participant, last_hit_time in pairs(participants) do
      if participant ~= killer and now - last_hit_time <= PARTICIPATION_TIMEOUT then
        local participant_elite = GetEnabledElite(participant)
        if participant_elite ~= nil then
          participant_elite:OnKill(victim, false, true)
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
  for victim, participants in pairs(attacks) do
    if not victim:IsValid() or victim.components.health == nil or victim.components.health:IsDead() then
      attacks[victim] = nil
    else
      for participant, last_hit_time in pairs(participants) do
        if GetEnabledElite(participant) == nil or now - last_hit_time > PARTICIPATION_TIMEOUT then
          participants[participant] = nil
        end
      end
      if next(participants) == nil then
        attacks[victim] = nil
      end
    end
  end
end

local function OnWorldRemoved(world)
  world_attacks[world] = nil
end

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
