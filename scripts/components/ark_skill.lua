local CONSTANTS = require "ark_constants"
local common = require "ark_common"
local utils = require "ark_utils"
local ArkSkill = Class(function(self, inst)
  self.inst = inst
  self.inst:AddTag("ark_skill")
  -- by-id 存储与遍历顺序
  self.skillsById = {}
  self.order = {}
  self.latestById = {}
  -- 读档静默标记：加载期间不触发回调与网络同步
  self._loading = false
end)

local function defaultSkill(skill)
  local function defaultLevelConfigs(levelConfigs)
    local copyLevelConfigs = {}
    for _, levelConfig in ipairs(levelConfigs) do
      local copyLevelConfig = {
        energy = levelConfig.energy or 1,
        buffTime = levelConfig.buffTime or 0.3,
        bullet = levelConfig.bullet or 10,
        maxActivationStacks = levelConfig.maxActivationStacks or 1,
        desc = levelConfig.desc,
        config = levelConfig.config or {},
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
    hotKey = skill.activationMode == CONSTANTS.ACTIVATION_MODE.MANUAL and skill.hotKey or nil,
    levels = defaultLevelConfigs(skill.levels),
  }
  return copySkill
end



-- 单技能对象（SingleSkill）：封装技能自身的运行态与行为
local SingleSkill = Class(function(self, manager, config)
  self.manager = manager
  self.inst = manager.inst
  self.config = config
  self.id = config.id
  -- 运行态数据
  self.data = {
    level = 1,
    status = CONSTANTS.SKILL_STATUS.LOCKED,
    energyProgress = 0,
    buffProgress = 0,
    bullet = 0,
    activationStacks = 0,
    force = false,
  }
  self.levelConfig = config.levels[1]
  -- tag
  self:UpdateLevelTags()
  -- 定时器控制（按帧推进）
  self.timeEnergy = false
  self.timeBuff = false
  -- 注册事件回调
  self._onLocked = {}
  self._onUnlocked = {}
  self._onEnergyRecovering = {}
  self._onActivateReady = {}
  self._onActivate = {}
  self._onDeactivate = {}
  self._onBulletCut = {}
  self._onLevelChange = {}
  self._activateTest = nil
end)

function SingleSkill:IsLoading()
  return self.manager and self.manager._loading
end

-- 事件工具方法
local function _addCallback(list, fn)
  if fn == nil then return end
  for _, cb in ipairs(list) do
    if cb == fn then
      return
    end
  end
  table.insert(list, fn)
end

local function _removeCallback(list, fn)
  if fn == nil then return end
  for i, cb in ipairs(list) do
    if cb == fn then
      table.remove(list, i)
      return
    end
  end
end

function SingleSkill:_Emit(list, eventName, payload)
  if self:IsLoading() then return end
  if payload == nil then payload = {} end
  payload.skillId = payload.skillId or self.id
  payload.level = payload.level or self.data.level
  payload.status = payload.status or self.data.status
  for _, cb in ipairs(list or {}) do
    cb(self.inst, payload)
  end
  if self.inst and self.inst.PushEvent then
    self.inst:PushEvent(eventName, payload)
  end
end

-- 事件注册/反注册接口（相同函数不会重复添加）
function SingleSkill:SetOnLocked(fn)       _addCallback(self._onLocked, fn) end
function SingleSkill:UnsetOnLocked(fn)     _removeCallback(self._onLocked, fn) end

function SingleSkill:SetOnUnlocked(fn)     _addCallback(self._onUnlocked, fn) end
function SingleSkill:UnsetOnUnlocked(fn)   _removeCallback(self._onUnlocked, fn) end

function SingleSkill:SetOnEnergyRecovering(fn)   _addCallback(self._onEnergyRecovering, fn) end
function SingleSkill:UnsetOnEnergyRecovering(fn) _removeCallback(self._onEnergyRecovering, fn) end

function SingleSkill:SetOnActivateReady(fn)   _addCallback(self._onActivateReady, fn) end
function SingleSkill:UnsetOnActivateReady(fn) _removeCallback(self._onActivateReady, fn) end

function SingleSkill:SetOnActive(fn)       _addCallback(self._onActivate, fn) end
function SingleSkill:UnsetOnActive(fn)     _removeCallback(self._onActivate, fn) end

function SingleSkill:SetOnDeactivate(fn)   _addCallback(self._onDeactivate, fn) end
function SingleSkill:UnsetOnDeactivate(fn) _removeCallback(self._onDeactivate, fn) end

function SingleSkill:SetOnBulletCut(fn)    _addCallback(self._onBulletCut, fn) end
function SingleSkill:UnsetOnBulletCut(fn)  _removeCallback(self._onBulletCut, fn) end

function SingleSkill:SetOnLevelChange(fn)   _addCallback(self._onLevelChange, fn) end
function SingleSkill:UnsetOnLevelChange(fn) _removeCallback(self._onLevelChange, fn) end

function SingleSkill:SetActivateTest(fn) self._activateTest = fn end

function SingleSkill:UpdateLevelTags()
  local data = self.data
  for i = 1, CONSTANTS.MAX_SKILL_LEVEL do
    local tag = common.genArkSkillLevelTagById(self.id, i)
    if data.status ~= CONSTANTS.SKILL_STATUS.LOCKED and i == data.level then
      self.inst:AddTag(tag)
    else
      self.inst:RemoveTag(tag)
    end
  end
end

function SingleSkill:StartTimeEnergy()
  self.timeEnergy = true
end
function SingleSkill:StopTimeEnergy()
  self.timeEnergy = false
end
function SingleSkill:StartTimeBuff()
  self.timeBuff = true
end
function SingleSkill:StopTimeBuff()
  self.timeBuff = false
end

function SingleSkill:SetEnergyRecovering(force)
  local data = self.data
  local cfg = self.config
  local lvl = self.levelConfig
  local prevStatus = data.status
  local cancelled = force == true

  data.status = CONSTANTS.SKILL_STATUS.ENERGY_RECOVERING
  if cfg.energyRecoveryMode == CONSTANTS.ENERGY_RECOVERY_MODE.AUTO then
    if data.activationStacks >= lvl.maxActivationStacks then
      self:StopTimeEnergy()
      data.energyProgress = 0
    else
      self:StartTimeEnergy()
    end
  else
    self:StopTimeEnergy()
  end
  self:UpdateLevelTags()
  self.manager:SyncSkillStatus(self.id)

  -- 从 BUFF/BULLET 状态回到充能，视为一次“结束激活”
  if prevStatus == CONSTANTS.SKILL_STATUS.BUFFING or prevStatus == CONSTANTS.SKILL_STATUS.BULLETING then
    self:_Emit(self._onDeactivate, "ark_skill_deactivate", {
      fromStatus = prevStatus,
      cancelled = cancelled,
    })
  end

  -- 进入充能状态事件
  self:_Emit(self._onEnergyRecovering, "ark_skill_energy_recovering", {
    fromStatus = prevStatus,
    cancelled = cancelled,
  })
end

function SingleSkill:SetBuffing()
  self.data.status = CONSTANTS.SKILL_STATUS.BUFFING
  self:StartTimeBuff()
  self:UpdateLevelTags()
  self.manager:SyncSkillStatus(self.id)
end

function SingleSkill:SetBulleting()
  self.data.status = CONSTANTS.SKILL_STATUS.BULLETING
  self:UpdateLevelTags()
  self.manager:SyncSkillStatus(self.id)
end

function SingleSkill:IsActivating()
  return self.data.status == CONSTANTS.SKILL_STATUS.BUFFING or self.data.status == CONSTANTS.SKILL_STATUS.BULLETING
end

function SingleSkill:Lock()
  local data = self.data
  local prevStatus = data.status
  data.status = CONSTANTS.SKILL_STATUS.LOCKED
  self:StopTimeEnergy()
  self:StopTimeBuff()
  data.energyProgress = 0
  data.buffProgress = 0
  data.bullet = 0
  data.activationStacks = 0
  data.force = false
  self:UpdateLevelTags()
  self.manager:SyncSkillStatus(self.id)
  self:_Emit(self._onLocked, "ark_skill_locked", {
    fromStatus = prevStatus,
  })
end

function SingleSkill:Unlock()
  local data = self.data
  if data.status ~= CONSTANTS.SKILL_STATUS.LOCKED and data.status ~= CONSTANTS.SKILL_STATUS.ENERGY_RECOVERING then
    return
  end
  local prevStatus = data.status
  self:SetEnergyRecovering(false)
  self:_Emit(self._onUnlocked, "ark_skill_unlocked", {
    fromStatus = prevStatus,
  })
end

function SingleSkill:SetLevel(level)
  local levelConfig = self.config.levels[level]
  if not levelConfig then return end
  local oldLevel = self.data.level or 1
  self.data.level = level
  self.levelConfig = levelConfig
  self:UpdateLevelTags()
  self.manager:SyncSkillStatus(self.id)
  if oldLevel ~= level then
    self:_Emit(self._onLevelChange, "ark_skill_level_change", {
      oldLevel = oldLevel,
      newLevel = level,
    })
  end
end

function SingleSkill:GetLevelConfig()
  return self.levelConfig.config
end

function SingleSkill:AddEnergyProgress(value)
  local data = self.data
  if data.status ~= CONSTANTS.SKILL_STATUS.ENERGY_RECOVERING then return 0 end
  if data.activationStacks >= self.levelConfig.maxActivationStacks then return 0 end
  local lvl = self.levelConfig
  data.energyProgress = data.energyProgress + value
  local changed = false
  while data.energyProgress >= lvl.energy do
    data.energyProgress = data.energyProgress - lvl.energy
    data.activationStacks = data.activationStacks + 1
    changed = true
    -- 每次可激活次数 +1 时触发
    self:_Emit(self._onActivateReady, "ark_skill_activate_ready", {
      activationStacks = data.activationStacks,
    })
    if data.activationStacks >= lvl.maxActivationStacks then
      self:StopTimeEnergy()
      data.energyProgress = 0
      break
    end
  end
  -- 自动充能时，只在状态变更时同步；其他充能方式每次都需要同步，避免客户端不能展示
  if changed or self.config.energyRecoveryMode ~= CONSTANTS.ENERGY_RECOVERY_MODE.AUTO then
    self.manager:SyncSkillStatus(self.id)
  end
  local leftEnergy = data.energyProgress - lvl.energy
  return leftEnergy
end

function SingleSkill:AddBuffProgress(value)
  local data = self.data
  if data.status ~= CONSTANTS.SKILL_STATUS.BUFFING then return 0 end
  local lvl = self.levelConfig
  data.buffProgress = data.buffProgress + value
  local leftBuff = data.buffProgress - lvl.buffTime
  if leftBuff >= 0 then
    data.buffProgress = leftBuff
    self:SetEnergyRecovering()
    self:StopTimeBuff()
  end
  return leftBuff
end

function SingleSkill:CanActivate(target, targetPos, force)
  local data = self.data
  if data.status == CONSTANTS.SKILL_STATUS.LOCKED then return false end
  if data.activationStacks <= 0 then return false end
  if self._activateTest then
    return self:_activateTest(target, targetPos, force)
  end
  return true
end

function SingleSkill:Activate(target, targetPos, force)
  if not self:CanActivate(target, targetPos, force) then return false end
  local data = self.data
  data.activationStacks = data.activationStacks - 1
  if self.config.bullet then
    data.bullet = self.levelConfig.bullet
  else
    data.buffProgress = 0
  end
  data.force = force
  if self.config.bullet then
    self:SetBulleting()
  else
    self:SetBuffing()
  end
  self:_Emit(self._onActivate, "ark_skill_activated", {
    force = force,
    target = target,
    targetPos = targetPos,
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
  if value == nil then value = 1 end
  local data = self.data
  data.bullet = data.bullet - value
  if data.bullet < 0 then
    data.bullet = 0
  end
  self.manager:SyncSkillStatus(self.id)
  self:_Emit(self._onBulletCut, "ark_skill_bullet_cut", {
    cut = value,
    bullet = data.bullet,
  })
  if data.bullet == 0 then
    self:SetEnergyRecovering(false)
  end
end

function SingleSkill:Step(dt)
  -- buff 期间不自动时间充能；buff 多余的时间根据充能模式决定是否叠加到能量
  if self.timeBuff then
    local leftBuff = self:AddBuffProgress(dt)
    -- 如果状态流转到了 自动充能，且有剩余时间，则将剩余时间加到能量上
    if leftBuff > 0 and self.timeEnergy then
        self:AddEnergyProgress(dt + leftBuff)
    end
  else
    if self.timeEnergy then self:AddEnergyProgress(dt) end
  end
end

function SingleSkill:OnLoad(saved)
  if not saved then return end
  -- 静默合并
  self.data = utils.mergeTable(self.data, saved)
  local maxLevel = #self.config.levels
  self.data.level = math.min(self.data.level or 1, maxLevel)
  self.levelConfig = self.config.levels[self.data.level]
  if self.data.status == CONSTANTS.SKILL_STATUS.BUFFING then
    self.timeBuff = true; self.timeEnergy = false
  elseif self.data.status == CONSTANTS.SKILL_STATUS.ENERGY_RECOVERING then
    if self.config.energyRecoveryMode == CONSTANTS.ENERGY_RECOVERY_MODE.AUTO and self.data.activationStacks < self.levelConfig.maxActivationStacks then
      self.timeEnergy = true
    else
      self.timeEnergy = false
      self.data.energyProgress = 0
    end
    self.timeBuff = false
  elseif self.data.status == CONSTANTS.SKILL_STATUS.LOCKED then
    -- LOCKED 状态下应该重置所有充能相关的数据
    self.data.energyProgress = 0
    self.data.buffProgress = 0
    self.data.activationStacks = 0
    self.timeBuff = false; self.timeEnergy = false
  else
    self.timeBuff = false; self.timeEnergy = false
  end
  self:UpdateLevelTags()
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
  self.latestById[id] = utils.cloneTable(skill.data)
  -- 初始化等级 Tag（不触发网络/事件）
  skill:UpdateLevelTags()
  -- 开始更新
  self.inst:StartUpdatingComponent(self)
  -- 下一帧安装 UI（聚合本帧内全部已注册技能），仅调度一次
  if not self._ui_scheduled then
    self._ui_scheduled = true
    self.inst:DoTaskInTime(0, function()
      self._ui_scheduled = false
      if self.inst.userid ~= nil then
        local payload = { skills = {} }
        for _, sid in ipairs(self.order) do
          local cfg = self.skillsById[sid].config
          table.insert(payload.skills, cfg)
        end
        SendModRPCToClient(GetClientModRPC("arkSkill", "SetupArkSkillUi"), self.inst.userid, json.encode(payload))
      end
    end)
  end
  return skill
end

-- 便捷的几个方法（by-id）
function ArkSkill:GetSkill(id)
  return self.skillsById and self.skillsById[id] or nil
end

function ArkSkill:SyncSkillStatus(id, notice)
  local s = self:GetSkill(id)
  if not s then return end
  local data = s.data
  if self._loading then
    -- 静默读档：不发RPC，不触发回调，仅刷新latest快照
    self.latestById[id] = utils.cloneTable(data)
    return
  end
  if self.inst.userid ~= nil then
    SendModRPCToClient(GetClientModRPC("arkSkill", "SyncSkillStatus"), self.inst.userid, id, data.status, data.level,
      data.energyProgress, data.buffProgress, data.bullet, data.activationStacks)
  end
  if notice == nil then notice = true end
  if self.onSkillStatusChange and notice then
    local latestData = self.latestById[id]
    self.latestById[id] = utils.cloneTable(data)
    self.onSkillStatusChange(id, data, latestData)
  end
end

function ArkSkill:RequestSyncSkillStatus(id)
  self:SyncSkillStatus(id, false)
end



function ArkSkill:OnUpdate(dt)
  self.OnUpdate = function(self, dt)
    for _, id in ipairs(self.order) do
      local s = self.skillsById[id]
      if s and s.Step then s:Step(dt) end
    end
  end
  self.OnUpdate(self, dt)
end

function ArkSkill:OnSave()
  local data = { order = utils.cloneTable(self.order), skills = {} }
  for id, skill in pairs(self.skillsById) do
    data.skills[id] = skill.data
  end
  return data
end

function ArkSkill:OnLoad(data)
  if not data or not data.skills then
    return
  end
  self._loading = true
  for id, skillData in pairs(data.skills) do
    local s = self.skillsById and self.skillsById[id]
    if s and s.OnLoad then
      s:OnLoad(skillData)
    end
  end
  self._loading = false
end
return ArkSkill
