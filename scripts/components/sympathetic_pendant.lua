local function GetOwnerBuffPrefab(emotion)
  return "sympathetic_pendant_" .. emotion .. "_owner_buff"
end

local GetOwnerBuffName = GetOwnerBuffPrefab

local function GetSharedBuffPrefab(emotion)
  return "sympathetic_pendant_" .. emotion .. "_shared_buff"
end

local function GetSharedBuffName(inst, emotion)
  return GetSharedBuffPrefab(emotion) .. "_" .. inst.GUID
end

local MAX_RESONANCE = 100
local RESONANCE_DAYS_TO_MAX = 20
-- Full day-night cycle ≈ 16 * 30s = 480s
local RESONANCE_PER_TICK = MAX_RESONANCE / (RESONANCE_DAYS_TO_MAX * 480)

local RESONANCE_TIER_THRESHOLDS = { 75, 50, 25, 0 }
local RESONANCE_TIER_MULTS     = { 0.25, 0.167, 0.083, 0.04 }

local function GetResonanceMult(resonance)
  for i, threshold in ipairs(RESONANCE_TIER_THRESHOLDS) do
    if resonance >= threshold then
      return RESONANCE_TIER_MULTS[i]
    end
  end
  return RESONANCE_TIER_MULTS[#RESONANCE_TIER_MULTS]
end

local function OnAttackOther(inst)
  local pendant = inst.components.sympathetic_pendant
  if pendant then
    pendant.last_combat_time = os.time()
  end
end
local function OnAttacked(inst)
  local pendant = inst.components.sympathetic_pendant
  if pendant then
    pendant.last_combat_time = os.time()
  end
end
local SympatheticPendant = Class(function(self, inst)
  self.inst = inst
  self.close_players = {}
  self.near_task = nil
  self.equipped = nil
  self.light = nil
  self.emotion = "normal"
  self.emotion_start_time = 0
  self.last_combat_time = 0

  self.scan_player_period = 1
  self.player_near_dist = 30
  self.player_far_dist = 35
  self:StartNearTask()

  self.emotions = { {
    name = "sad",
    colour = { 0.15, 0.35, 1.0 }
  }, {
    name = "angry",
    colour = { 1.0, 0.12, 0.08 }
  }, {
    name = "confused",
    colour = { 0.1, 1.0, 0.2 }
  }, {
    name = "happy",
    colour = { 1.0, 0.85, 0.0 }
  }, {
    name = "normal",
    colour = { 0.85, 0.85, 0.75 }
  } }

  self.emotion_defs = {
    {
      name = "sad",
      priority = 5,
      min_duration = 8,
      label = "dead_teammate",
      enter_condition = function()
        for _, v in ipairs(AllPlayers) do
          if v ~= inst and v.components.health:IsDead() then
            return true
          end
        end
        return false
      end,
    },
    {
      name = "angry",
      priority = 4,
      min_duration = 6,
      enter_condition = function()
        return os.time() - self.last_combat_time < 5
      end,
      exit_condition = function()
        return os.time() - self.last_combat_time >= 6
      end,
    },
    {
      name = "sad",
      priority = 3,
      min_duration = 8,
      label = "low_health_teammate",
      enter_condition = function()
        if inst.components.health and inst.components.health.currenthealth < 30 then
          return true
        end
        for _, player in ipairs(self.close_players) do
          if player.components.health.currenthealth < 30 then
            return true
          end
        end
        return false
      end,
    },
    {
      name = "happy",
      priority = 2,
      min_duration = 10,
      enter_condition = function()
        return #self.close_players > 0
      end,
    },
    {
      name = "confused",
      priority = 1,
      min_duration = 5,
      enter_condition = function()
        return #self.close_players == 0
      end,
    },
    {
      name = "normal",
      priority = 0,
      min_duration = 0,
      enter_condition = function()
        return true
      end,
    },
  }
end)

function SympatheticPendant:RegisterCombatEvents()
  self.inst:ListenForEvent("onattackother", OnAttackOther)
  self.inst:ListenForEvent("attacked", OnAttacked)
end

function SympatheticPendant:UnregisterCombatEvents()
  self.inst:RemoveEventCallback("onattackother", OnAttackOther)
  self.inst:RemoveEventCallback("attacked", OnAttacked)
end

-- Emotion evaluation
function SympatheticPendant:EvaluateEmotion()
  local now = os.time()
  local current = self.emotion

  -- Find current emotion's active definition to get its priority
  -- Scan in priority order: first def whose name matches AND enter_condition is true = current priority
  local current_priority = 0
  for _, def in ipairs(self.emotion_defs) do
    if def.name == current and def.enter_condition(self) then
      current_priority = def.priority
      break
    end
  end

  -- Find best matching emotion (top-down priority scan)
  local best_def = nil
  for _, def in ipairs(self.emotion_defs) do
    if def.enter_condition(self) then
      best_def = def
      break
    end
  end

  if best_def == nil then
    -- Fallback to normal (last entry in emotion_defs)
    best_def = self.emotion_defs[#self.emotion_defs]
  end

  -- Same emotion AND same priority: no change (prevents bouncing between label variants of same emotion)
  if best_def.name == current and best_def.priority == current_priority then
    return
  end

  -- Higher priority: switch immediately
  if best_def.priority > current_priority then
    self:SetEmotion(best_def.name)
    return
  end

  -- Lower priority: must pass both min_duration and exit_condition gates
  local current_def = nil
  for _, def in ipairs(self.emotion_defs) do
    if def.name == current and def.priority == current_priority then
      current_def = def
      break
    end
  end

  if current_def then
    if now - self.emotion_start_time < current_def.min_duration then
      return
    end
    if current_def.exit_condition and not current_def.exit_condition(self) then
      return
    end
  end

  self:SetEmotion(best_def.name)
end

function SympatheticPendant:RemoveAllOwnerBuffs()
  for _, emotion in ipairs(self.emotions) do
    self.inst:RemoveDebuff(GetOwnerBuffPrefab(emotion.name))
  end
end

function SympatheticPendant:SetOwnerBuff(emotion)
  self:RemoveAllOwnerBuffs()
  local prefab = GetOwnerBuffPrefab(emotion)
  local name = GetOwnerBuffName(emotion)
  self.inst:AddDebuff(name, prefab)
end

function SympatheticPendant:RemoveAllSharedBuffs(player)
  if not player:IsValid() then
    return
  end
  for _, emotion in ipairs(self.emotions) do
    player:RemoveDebuff(GetSharedBuffName(self.inst, emotion.name))
  end
end

function SympatheticPendant:SetSharedBuff(player, emotion)
  self:RemoveAllSharedBuffs(player)
  local prefab = GetSharedBuffPrefab(emotion)
  local name = GetSharedBuffName(self.inst, emotion)
  local data = self:GetSharedData(player)
  local mult = data and GetResonanceMult(data.resonance) or 0
  player:AddDebuff(name, prefab, { mult = mult, buffer_name = self.inst.name })
end

function SympatheticPendant:GetEmotion()
  return self.emotion
end

function SympatheticPendant:SetEmotion(emotion)
  self.emotion = emotion
  self.emotion_start_time = os.time()
  self:UpdateLight(emotion)
  if self.equipped and self.equipped.SetEmotion then
    self.equipped:SetEmotion(self.inst, emotion)
  end
  self:SetOwnerBuff(emotion)
  for _, player in ipairs(self.close_players) do
    self:SetSharedBuff(player, emotion)
  end
end

function SympatheticPendant:OnPlayerNear(player)
  if not self.equipped then
    return
  end
  local emotion = self:GetEmotion()
  self:SetSharedBuff(player, emotion)
  self:UpdateLight(emotion)
end

function SympatheticPendant:OnPlayerFar(player)
  if self.equipped then
    if player:IsValid() then
      self:RemoveAllSharedBuffs(player)
    end
    local emotion = self:GetEmotion()
    self:UpdateLight(emotion)
  end
end

function SympatheticPendant:OnPlayerKeepNear(player)
  self:EvaluateAddResonance(player)
end

function SympatheticPendant:EvaluateAddResonance(player)
  -- Both must have pendant equipped
  if not self.equipped then
    return
  end
  local other = player.components.sympathetic_pendant
  if not (other and other.equipped) then
    return
  end

  -- Only the player with smaller GUID accumulates
  if self.inst.GUID > player.GUID then
    return
  end

  local data = self:GetSharedData(player)
  if not data then
    return
  end

  local old = data.resonance
  data.resonance = math.min(data.resonance + RESONANCE_PER_TICK, MAX_RESONANCE)

  if data.resonance ~= old then
    self:OnResonanceChange(player, data.resonance, old)
    other:OnResonanceChange(self.inst, data.resonance, old)
  end
end

function SympatheticPendant:OnResonanceChange(player, resonance, old)
  if GetResonanceMult(resonance) ~= GetResonanceMult(old) then
    self:SetSharedBuff(player, self:GetEmotion())
  end
end

function SympatheticPendant:IsResonanceMaxed(player)
  local data = self:GetSharedData(player)
  return data and data.resonance >= MAX_RESONANCE or false
end

function SympatheticPendant:GetSharedData(player)
  local world_data = TheWorld.components.sympathetic_pendant_data
  return world_data and world_data:GetPairData(self.inst.GUID, player.GUID) or nil
end

function SympatheticPendant:ScanPlayers()
  local inst = self.inst
  local x, y, z = inst.Transform:GetWorldPosition()
  local scanned_players = FindPlayersInRange(x, y, z, self.player_far_dist, true)

  -- 检查新进入 near 距离的玩家
  for _, player in ipairs(scanned_players) do
    if player ~= inst then
      if table.contains(self.close_players, player) then
        self:OnPlayerKeepNear(player)
      elseif inst:GetDistanceSqToPoint(player.Transform:GetWorldPosition()) <= self.player_near_dist * self.player_near_dist then
        table.insert(self.close_players, player)
        self:OnPlayerNear(player)
      end
    end
  end

  -- 清理离开范围/离线的玩家；保留满共鸣的在线远方玩家
  for i = #self.close_players, 1, -1 do
    local player = self.close_players[i]
    if not table.contains(scanned_players, player) then
      if table.contains(AllPlayers, player) and self:IsResonanceMaxed(player) then
        -- 在线且满共鸣：保留，无视距离
      else
        table.remove(self.close_players, i)
        self:OnPlayerFar(player)
      end
    end
  end

  -- 将满共鸣的远方玩家加入 close_players（无视距离）
  for _, player in ipairs(AllPlayers) do
    if player ~= inst and not table.contains(self.close_players, player) and self:IsResonanceMaxed(player) then
      table.insert(self.close_players, player)
      self:OnPlayerNear(player)
    end
  end
end

function SympatheticPendant:StopNearTask()
  if self.near_task ~= nil then
    self.near_task:Cancel()
    self.near_task = nil
  end
end

function SympatheticPendant:StartNearTask()
  if self.near_task ~= nil then
    self.near_task:Cancel()
    self.near_task = nil
  end
  self.near_task = self.inst:DoPeriodicTask(self.scan_player_period, function() self:ScanPlayers() end)
end

function SympatheticPendant:UpdateLight(emotion)
  local colour = self.emotions[1].colour
  for _, e in ipairs(self.emotions) do
    if e.name == emotion then
      colour = e.colour
      break
    end
  end
  local radius = (#self.close_players + 1) * 3 -- 附近玩家数量 + 自己
  if self.light then
    self.light:UpdateLight({
      colour = colour,
      radius = radius
    })
  end
end

function SympatheticPendant:AddLight()
  if self.light then
    self.light:Remove()
  end
  self.light = SpawnPrefab("sympathetic_pendant_light")
  self.light.entity:SetParent(self.inst.entity)
end

function SympatheticPendant:RemoveLight()
  if self.light then
    self.light:Remove()
    self.light = nil
  end
end

function SympatheticPendant:StartEvaluateEmotion()
  if self.evaluate_task then
    self.evaluate_task:Cancel()
    self.evaluate_task = nil
  end
  self.evaluate_task = self.inst:DoPeriodicTask(1, function()
    self:EvaluateEmotion()
  end)
end

function SympatheticPendant:StopEvaluateEmotion()
  if self.evaluate_task then
    self.evaluate_task:Cancel()
    self.evaluate_task = nil
  end
end

function SympatheticPendant:EquipPendant(item)
  self.equipped = item
  self:RegisterCombatEvents()
  self:StartEvaluateEmotion()
  local emotion = self:GetEmotion()
  self:SetEmotion(emotion)
  self:AddLight()
  self:UpdateLight(emotion)
end

function SympatheticPendant:UnequipPendant()
  self:StopEvaluateEmotion()
  self:UnregisterCombatEvents()
  self:RemoveAllOwnerBuffs()
  for _, player in ipairs(self.close_players) do
    self:RemoveAllSharedBuffs(player)
  end
  self:RemoveLight()
  self.equipped = nil
end

function SympatheticPendant:OnRemoveEntity()
  for _, player in ipairs(self.close_players) do
    self:RemoveAllSharedBuffs(player)
  end
end

function SympatheticPendant:OnSave()
  local data = {}
  data.emotion = self:GetEmotion()
  data.emotion_start_time = self.emotion_start_time
  data.last_combat_time = self.last_combat_time
  return data
end

function SympatheticPendant:OnLoad(data)
  if data and data.emotion then
    self.emotion_start_time = data.emotion_start_time or os.time()
    self.last_combat_time = data.last_combat_time or 0
    self:SetEmotion(data.emotion)
  end
end

return SympatheticPendant
