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

local SympatheticPendant = Class(function(self, inst)
  self.inst = inst
  self.close_players = {}
  self.near_task = nil
  self.equipped = nil
  self.light = nil
  self.emotion = "normal"

  self.scan_player_period = 1
  self.player_near_dist = 30
  self.player_far_dist = 35
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
end)

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
  for _, emotion in ipairs(self.emotions) do
    player:RemoveDebuff(GetSharedBuffName(self.inst, emotion.name))
  end
end

function SympatheticPendant:SetSharedBuff(player, emotion)
  self:RemoveAllSharedBuffs(player)
  local prefab = GetSharedBuffPrefab(emotion)
  local name = GetSharedBuffName(self.inst, emotion)
  player:AddDebuff(name, prefab, { mult = 1, buffer_name = self.inst.name })
end

function SympatheticPendant:GetEmotion()
  return self.emotion
end

function SympatheticPendant:SetEmotion(emotion)
  self.emotion = emotion
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
  local emotion = self:GetEmotion()
  self:SetSharedBuff(player, emotion)
  self:UpdateLight(emotion)
end

function SympatheticPendant:OnPlayerFar(player)
  self:RemoveAllSharedBuffs(player)
  local emotion = self:GetEmotion()
  self:UpdateLight(emotion)
end

function SympatheticPendant:OnPlayerKeepNear(player)
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

  -- 检查离开 far 距离的玩家（不在 scanned_players 中说明已离开 far 距离）
  for i = #self.close_players, 1, -1 do
    local player = self.close_players[i]
    if not table.contains(scanned_players, player) then
      table.remove(self.close_players, i)
      self:OnPlayerFar(player)
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
  self.evaluate_task = self.inst:DoPeriodicTask(10, function()
    -- self:EvaluateEmotion()
    -- test 随机表情
    local random_emotion = self.emotions[math.random(1, #self.emotions)].name
    self:SetEmotion(random_emotion)
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
  self:StartNearTask()
  self:StartEvaluateEmotion()
  local emotion = self:GetEmotion()
  self:SetEmotion(emotion)
  self:AddLight()
  self:UpdateLight(emotion)
end

function SympatheticPendant:UnequipPendant()
  self:StopEvaluateEmotion()
  self:StopNearTask()
  self:RemoveAllOwnerBuffs()
  self:RemoveLight()
  self.equipped = nil
end

function SympatheticPendant:OnSave()
  local data = {}
  data.emotion = self:GetEmotion()
  return data
end

function SympatheticPendant:OnLoad(data)
  if data and data.emotion then
    self:SetEmotion(data.emotion)
  end
end

function SympatheticPendant:OnRemoveEntity()
  self:UnequipPendant()
end

return SympatheticPendant
