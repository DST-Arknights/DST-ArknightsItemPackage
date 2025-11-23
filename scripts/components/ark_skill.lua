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
  skill.id = common.normalizeSkillId(skill.id)
  skill.energyRecoveryMode = skill.energyRecoveryMode or CONSTANTS.ENERGY_RECOVERY_MODE.AUTO
  skill.activationMode = skill.activationMode or CONSTANTS.ACTIVATION_MODE.MANUAL
  -- 能自动触发的技能关闭快捷键
  if skill.activationMode ~= CONSTANTS.ACTIVATION_MODE.MANUAL then
    skill.hotKey = nil
  end
  for _, levelConfig in ipairs(skill.levels) do
    levelConfig.energy = levelConfig.energy or 1
    levelConfig.buffTime = levelConfig.buffTime or 0.3
    levelConfig.bullet = levelConfig.bullet or 10
    levelConfig.maxActivationStacks = levelConfig.maxActivationStacks or 1
  end
  return skill
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
  -- 定时器控制（按帧推进）
  self.timeEnergy = false
  self.timeBuff = false
  -- 注册事件回调
  self._onLocked = {}
  self._onUnlocked = {}
  self._onEnergyRecovering = {}
  self._onEnergyReady = {}
  self._onActive = {}
  self._onDeactivate = {}
  self._onActiveCancel = {}
  self._onBulletCut = {}
  self._onLevelChange = {}
  self._onStatusChange = {}
end)

function SingleSkill:IsLoading()
  return self.manager and self.manager._loading
end

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

function SingleSkill:SetEnergyRecovering()
  local data = self.data
  local cfg = self.config
  local lvl = self.levelConfig
  data.status = CONSTANTS.SKILL_STATUS.ENERGY_RECOVERING
  if cfg.energyRecoveryMode == CONSTANTS.ENERGY_RECOVERY_MODE.AUTO then
    if data.activationStacks >= lvl.maxActivationStacks then
      self:StopTimeEnergy()
      data.energyProgress = 0    else
      self:StartTimeEnergy()    end
  else
    self:StopTimeEnergy()
  end
  self:UpdateLevelTags()
  self.manager:SyncSkillStatus(self.id)
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

function SingleSkill:Lock()
  local data = self.data
  data.status = CONSTANTS.SKILL_STATUS.LOCKED
  self:StopTimeEnergy(); self:StopTimeBuff()
  data.energyProgress = 0; data.buffProgress = 0; data.bullet = 0; data.activationStacks = 0; data.force = false
  self:UpdateLevelTags()
  self.manager:SyncSkillStatus(self.id)
end

function SingleSkill:Unlock()
  if self.data.status ~= CONSTANTS.SKILL_STATUS.LOCKED and self.data.status ~= CONSTANTS.SKILL_STATUS.ENERGY_RECOVERING then return end
  self:SetEnergyRecovering()
end

function SingleSkill:SetLevel(level)
  local levelConfig = self.config.levels[level]
  if not levelConfig then return end
  self.data.level = level
  self.levelConfig = levelConfig
  self:UpdateLevelTags()
  self.manager:SyncSkillStatus(self.id)
end

function SingleSkill:AddEnergyProgress(value)
  local data = self.data
  if data.status ~= CONSTANTS.SKILL_STATUS.ENERGY_RECOVERING then return 0 end
  local lvl = self.levelConfig
  data.energyProgress = data.energyProgress + value
  local changed = false
  while data.energyProgress >= lvl.energy do
    data.energyProgress = data.energyProgress - lvl.energy    data.activationStacks = data.activationStacks + 1
    changed = true
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

function SingleSkill:Activate(force)
  local data = self.data
  if data.status == CONSTANTS.SKILL_STATUS.LOCKED then return false end
  if data.activationStacks <= 0 then return false end
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
  return true
end

function SingleSkill:Cancel()
  self.data.force = false
  self:SetEnergyRecovering()
end

function SingleSkill:CutBullet(value)
  if value == nil then value = 1 end
  local data = self.data
  data.bullet = data.bullet - value
  if data.bullet < 0 then data.bullet = 0 end
  self.manager:SyncSkillStatus(self.id)
  if data.bullet == 0 then
    self:SetEnergyRecovering()
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
