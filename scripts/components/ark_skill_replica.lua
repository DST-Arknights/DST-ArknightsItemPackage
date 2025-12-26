local CONSTANTS = require "ark_constants"

local function getHotkeyName(inst, id)
  return inst.prefab .. "_ark_skill_" .. id
end


local SafeGetArkExtendUi = GenSafeCall(function(inst)
  return inst and inst.HUD and inst.HUD.controls and inst.HUD.controls.arkExtendUi or nil
end)

local SafeGetSkillsUI = GenSafeCall(function(inst)
  return SafeGetArkExtendUi(inst).skills
end)

local MAX_SKILL_COUNT = 4

local ArkSkillReplica = Class(function(self, inst)
  self.inst = inst
  self.states = {}           -- 索引 -> state
  self.skillIdToIndex = {}   -- 技能id -> 索引
  self.skillCount = 0
  self.configs = {}
  self._register_tasks = {}
  -- 预制 4 个 state，用于同步状态数据
  for i = 1, MAX_SKILL_COUNT do
    local state = NetState(self.inst, {
      status = "int:classified",
      level = "int:classified",
      energyProgress = "float:classified",
      buffProgress = "float:classified",
      bulletCount = "int:classified",
      activationStacks = "int:classified",
    })
    self.states[i] = state
    state:Attach(self.inst)
    state:Watch({ "status", "level", "energyProgress", "buffProgress", "bulletCount", "activationStacks" }, function()
      ArkLogger:Debug('ark_skill_replica Watch OnDirty', i, state.status, state.level, state.energyProgress, state.buffProgress, state.bulletCount, state.activationStacks)
      local skillUI = SafeGetSkillsUI(self.inst):GetSkillByIndex(i)
      if skillUI then
        skillUI:SyncSkillStatus(
          state.status,
          state.level,
          state.energyProgress,
          state.buffProgress,
          state.bulletCount,
          state.activationStacks
        )
      end
    end)
  end
end)

function ArkSkillReplica:ClientRegisterSkill(config)
  ArkLogger:Debug("ark_skill_replica ClientRegisterSkill", config.id)
  if TheWorld.ismastersim then
    return
  end
  local index = config.index
  self.skillIdToIndex[config.id] = index
  self.configs[index] = config
  self:SetHotkey(config.id, config.hotkey)
end

-- 主机端注册技能，返回分配的索引
function ArkSkillReplica:RegisterSkill(config)
  ArkLogger:Debug("ark_skill_replica register skill", config.id)

  self.skillCount = self.skillCount + 1
  if self.skillCount > MAX_SKILL_COUNT then
    ArkLogger:Error("ark_skill_replica: 超过最大技能数量限制 " .. MAX_SKILL_COUNT)
    return nil
  end

  local index = self.skillCount
  self.skillIdToIndex[config.id] = index
  self.configs[index] = config
  if TheWorld.ismastersim then
      -- 发送rpc, 同步配置
      -- 延时发送, 不然获取不到userid
    if self._register_tasks[config.id] then
      self._register_tasks[config.id]:Cancel()
    end
    self._register_tasks[config.id] = self.inst:DoTaskInTime(0, function()
      if ThePlayer == self.inst then
        self:SetHotkey(config.id, config.hotkey)
      else
        ArkLogger:Debug("ark_skill_replica register skill send rpc", config.id)
        SendModRPCToClient(GetClientModRPC("arkSkill", "ClientRegisterSkill"), self.inst.userid, json.encode(config))
        self._register_tasks[config.id] = nil
      end
    end)
  end
  return index
end

function ArkSkillReplica:GetStateByIndex(index)
  return self.states[index]
end

-- 主机端同步状态到客机
function ArkSkillReplica:SyncSkillStatus(id, data)
  ArkLogger:Debug('ark_skill_replica SyncSkillStatus', id, data.status, data.level, data.energyProgress, data.buffProgress, data.bulletCount, data.activationStacks)
  local index = self.skillIdToIndex[id]
  if not index then
    ArkLogger:Error("ark_skill_replica: 未注册的技能 " .. id)
    return
  end
  local state = self.states[index]
  if not state then
    ArkLogger:Error("ark_skill_replica: 未找到技能状态 " .. id)
    return
  end
  state.status = data.status
  state.level = data.level
  state.energyProgress = data.energyProgress
  state.buffProgress = data.buffProgress
  state.bulletCount = data.bulletCount
  state.activationStacks = data.activationStacks
end

function ArkSkillReplica:GetState(id)
  local index = self.skillIdToIndex[id]
  return index and self.states[index] or nil
end

function ArkSkillReplica:RestoreDefaultHotkey(id)
  if not TheNet:IsDedicated() then
    local hotkey_mgr = GetHotKeyManager(self.inst)
    local name = getHotkeyName(self.inst, id)
    hotkey_mgr:RestoreDefaultHotkey(name)
  end
end

function ArkSkillReplica:GetHotkey(id)
  if not TheNet:IsDedicated() then
    local hotkey = GetHotKeyManager(self.inst)
    local name = getHotkeyName(self.inst, id)
    return hotkey:GetHotkey(name)
  end
end

function ArkSkillReplica:SetHotkey(id, hotkey)
  if not hotkey then return end
  if not TheNet:IsDedicated() then
    local hotkey_mgr = GetHotKeyManager(self.inst)
    local name = getHotkeyName(self.inst, id)
    -- 检查是否已经有按键了
    local oldHotkey = hotkey_mgr:GetHotkey(name)
    ArkLogger:Debug('ark_skill_replica SetHotkey', id, hotkey, oldHotkey)
    if oldHotkey then
      hotkey_mgr:SetHotkey(name, hotkey)
    else
      hotkey_mgr:Register(name, function()
        if self:IsActivating(id) then
          self:CancelSkill(id)
        else
          self:TryActivateSkill(id)
        end
      end, hotkey)
    end
  end
end

function ArkSkillReplica:TryActivateSkill(id)
  local target = TheInput:GetWorldEntityUnderMouse()
  local targetPos = TheInput:GetWorldPosition()
  local serializedPos = string.format("%.2f,%.2f,%.2f", targetPos.x, targetPos.y, targetPos.z)
  local force = TheInput:IsKeyDown(KEY_CTRL) or TheInput:IsKeyDown(KEY_RCTRL)
  if self.inst.components.ark_skill then
    self.inst.components.ark_skill:GetSkill(id):TryActivate(target, targetPos, force)
  else
    SendModRPCToServer(GetModRPC("arkSkill", "ManualActivateSkill"), id, target, serializedPos, force)
  end
end

function ArkSkillReplica:IsActivating(id)
  local state = self:GetState(id)
  return state and state.status == CONSTANTS.SKILL_STATUS.BUFFING or state.status == CONSTANTS.SKILL_STATUS.BULLETING
end

function ArkSkillReplica:CancelSkill(id)
  if self.inst.components.ark_skill then
    self.inst.components.ark_skill:GetSkill(id):Cancel()
  else
    SendModRPCToServer(GetModRPC("arkSkill", "ManualCancelSkill"), id)
  end
end

function ArkSkillReplica:OnRemoveFromEntity()
  -- 卸载按键
  if not TheNet:IsDedicated() then
    for id, _ in pairs(self.skillIdToIndex) do
      local hotkey = GetHotKeyManager(self.inst)
      local name = getHotkeyName(self.inst, id)
      hotkey:Unregister(name)
    end
    SafeGetArkExtendUi(self.inst):RemoveSkill()
  end
  for _, task in pairs(self._register_tasks) do
    local _ = task and task:Cancel()
  end
end

return ArkSkillReplica
