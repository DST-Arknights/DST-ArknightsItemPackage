local CONSTANTS = require "ark_constants"
local common = require "ark_common"
local utils = require "ark_utils"

local EFFECTS_SYNC_REASON = CONSTANTS.SKILL_EFFECTS_SYNC_REASON
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

  -- 技能效果同步（ark_skill_effects_sync）专用：记录上一次已同步的“效果态快照”
  -- 注意：此字段不参与存档，仅用于计算 from/to 与 changed。
  self._effects_last_state = nil
end)

local function _BuildEffectsState(data)
  return {
    status = data.status,
    level = data.level,
    energyProgress = data.energyProgress,
    buffProgress = data.buffProgress,
    bulletCount = data.bulletCount,
    activationStacks = data.activationStacks,
    force = data.force,
    tickEnergy = data.tickEnergy,
    tickBuff = data.tickBuff,
  }
end

local function _BuildChangedMap(from, to)
  local changed = {}
  for k, v in pairs(to) do
    if from[k] ~= v then
      changed[k] = true
    end
  end
  for k, v in pairs(from) do
    if to[k] ~= v then
      changed[k] = true
    end
  end
  return changed
end

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

-- 统一的“效果态同步”事件：用于让外部模组在【存档恢复】和【状态切换】时都能幂等地恢复/校准一次性挂载效果。
-- 事件名：ark_skill_effects_sync
-- payload:
--   reason: CONSTANTS.SKILL_EFFECTS_SYNC_REASON.*
--   from/to: 效果态快照（表）
--   prev: 上一次效果态快照（表，来自存档/上次切换前），用于在 load 时也能拿到“上次状态”
--   fromStatus/fromLevel: 便捷字段
--   prevStatus/prevLevel: 便捷字段
--   changed: 变更字段集合（map: key->true）
function SingleSkill:_EmitEffectsSync(reason)
  local to = _BuildEffectsState(self.data)
  local prev = self.data.effects_prev
      or {
        status = self.data.prevStatus,
        level = self.data.prevLevel,
      }
      or {}

  local r = reason or EFFECTS_SYNC_REASON.MANUAL

  -- from/to 表示“本次同步前后的效果态”。
  -- 对于 load/register，这不是一次状态切换，而是对账；因此 from 默认等于 to。
  local from
  if self._effects_last_state ~= nil then
    from = self._effects_last_state
  elseif r == EFFECTS_SYNC_REASON.STATUS_CHANGE or r == EFFECTS_SYNC_REASON.LEVEL_CHANGE then
    from = prev
  else
    from = to
  end

  -- 防止监听者修改 payload 表影响内部状态
  local payloadFrom = utils.cloneTable(from)
  local payloadTo = utils.cloneTable(to)
  local payloadPrev = utils.cloneTable(prev)

  self:_Emit("ark_skill_effects_sync", {
    reason = r,
    from = payloadFrom,
    to = payloadTo,
    prev = payloadPrev,
    fromStatus = payloadFrom.status,
    fromLevel = payloadFrom.level,
    prevStatus = payloadPrev.status,
    prevLevel = payloadPrev.level,
    changed = _BuildChangedMap(payloadFrom, payloadTo),
  })

  -- 内部保留一份不可被外部持有的快照
  self._effects_last_state = utils.cloneTable(to)
end

-- 对外公开：允许外部在需要时主动触发一次“效果态同步”（例如自身初始化完成后）。
function SingleSkill:SyncEffects(reason)
  self:_EmitEffectsSync(reason)
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

-- 效果同步事件（推荐依赖方使用此事件做幂等挂载/卸载）
function SingleSkill:SetOnEffectsSync(fn)
  self:_AddCallback("ark_skill_effects_sync", fn)
end
function SingleSkill:UnsetOnEffectsSync(fn)
  self:_RemoveCallback("ark_skill_effects_sync", fn)
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

  -- 保存“上一次效果态快照”（用于存档恢复/外部无感对账）
  data.effects_prev = _BuildEffectsState(data)

  -- 记录上一次状态（用于存档恢复与事件 payload）
  data.prevStatus = prevStatus

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

  -- 效果态同步：状态变更后，要求外部将挂载效果校准到当前状态

  self:_EmitEffectsSync(EFFECTS_SYNC_REASON.STATUS_CHANGE)

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
  data.effects_prev = _BuildEffectsState(data)
  data.prevStatus = data.status
  data.status = CONSTANTS.SKILL_STATUS.BUFFING
  data.tickBuff = true
  data.tickEnergy = false
  self.manager:SyncSkillStatus(self.id)

  self:_EmitEffectsSync(EFFECTS_SYNC_REASON.STATUS_CHANGE)
end

function SingleSkill:SetBulleting()
  local data = self.data
  data.effects_prev = _BuildEffectsState(data)
  data.prevStatus = data.status
  data.status = CONSTANTS.SKILL_STATUS.BULLETING
  self.manager:SyncSkillStatus(self.id)
  data.tickEnergy = false
  data.tickBuff = false
  self:_EmitEffectsSync(EFFECTS_SYNC_REASON.STATUS_CHANGE)
end

function SingleSkill:IsActivating()
  return self.data.status == CONSTANTS.SKILL_STATUS.BUFFING or self.data.status == CONSTANTS.SKILL_STATUS.BULLETING
end

function SingleSkill:Lock()
  local data = self.data
  local prevStatus = data.status
  data.effects_prev = _BuildEffectsState(data)
  data.prevStatus = prevStatus
  data.status = CONSTANTS.SKILL_STATUS.LOCKED
  data.tickEnergy = false
  data.tickBuff = false
  data.energyProgress = 0
  data.buffProgress = 0
  data.bulletCount = 0
  data.activationStacks = 0
  data.force = false
  self.manager:SyncSkillStatus(self.id)

  self:_EmitEffectsSync(EFFECTS_SYNC_REASON.STATUS_CHANGE)
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
  self.data.effects_prev = _BuildEffectsState(self.data)
  self.data.prevLevel = oldLevel
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

  self:_EmitEffectsSync(EFFECTS_SYNC_REASON.LEVEL_CHANGE)
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

  -- 兼容空值：若旧存档没有 prev 字段，则默认与当前一致，避免外部误判。
  if self.data.prevStatus == nil then
    self.data.prevStatus = self.data.status
  end
  if self.data.prevLevel == nil then
    self.data.prevLevel = self.data.level
  end

  if self.data.effects_prev == nil then
    self.data.effects_prev = {
      status = self.data.prevStatus,
      level = self.data.prevLevel,
    }
  end

  self.manager:SyncSkillStatus(self.id)
  self:RefreshTag()
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

  -- 延迟一帧触发一次效果态同步，保证外部模组有机会先注册监听。
  -- （新技能默认 LOCKED，也应当让外部有机会做一次幂等清理/初始化。）
  self.inst:DoTaskInTime(0, function()
    if self.skillsById and self.skillsById[id] then
      self.skillsById[id]:SyncEffects(EFFECTS_SYNC_REASON.REGISTER)
    end
  end)
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

-- 对外：按技能 id 触发一次效果态同步
function ArkSkill:SyncSkillEffects(id, reason)
  local s = self:GetSkill(id)
  if not s then
    return
  end
  s:SyncEffects(reason)
end

-- 对外：对所有技能触发一次效果态同步
function ArkSkill:SyncAllSkillEffects(reason)
  for _, s in pairs(self.skillsById) do
    if s and s.SyncEffects then
      s:SyncEffects(reason)
    end
  end
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

  -- 存档恢复后：延迟一帧，对所有技能做一次“效果态同步”
  -- 让依赖方可以在一个事件里同时处理：
  --   - 读档恢复（reason=CONSTANTS.SKILL_EFFECTS_SYNC_REASON.LOAD）
  --   - 运行时切换（reason=CONSTANTS.SKILL_EFFECTS_SYNC_REASON.STATUS_CHANGE/LEVEL_CHANGE）
  self.inst:DoTaskInTime(0, function()
    if self.inst and self.inst.components and self.inst.components.ark_skill == self then
      self:SyncAllSkillEffects(EFFECTS_SYNC_REASON.LOAD)
    end
  end)
end
return ArkSkill
