local CONSTANTS = require "ark_constants"

local SafeGetArkExtendUi = GenSafeCall(function(inst)
  return inst and inst.HUD and inst.HUD.controls and inst.HUD.controls.arkExtendUi
end)

local SafeGetTalentsUI = GenSafeCall(function(inst)
  return SafeGetArkExtendUi(inst).talents
end)

local MAX_TALENT_COUNT = 6

local ArkTalentReplica = Class(function(self, inst)
  self.inst = inst
  self.states    = {}          -- 索引 -> state
  self.talentIds = {}          -- 索引 -> 天赋id
  self.talentIdToIndex = {}    -- 天赋id -> 索引
  -- 预制 MAX_TALENT_COUNT 个 state，用于同步状态数据
  for i = 1, MAX_TALENT_COUNT do
    local state = NetState(self.inst, "ark_talent")
    self.states[i] = state
    state:Attach(self.inst)
    state:Watch({ "id", "status", "level" }, function()
      self:TalentDataDirty(i)
    end)
  end
end)

function ArkTalentReplica:GetConfigById(id)
  return GetArkTalentConfigById(id)
end

function ArkTalentReplica:AddTalent(id)
  local cfg = self:GetConfigById(id)
  assert(cfg, "No config found for talent id: " .. tostring(id))
  for i, state in pairs(self.states) do
    if state.id == "" then
      state.id = id
      self.talentIdToIndex[id] = i
      return
    end
  end
  assert(false, "No empty slot found for talent id: " .. tostring(id))
end

function ArkTalentReplica:RemoveTalent(id)
  local index = self.talentIdToIndex[id]
  if not index then
    ArkLogger:Error("ark_talent_replica: RemoveTalent failed, id not found " .. tostring(id))
    return
  end
  local state = self.states[index]
  if state.id ~= id then
    ArkLogger:Error("ark_talent_replica: RemoveTalent failed, id mismatch " .. tostring(id))
    return
  end
  state.id = ""
end

function ArkTalentReplica:DoUninstallTalent(id)
  if not id or id == "" then return end
  SafeGetTalentsUI(self.inst):RemoveTalent(id)
  self.talentIdToIndex[id] = nil
end

function ArkTalentReplica:DoInstallTalent(id, index)
  if not id or id == "" then return end
  SafeGetTalentsUI(self.inst):AddTalent(id, index)
  self.talentIdToIndex[id] = index
end

function ArkTalentReplica:TrySyncTalentData(id, state)
  if not id or id == "" then return end
  local talentsUI = SafeGetTalentsUI(self.inst)
  if not talentsUI then return end
  talentsUI:SyncTalentStatus(id, state.status, state.level)
end

function ArkTalentReplica:TalentDataDirty(index)
  local oldId  = self.talentIds[index]
  local state  = self.states[index]
  local newId  = state.id
  local hasOld = oldId ~= nil and oldId ~= ""
  local hasNew = newId ~= nil and newId ~= ""

  if hasOld and not hasNew then
    self:DoUninstallTalent(oldId)
    self.talentIds[index] = nil
    return
  end

  if not hasOld and hasNew then
    self:DoInstallTalent(newId, index)
    self.talentIds[index] = newId
    self:TrySyncTalentData(newId, state)
    return
  end

  if hasOld and hasNew and oldId ~= newId then
    self:DoUninstallTalent(oldId)
    self:DoInstallTalent(newId, index)
    self.talentIds[index] = newId
    self:TrySyncTalentData(newId, state)
    return
  end

  if hasNew then
    self:TrySyncTalentData(newId, state)
  end
end

-- 主机端同步状态到客机
function ArkTalentReplica:SyncTalentStatus(id, data)
  local index = self.talentIdToIndex[id]
  if not index then
    ArkLogger:Error("ark_talent_replica: 未注册的天赋 " .. tostring(id))
    return
  end
  local state = self.states[index]
  if not state then
    ArkLogger:Error("ark_talent_replica: 未找到天赋状态 " .. tostring(id))
    return
  end
  state.status = data.status
  state.level  = data.level
end

return ArkTalentReplica
