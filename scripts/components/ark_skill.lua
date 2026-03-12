local CONSTANTS = require "ark_constants"
local common = require "ark_common"
local utils = require "ark_utils"

local ArkSkill = Class(function(self, inst)
  self.inst = inst
  self.inst:AddTag("ark_skill")
  self.skillsById = {}
  self.skillCount = 0
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
    id = skill.id,
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

function SingleSkill:_EmitActivateEffect(payload)
  local data = self.data
  self:_Emit("ark_skill_activate_effect", {
    source = payload.source,
    target = payload.target,
    targetPos = payload.targetPos,
    force = data.force,
    energyProgress = data.energyProgress,
    buffProgress = data.buffProgress,
    bulletCount = data.bulletCount,
    activationStacks = data.activationStacks,
  })
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

-- 持续效果应用事件：正常激活时在 activate 之后触发，读档恢复时只触发此事件。
function SingleSkill:SetOnActivateEffect(fn)
  self:_AddCallback("ark_skill_activate_effect", fn)
end
function SingleSkill:UnsetOnActivateEffect(fn)
  self:_RemoveCallback("ark_skill_activate_effect", fn)
end

function SingleSkill:SetOnActivate(fn)
  self:_AddCallback("ark_skill_activate", fn)
end
function SingleSkill:UnsetOnActivate(fn)
  self:_RemoveCallback("ark_skill_activate", fn)
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
  data.tickBuff = false
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
  local data = self.data
  data.status = CONSTANTS.SKILL_STATUS.BUFFING
  data.tickBuff = true
  data.tickEnergy = false
  self.manager:SyncSkillStatus(self.id)
end

function SingleSkill:SetBulleting()
  local data = self.data
  data.status = CONSTANTS.SKILL_STATUS.BULLETING
  self.manager:SyncSkillStatus(self.id)
  data.tickEnergy = false
  data.tickBuff = false
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

  if prevStatus == CONSTANTS.SKILL_STATUS.BUFFING or prevStatus == CONSTANTS.SKILL_STATUS.BULLETING then
    self:_Emit("ark_skill_deactivate", {
      fromStatus = prevStatus,
      force = false
    })
  end
  self:_Emit("ark_skill_locked", {
    fromStatus = prevStatus
  })
  self:RefreshTag()
end

function SingleSkill:Unlock()
  local data = self.data
  if data.status ~= CONSTANTS.SKILL_STATUS.LOCKED then
    return
  end
  local prevStatus = data.status
  self:_Emit("ark_skill_unlocked", {
    fromStatus = prevStatus
  })
  self:SetEnergyRecovering()
  self:RefreshTag()
end

function SingleSkill:RefreshTag()
  -- task任务, 第一次prefab是没初始化的
  if self.refreshTagTask ~= nil then
    return
  end
  self.refreshTagTask = self.inst:DoTaskInTime(0, function()
    self.refreshTagTask = nil
    for level in pairs(self.config.levels) do
      local builder_tag = common.genArkSkillLevelUpPrefabNameById(self.inst.prefab, self.id, level)
      if level == self.data.level and self.data.status ~= CONSTANTS.SKILL_STATUS.LOCKED then
        self.inst:AddTag(builder_tag)
      else
        self.inst:RemoveTag(builder_tag)
      end
    end
  end)
end

function SingleSkill:GetLevel()
  return self.data.level or 1
end

function SingleSkill:SetLevel(level)
  local levelConfig = self.config.levels[level]
  if not levelConfig then
    return
  end
  local oldLevel = self.data.level or 1
  if oldLevel == level then
    return
  end
  self.data.level = level
  self.levelConfig = levelConfig

  -- 等级变化后，按新上限修正激活层数，并重算是否继续自动充能
  if self.data.activationStacks > levelConfig.maxActivationStacks then
    self.data.activationStacks = levelConfig.maxActivationStacks
  end

  if self.data.status == CONSTANTS.SKILL_STATUS.ENERGY_RECOVERING then
    if self.config.energyRecoveryMode == CONSTANTS.ENERGY_RECOVERY_MODE.AUTO then
      self.data.tickEnergy = self.data.activationStacks < levelConfig.maxActivationStacks
      if not self.data.tickEnergy then
        self.data.energyProgress = 0
      end
    else
      self.data.tickEnergy = false
    end
  end

  self.manager:SyncSkillStatus(self.id)

  if oldLevel ~= level then
    self:_Emit("ark_skill_level_change", {
      oldLevel = oldLevel,
      newLevel = level
    })
  end
  -- self:SetEnergyRecovering()
  self:RefreshTag()
end

function SingleSkill:GetLevelConfig()
  return self.levelConfig.config
end

function SingleSkill:AddEnergyProgress(value, ignoreSync)
  local data = self.data
  if data.status ~= CONSTANTS.SKILL_STATUS.ENERGY_RECOVERING and data.status ~= CONSTANTS.SKILL_STATUS.BUFFING then
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
  if changed or self.config.energyRecoveryMode ~= CONSTANTS.ENERGY_RECOVERY_MODE.AUTO or not ignoreSync then
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

function SingleSkill:CanActivate(params)
  if not params then params = {} end
  local data = self.data
  if data.status == CONSTANTS.SKILL_STATUS.LOCKED then
    return false
  end
  if data.activationStacks <= 0 then
    return false
  end
  if self._activateTest then
    return self._activateTest(self.inst, {
      target = params.target,
      targetPos = params.targetPos,
      force = params.force
    })
  end
  return true
end

function SingleSkill:Activate(params)
  local data = self.data
  data.activationStacks = data.activationStacks - 1
  if self.levelConfig.bulletCount then
    data.bulletCount = self.levelConfig.bulletCount
  else
    data.buffProgress = 0
  end
  data.force = params.force
  if self.levelConfig.bulletCount then
    self:SetBulleting()
  else
    self:SetBuffing()
  end
  self:_Emit("ark_skill_activate", params)
  self:_EmitActivateEffect({
    source = "activate",
    target = params.target,
    targetPos = params.targetPos,
  })
  return true
end

function SingleSkill:TryActivate(params)
  if not params then params = { target = nil, targetPos = nil, force = false } end
  if not self:CanActivate(params) then
    return false
  end
  return self:Activate(params)
end

function SingleSkill:Cancel()
  self.data.force = false
  self.data.tickBuff = false
  if self.levelConfig.bulletCount then
    self:SetEnergyRecovering(true)
  end
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
      self:AddEnergyProgress(dt + leftBuff, true)
    end
  elseif data.tickEnergy then
    self:AddEnergyProgress(dt, true)
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
  self:RefreshTag()

  if self:IsActivating() then
    self:_EmitActivateEffect({ source = "load" })
  end
end

function SingleSkill:OnRemoveFromEntity()
  if self.refreshTagTask then
    self.refreshTagTask:Cancel()
    self.refreshTagTask = nil
  end
  self:Cancel()
end

function ArkSkill:RegisterSkill(config)
  assert(config and config.id, "RegisterSkill requires config.id")
  config = defaultSkill(config)
  local id = config.id
  if self.skillsById[id] then
    return self.skillsById[id]
  end
  self.skillCount = self.skillCount + 1
  config.index = self.skillCount
  local skill = SingleSkill(self, config)
  self.skillsById[id] = skill

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
  for _, s in pairs(self.skillsById) do
    if s and s.Step then
      s:Step(dt)
    end
  end
end

function ArkSkill:OnSave()
  local data = {
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

-- OnRemoveFromEntity
function ArkSkill:OnRemoveFromEntity()
  for _, s in pairs(self.skillsById) do
    if s and s.OnRemoveFromEntity then
      s:OnRemoveFromEntity()
    end
  end
end
return ArkSkill
