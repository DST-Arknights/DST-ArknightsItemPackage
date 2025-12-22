local CONSTANTS = require "ark_constants"
local common = require "ark_common"
local utils = require "ark_utils"
local ArkSkill = Class(function(self, inst)
  self.inst = inst
  self.inst:AddTag("ark_skill")
  -- by-id 存储与遍历顺序
  self.skillsById = {}
  self.order = {}
end)

local function defaultSkill(skill)
  local function defaultLevelConfigs(levelConfigs)
    local copyLevelConfigs = {}
    for _, levelConfig in ipairs(levelConfigs) do
      local copyLevelConfig = {
        activationEnergy = levelConfig.activationEnergy or 1,
        buffDuration = levelConfig.buffDuration or 0.3,
        bulletCount = levelConfig.bulletCount,
        maxActivationStacks = levelConfig.maxActivationStacks or 1,
        desc = levelConfig.desc,
        config = levelConfig.config or {}
      }
      table.insert(copyLevelConfigs, copyLevelConfig)
    end
    return copyLevelConfigs
  end
  local copySkill = {
    id = common.normalizeSkillId(skill.id),
    atlas = skill.atlas,
    image = skill.image,
    name = skill.name,
    lockedDesc = skill.lockedDesc,
    energyRecoveryMode = skill.energyRecoveryMode or CONSTANTS.ENERGY_RECOVERY_MODE.AUTO,
    activationMode = skill.activationMode or CONSTANTS.ACTIVATION_MODE.MANUAL,
    hotkey = skill.activationMode == CONSTANTS.ACTIVATION_MODE.MANUAL and skill.hotkey or nil,
    levels = defaultLevelConfigs(skill.levels)
  }
  return copySkill
end

-- 单技能对象（SingleSkill）：封装技能自身的运行态与行为
local SingleSkill = Class(function(self, manager, config)
  self.manager = manager
  self.inst = manager.inst
  self.config = config
  self.id = config.id
  -- 运行态数据（含定时器控制）
  self.data = {
    level = 1,
    status = CONSTANTS.SKILL_STATUS.LOCKED,
    energyProgress = 0,
    buffProgress = 0,
    bulletCount = 0,
    activationStacks = 0,
    force = false,
    tickEnergy = false,
    tickBuff = false
  }
  self.levelConfig = config.levels[1]
  -- 注册事件回调（按事件名索引）
  self._callbacks = {}
  self._activateTest = nil
end)

-- 事件工具方法
function SingleSkill:_AddCallback(eventName, fn)
  if fn == nil then
    return
  end
  local list = self._callbacks[eventName]
  if not list then
    list = {}
    self._callbacks[eventName] = list
  end
  for _, cb in ipairs(list) do
    if cb == fn then
      return
    end
  end
  table.insert(list, fn)
end

function SingleSkill:_RemoveCallback(eventName, fn)
  if fn == nil then
    return
  end
  local list = self._callbacks[eventName]
  if not list then
    return
  end
  for i, cb in ipairs(list) do
    if cb == fn then
      table.remove(list, i)
      return
    end
  end
end

function SingleSkill:_Emit(eventName, payload)
  if payload == nil then
    payload = {}
  end
  payload.skillId = payload.skillId or self.id
  payload.level = payload.level or self.data.level
  payload.status = payload.status or self.data.status
  local list = self._callbacks[eventName]
  if list then
    for _, cb in ipairs(list) do
      cb(self.inst, payload)
    end
  end
  self.inst:PushEvent(eventName, payload)
end

-- 事件注册/反注册接口（相同函数不会重复添加）
function SingleSkill:SetOnLocked(fn)
  self:_AddCallback("ark_skill_locked", fn)
end
function SingleSkill:UnsetOnLocked(fn)
  self:_RemoveCallback("ark_skill_locked", fn)
end

function SingleSkill:SetOnUnlocked(fn)
  self:_AddCallback("ark_skill_unlocked", fn)
end
function SingleSkill:UnsetOnUnlocked(fn)
  self:_RemoveCallback("ark_skill_unlocked", fn)
end

function SingleSkill:SetOnEnergyRecovering(fn)
  self:_AddCallback("ark_skill_energy_recovering", fn)
end
function SingleSkill:UnsetOnEnergyRecovering(fn)
  self:_RemoveCallback("ark_skill_energy_recovering", fn)
end

function SingleSkill:SetOnActivateReady(fn)
  self:_AddCallback("ark_skill_activate_ready", fn)
end
function SingleSkill:UnsetOnActivateReady(fn)
  self:_RemoveCallback("ark_skill_activate_ready", fn)
end

function SingleSkill:SetOnActive(fn)
  self:_AddCallback("ark_skill_activated", fn)
end
function SingleSkill:UnsetOnActive(fn)
  self:_RemoveCallback("ark_skill_activated", fn)
end

function SingleSkill:SetOnDeactivate(fn)
  self:_AddCallback("ark_skill_deactivate", fn)
end
function SingleSkill:UnsetOnDeactivate(fn)
  self:_RemoveCallback("ark_skill_deactivate", fn)
end

function SingleSkill:SetOnBulletCut(fn)
  self:_AddCallback("ark_skill_bullet_cut", fn)
end
function SingleSkill:UnsetOnBulletCut(fn)
  self:_RemoveCallback("ark_skill_bullet_cut", fn)
end

function SingleSkill:SetOnLevelChange(fn)
  self:_AddCallback("ark_skill_level_change", fn)
end
function SingleSkill:UnsetOnLevelChange(fn)
  self:_RemoveCallback("ark_skill_level_change", fn)
end

function SingleSkill:SetActivateTest(fn)
  self._activateTest = fn
end

function SingleSkill:SetEnergyRecovering(force)
  local data = self.data
  local cfg = self.config
  local lvl = self.levelConfig
  local prevStatus = data.status
  force = force == true

  data.status = CONSTANTS.SKILL_STATUS.ENERGY_RECOVERING
  if cfg.energyRecoveryMode == CONSTANTS.ENERGY_RECOVERY_MODE.AUTO then
    if data.activationStacks >= lvl.maxActivationStacks then
      data.tickEnergy = false
      data.energyProgress = 0
    else
      data.tickEnergy = true
    end
  else
    data.tickEnergy = false
  end
  self.manager:SyncSkillStatus(self.id)

  -- 从 BUFF/BULLET 状态回到充能，视为一次“结束激活”
  if prevStatus == CONSTANTS.SKILL_STATUS.BUFFING or prevStatus == CONSTANTS.SKILL_STATUS.BULLETING then
    self:_Emit("ark_skill_deactivate", {
      fromStatus = prevStatus,
      force = force
    })
  end

  -- 进入充能状态事件
  self:_Emit("ark_skill_energy_recovering", {
    fromStatus = prevStatus,
    force = force
  })
end

function SingleSkill:SetBuffing()
  self.data.status = CONSTANTS.SKILL_STATUS.BUFFING
  self.data.tickBuff = true
  self.manager:SyncSkillStatus(self.id)
end

function SingleSkill:SetBulleting()
  self.data.status = CONSTANTS.SKILL_STATUS.BULLETING
  self.manager:SyncSkillStatus(self.id)
end

function SingleSkill:IsActivating()
  return self.data.status == CONSTANTS.SKILL_STATUS.BUFFING or self.data.status == CONSTANTS.SKILL_STATUS.BULLETING
end

function SingleSkill:Lock()
  local data = self.data
  local prevStatus = data.status
  data.status = CONSTANTS.SKILL_STATUS.LOCKED
  data.tickEnergy = false
  data.tickBuff = false
  data.energyProgress = 0
  data.buffProgress = 0
  data.bulletCount = 0
  data.activationStacks = 0
  data.force = false
  self.manager:SyncSkillStatus(self.id)
  self:_Emit("ark_skill_locked", {
    fromStatus = prevStatus
  })
end

function SingleSkill:Unlock()
  local data = self.data
  if data.status ~= CONSTANTS.SKILL_STATUS.LOCKED then
    return
  end
  local prevStatus = data.status
  self:SetEnergyRecovering()
  self:_Emit("ark_skill_unlocked", {
    fromStatus = prevStatus
  })
end

function SingleSkill:SetLevel(level)
  local levelConfig = self.config.levels[level]
  if not levelConfig then
    return
  end
  local oldLevel = self.data.level or 1
  self.data.level = level
  self.levelConfig = levelConfig
  self.manager:SyncSkillStatus(self.id)
  if oldLevel ~= level then
    self:_Emit("ark_skill_level_change", {
      oldLevel = oldLevel,
      newLevel = level
    })
  end
end

function SingleSkill:GetLevelConfig()
  return self.levelConfig.config
end

function SingleSkill:AddEnergyProgress(value)
  local data = self.data
  if data.status ~= CONSTANTS.SKILL_STATUS.ENERGY_RECOVERING then
    return 0
  end
  if data.activationStacks >= self.levelConfig.maxActivationStacks then
    return 0
  end
  local lvl = self.levelConfig
  data.energyProgress = data.energyProgress + value
  local changed = false
  while data.energyProgress >= lvl.activationEnergy do
    data.energyProgress = data.energyProgress - lvl.activationEnergy
    data.activationStacks = data.activationStacks + 1
    changed = true
    -- 每次可激活次数 +1 时触发
    self:_Emit("ark_skill_activate_ready", {
      activationStacks = data.activationStacks
    })
    if data.activationStacks >= lvl.maxActivationStacks then
      data.tickEnergy = false
      data.energyProgress = 0
      break
    end
  end
  -- 自动充能时，只在状态变更时同步；其他充能方式每次都需要同步，避免客户端不能展示
  if changed or self.config.energyRecoveryMode ~= CONSTANTS.ENERGY_RECOVERY_MODE.AUTO then
    self.manager:SyncSkillStatus(self.id)
  end
  local leftEnergy = data.energyProgress - lvl.activationEnergy
  return leftEnergy
end

function SingleSkill:AddBuffProgress(value)
  local data = self.data
  if data.status ~= CONSTANTS.SKILL_STATUS.BUFFING then
    return 0
  end
  local lvl = self.levelConfig
  data.buffProgress = data.buffProgress + value
  local leftBuff = data.buffProgress - lvl.buffDuration
  if leftBuff >= 0 then
    data.buffProgress = leftBuff
    self:SetEnergyRecovering()
    data.tickBuff = false
  end
  return leftBuff
end

function SingleSkill:CanActivate(target, targetPos, force)
  local data = self.data
  if data.status == CONSTANTS.SKILL_STATUS.LOCKED then
    return false
  end
  if data.activationStacks <= 0 then
    return false
  end
  if self._activateTest then
    return self:_activateTest(target, targetPos, force)
  end
  return true
end

function SingleSkill:Activate(target, targetPos, force)
  if not self:CanActivate(target, targetPos, force) then
    return false
  end
  local data = self.data
  data.activationStacks = data.activationStacks - 1
  if self.levelConfig.bulletCount then
    data.bulletCount = self.levelConfig.bulletCount
  else
    data.buffProgress = 0
  end
  data.force = force
  if self.levelConfig.bulletCount then
    self:SetBulleting()
  else
    self:SetBuffing()
  end
  self:_Emit("ark_skill_activated", {
    force = force,
    target = target,
    targetPos = targetPos
  })
  return true
end

function SingleSkill:TryActivate(...)
  return self:Activate(...)
end

function SingleSkill:Cancel()
  self.data.force = false
  self:SetEnergyRecovering(true)
end

function SingleSkill:CutBullet(value)
  if value == nil then
    value = 1
  end
  local data = self.data
  data.bulletCount = data.bulletCount - value
  if data.bulletCount < 0 then
    data.bulletCount = 0
  end
  self.manager:SyncSkillStatus(self.id)
  self:_Emit("ark_skill_bullet_cut", {
    cut = value,
    bulletCount = data.bulletCount
  })
  if data.bulletCount == 0 then
    self:SetEnergyRecovering()
  end
end

function SingleSkill:Step(dt)
  local data = self.data
  -- buff 期间不自动时间充能；buff 多余的时间根据充能模式决定是否叠加到能量
  if data.tickBuff then
    local leftBuff = self:AddBuffProgress(dt)
    -- 如果状态流转到了 自动充能，且有剩余时间，则将剩余时间加到能量上
    if leftBuff > 0 and data.tickEnergy then
      self:AddEnergyProgress(dt + leftBuff)
    end
  elseif data.tickEnergy then
    self:AddEnergyProgress(dt)
  end
end

function SingleSkill:OnLoad(saved)
  if not saved then
    return
  end
  self.data = utils.mergeTable(self.data, saved)
  local maxLevel = #self.config.levels
  self.data.level = math.min(self.data.level or 1, maxLevel)
  self.levelConfig = self.config.levels[self.data.level]
  self.manager:SyncSkillStatus(self.id)
end

function ArkSkill:RegisterSkill(config)
  assert(config and config.id, "RegisterSkill requires config.id")
  config = defaultSkill(config)
  local id = config.id
  if self.skillsById[id] then
    return self.skillsById[id]
  end
  local skill = SingleSkill(self, config)
  self.skillsById[id] = skill
  table.insert(self.order, id)

  -- 开始更新
  self.inst:StartUpdatingComponent(self)
  self.inst.replica.ark_skill:RegisterSkill(config)
  return skill
end

-- 便捷的几个方法（by-id）
function ArkSkill:GetSkill(id)
  return self.skillsById[id]
end

function ArkSkill:SyncSkillStatus(id)
  local s = self:GetSkill(id)
  if not s then
    return
  end
  self.inst.replica.ark_skill:SyncSkillStatus(id, s.data)
end

function ArkSkill:RequestSyncSkillStatus(id)
  self:SyncSkillStatus(id)
end

function ArkSkill:OnUpdate(dt)
  for _, id in ipairs(self.order) do
    local s = self.skillsById[id]
    if s and s.Step then
      s:Step(dt)
    end
  end
end

function ArkSkill:OnSave()
  local data = {
    order = self.order,
    skills = {}
  }
  for id, skill in pairs(self.skillsById) do
    data.skills[id] = skill.data
  end
  return data
end

function ArkSkill:OnLoad(data)
  if not data or not data.skills then
    return
  end
  for id, skillData in pairs(data.skills) do
    local s = self.skillsById[id]
    if s and s.OnLoad then
      s:OnLoad(skillData)
    end
  end
end
return ArkSkill
