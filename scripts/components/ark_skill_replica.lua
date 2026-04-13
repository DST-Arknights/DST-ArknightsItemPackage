local CONSTANTS = require "ark_constants"

local function getHotkeyName(inst, id)
  return 'ark_skill_' .. id
end


local SafeGetArkExtendUi = GenSafeCall(function(inst)
  return inst and inst.HUD and inst.HUD.controls and inst.HUD.controls.arkExtendUi
end)

local SafeGetSkillsUI = GenSafeCall(function(inst)
  return SafeGetArkExtendUi(inst).skills
end)

local MAX_SKILL_COUNT = 4

local ArkSkillReplica = Class(function(self, inst)
  self.inst = inst
  self.states = {}           -- 索引 -> state
  self.skillIds = {}          -- 索引 -> 技能id
  self.skillIdToIndex = {}    -- 技能id -> 索引
  -- 预制 4 个 state，用于同步状态数据
  for i = 1, MAX_SKILL_COUNT do
    local state = NetState(self.inst, "ark_skill")
    self.states[i] = state
    state:Attach(self.inst)
    state:Watch({ "id", "status", "level", "energyProgress", "buffProgress", "bulletCount", "activationStacks" }, function()
      self:SkillDataDirty(i)
    end)
    state:Watch({ "id", "status", "level"}, function ()
      if self.inst.HUD then
        self.inst:PushEvent("refreshcrafting")
      end
    end)
  end
end)

function ArkSkillReplica:GetConfigById(id)
  return GetArkSkillConfigById(id)
end

function ArkSkillReplica:AddSkill(id)
  local cfg = self:GetConfigById(id)
  assert(cfg, "No config found for skill id: " .. tostring(id))
  -- 找到一个空插槽, 设置id, 后续安装交给dirty
  for i, state in pairs(self.states) do
    if state.id == "" then
      state.id = id
      self.skillIdToIndex[id] = i
      return
    end
  end
  assert(false, "No empty slot found for skill id: " .. tostring(id))
end

function ArkSkillReplica:RemoveSkill(id)
  local index = self.skillIdToIndex[id]
  if not index then
    ArkLogger:Error("ark_skill_replica: RemoveSkill failed, skill id not found " .. tostring(id))
    return
  end
  local state = self.states[index]
  if state.id ~= id then
    ArkLogger:Error("ark_skill_replica: RemoveSkill failed, skill id mismatch " .. tostring(id))
    return
  end
  state.id = ""
end

function ArkSkillReplica:DoUninstallSkill(id)
  if not id or id == "" then
    return
  end
  self:UnregisterHotkey(id)
  SafeGetSkillsUI(self.inst):RemoveSkill(id)
  self.skillIdToIndex[id] = nil
end

function ArkSkillReplica:DoInstallSkill(id, index)
  if not id or id == "" then
    return
  end
  local cfg = self:GetConfigById(id)
  self:RegisterHotkey(id, cfg.hotkey)
  SafeGetSkillsUI(self.inst):AddSkill(id, index)
  self.skillIdToIndex[id] = index
end

function ArkSkillReplica:TrySyncSkillData(id, state)
  if not id or id == "" then
    return
  end
  SafeGetSkillsUI(self.inst):GetSkillById(id):SyncSkillStatus(
    state.status,
    state.level,
    state.energyProgress,
    state.buffProgress,
    state.bulletCount,
    state.activationStacks
  )
end

function ArkSkillReplica:SkillDataDirty(index)
  local oldId = self.skillIds[index]
  local state = self.states[index]
  local newId = state.id
  local hasOldId = oldId ~= nil and oldId ~= ""
  local hasNewId = newId ~= nil and newId ~= ""

  if hasOldId and not hasNewId then
    self:DoUninstallSkill(oldId)
    self.skillIds[index] = nil
    return
  end

  if not hasOldId and hasNewId then
    self:DoInstallSkill(newId, index)
    self.skillIds[index] = newId
    self:TrySyncSkillData(newId, state)
    return
  end

  if hasOldId and hasNewId and oldId ~= newId then
    self:DoUninstallSkill(oldId)
    self:DoInstallSkill(newId, index)
    self.skillIds[index] = newId
    self:TrySyncSkillData(newId, state)
    return
  end

  if hasNewId then
    self:TrySyncSkillData(newId, state)
  end
end

function ArkSkillReplica:GetStateByIndex(index)
  return self.states[index]
end

-- 主机端同步状态到客机
function ArkSkillReplica:SyncSkillStatus(id, data)
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
  if TheNet:IsDedicated() then return end
  local hotkey_mgr = GetHotKeyManager(self.inst)
  local name = getHotkeyName(self.inst, id)
  hotkey_mgr:RestoreDefaultHotkey(name)
end

function ArkSkillReplica:GetHotkey(id)
  if not TheNet:IsDedicated() then
    local hotkey = GetHotKeyManager(self.inst)
    local name = getHotkeyName(self.inst, id)
    return hotkey:GetHotkey(name)
  end
end

function ArkSkillReplica:UnregisterHotkey(id)
  if TheNet:IsDedicated() then return end
  local hotkey = GetHotKeyManager(self.inst)
  local name = getHotkeyName(self.inst, id)
  hotkey:Unregister(name)
end

function ArkSkillReplica:RegisterHotkey(id, hotkey)
  if TheNet:IsDedicated() then return end
  local hotkey_mgr = GetHotKeyManager(self.inst)
  local name = getHotkeyName(self.inst, id)
  hotkey_mgr:Register(name, function()
    -- 弹药模式下再次按会取消
    if self:GetState(id).status == CONSTANTS.SKILL_STATUS.BULLETING then
      self:CancelSkill(id)
    else
      self:TryActivateSkill(id)
    end
  end, hotkey)
end

function ArkSkillReplica:SetHotkey(id, hotkey)
  ArkLogger:Info("Setting hotkey for skill " .. id .. ": " .. tostring(hotkey))
  if not hotkey then return end
  if TheNet:IsDedicated() then return end
  local hotkey_mgr = GetHotKeyManager(self.inst)
  local name = getHotkeyName(self.inst, id)
  -- 检查是否已经有按键了
  local oldHotkey = hotkey_mgr:GetHotkey(name)
  if not oldHotkey then
    self:RegisterHotkey(id, hotkey)
  end
  hotkey_mgr:SetHotkey(name, hotkey)
end

function ArkSkillReplica:TryActivateSkill(id)
  local target = TheInput:GetWorldEntityUnderMouse()
  local targetPos = TheInput:GetWorldPosition()
  local serializedPos = string.format("%.2f,%.2f,%.2f", targetPos.x, targetPos.y, targetPos.z)
  local force = TheInput:IsKeyDown(KEY_CTRL) or TheInput:IsKeyDown(KEY_RCTRL)
  if self.inst.components.ark_skill then
    self.inst.components.ark_skill:GetSkill(id):TryActivate({
      target = target,
      targetPos = targetPos,
      force = force
    })
  else
    SendModRPCToServer(GetModRPC("arkSkill", "ManualActivateSkill"), id, target, serializedPos, force)
  end
end

function ArkSkillReplica:IsActivating(id)
  local state = self:GetState(id)
  return state ~= nil and (state.status == CONSTANTS.SKILL_STATUS.BUFFING or state.status == CONSTANTS.SKILL_STATUS.BULLETING)
end

function ArkSkillReplica:CancelSkill(id)
  if self.inst.components.ark_skill then
    self.inst.components.ark_skill:GetSkill(id):Cancel()
  else
    SendModRPCToServer(GetModRPC("arkSkill", "ManualCancelSkill"), id)
  end
end

return ArkSkillReplica
