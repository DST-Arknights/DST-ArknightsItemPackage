local CONSTANTS = require "ark_constants"
local common = require "ark_common"
local utils = require "ark_utils"
local ArkSkill = Class(function(self, inst)
  self.inst = inst
  self.inst:AddTag("ark_skill")
end)

local function defaultSkill(skill)
  skill.energyRecoveryMode = skill.energyRecoveryMode or CONSTANTS.ENERGY_RECOVERY_MODE.AUTO
  skill.activationMode = skill.activationMode or CONSTANTS.ACTIVATION_MODE.MANUAL
  -- 能自动触发的技能关闭快捷键
  if skill.activationMode ~= CONSTANTS.ACTIVATION_MODE.MANUAL then
    skill.hotKey = nil
  end
  for _, levelConfig in ipairs(skill.levels) do
    levelConfig.energy = levelConfig.energy or 1
    -- levelConfig.buffTime = levelConfig.buffTime or 1
    levelConfig.buffTime = levelConfig.buffTime or 0.3
    levelConfig.bullet = levelConfig.bullet or 10
    levelConfig.maxActivationStacks = levelConfig.maxActivationStacks or 1
  end
  return skill
end

local function defaultSkillData(config)
  local level = 1
  return {
    data = {
      level = level,
      status = CONSTANTS.SKILL_STATUS.LOCKED,
      energyProgress = 0,
      buffProgress = 0,
      bullet = 0,
      activationStacks = 1,
      force = false
    },
    config = config,
    levelConfig = config.levels[level],
    timeEnergy = false,
    timeBuff = false
  }
end

function ArkSkill:SetupSkillConfig(prefab)
  local config = ARK_GLOBAL.GetArkSkillConfig(prefab)
  self.config = config
  -- 搞几个默认值进去
  for _, config in ipairs(config.skills) do
    defaultSkill(config)
  end
  self.skills = {}
  self.latestSkills = {}
  for i, config in ipairs(config.skills) do
    local level = 1
    self.skills[i] = defaultSkillData(config)
    self.latestSkills[i] = utils.cloneTable(self.skills[i].data)
    self:SetSkillLevel(i, 1)
  end
  for i, skill in ipairs(self.skills) do
    if skill.config.unlock then
      self:UnLock(i)
    end
  end
  self.inst:StartUpdatingComponent(self)
  -- 下次调度让客户端安装UI
  self.inst:DoTaskInTime(0, function()
    SendModRPCToClient(GetClientModRPC("arkSkill", "SetupArkSkillUi"), self.inst.userid, json.encode(config))
  end)
end

-- 便捷的几个方法
function ArkSkill:GetSkill(idx)
  return self.skills[idx]
end

function ArkSkill:GetSkillData(idx)
  return self:GetSkill(idx).data
end

function ArkSkill:GetConfig(idx)
  return self:GetSkill(idx).config
end

function ArkSkill:GetLevelConfig(idx)
  return self:GetSkill(idx).levelConfig
end

-- 时间更新
function ArkSkill:StartTimeEnergy(idx)
  self:GetSkill(idx).timeEnergy = true
end

function ArkSkill:StopTimeEnergy(idx)
  self:GetSkill(idx).timeEnergy = false
end

function ArkSkill:StartTimeBuff(idx)
  self:GetSkill(idx).timeBuff = true
end

function ArkSkill:StopTimeBuff(idx)
  self:GetSkill(idx).timeBuff = false
end

-- 状态变换

function ArkSkill:UnLock(idx)
  local status = self:GetSkillData(idx).status
  -- 如果已经解锁就返回
  if status ~= CONSTANTS.SKILL_STATUS.LOCKED and status ~= CONSTANTS.SKILL_STATUS.ENERGY_RECOVERING  then
    return
  end
  -- 直接去充能状态
  self:GoEnergyRecovering(idx)
end

function ArkSkill:GoEnergyRecovering(idx)
  local config = self:GetConfig(idx)
  local levelConfig = self:GetLevelConfig(idx)
  local data = self:GetSkillData(idx)
  data.status = CONSTANTS.SKILL_STATUS.ENERGY_RECOVERING
  if config.energyRecoveryMode == CONSTANTS.ENERGY_RECOVERY_MODE.AUTO then
    if data.activationStacks >= levelConfig.maxActivationStacks then
      self:StopTimeEnergy(idx)
      data.energyProgress = 0
      data.activationStacks = levelConfig.maxActivationStacks
    else
      self:StartTimeEnergy(idx)
    end
  end
  self:SyncSkillStatus(idx)
end

function ArkSkill:GoBuffing(idx)
  local data = self:GetSkillData(idx)
  data.status = CONSTANTS.SKILL_STATUS.BUFFING
  self:StartTimeBuff(idx)
  self:SyncSkillStatus(idx)
end

function ArkSkill:GoBulleting(idx)
  local data = self:GetSkillData(idx)
  data.status = CONSTANTS.SKILL_STATUS.BULLETING
  self:SyncSkillStatus(idx)
end

function ArkSkill:SyncSkillStatus(idx, notice)
  local data = self:GetSkillData(idx)
  SendModRPCToClient(GetClientModRPC("arkSkill", "SyncSkillStatus"), self.inst.userid, idx, data.status, data.level,
    data.energyProgress, data.buffProgress, data.bullet, data.activationStacks)
  if notice == nil then
    notice = true
  end
  if self.onSkillStatusChange and notice then
    local latestData = self.latestSkills[idx]
    self.latestSkills[idx] = utils.cloneTable(data)
    self.onSkillStatusChange(idx, data, latestData)
  end
end

function ArkSkill:RequestSyncSkillStatus(idx)
  self:SyncSkillStatus(idx, false)
end

function ArkSkill:OnUpdateBuff(idx, dt)
  if not self:GetSkill(idx).timeBuff then
    return nil
  end
  return self:AddBuffProgress(idx, dt)
end

function ArkSkill:OnUpdateTimeEnergy(idx, dt)
  if not self:GetSkill(idx).timeEnergy then
    return
  end
  self:AddEnergyProgress(idx, dt)
end

function ArkSkill:OnUpdate(dt)
  self.OnUpdate = function(self, dt)
    for i = 1, #self.skills do
      -- buff流动期间, 不会自动时间充能
      local leftBuffTime = self:OnUpdateBuff(i, dt)
      if leftBuffTime == nil then
        self:OnUpdateTimeEnergy(i, dt)
      elseif leftBuffTime > 0 then
        self:OnUpdateTimeEnergy(i, dt + leftBuffTime)
      end
    end
  end
  self.OnUpdate(self, dt)
end

function ArkSkill:OnSave()
  local data = {
    skillsData = {}
  }
  for i, skill in ipairs(self.skills) do
    table.insert(data.skillsData, skill.data)
  end
  return data
end

function ArkSkill:OnLoad(data)
  if not data or not data.skillsData then
    return
  end
  for i, skillData in ipairs(data.skillsData) do
    if not self.skills[i] then
      break
    end
    self.skills[i].data = utils.mergeTable(self.skills[i].data, skillData)
    local maxLevel = #self.skills[i].config.levels
    self:SetSkillLevel(i, math.min(skillData.level, maxLevel))
    -- 根据status 切换到对应状态
    if skillData.status == CONSTANTS.SKILL_STATUS.ENERGY_RECOVERING then
      self:GoEnergyRecovering(i)
    elseif skillData.status == CONSTANTS.SKILL_STATUS.BUFFING then
      self:GoBuffing(i)
    elseif skillData.status == CONSTANTS.SKILL_STATUS.BULLETING then
      self:GoBulleting(i)
    end
  end
end
-- 推荐暴露的方法

function ArkSkill:LevelUpSkill(idx)
  local skill = self:GetSkill(idx)
  local level = skill.data.level + 1
  self:SetSkillLevel(idx, level)
end

function ArkSkill:SetSkillLevel(idx, level)
  local skill = self:GetSkill(idx)
  local levelConfig = skill.config.levels[level]
  if not levelConfig then
    return
  end
  skill.data.level = level
  skill.levelConfig = skill.config.levels[level]
  local skillData = self:GetSkillData(idx)
  for i = 1, CONSTANTS.MAX_SKILL_LEVEL do
    local skillTag = common.genArkSkillLevelTag(idx, i)
    if not skillData.locked and i == level then
      self.inst:AddTag(skillTag)
    else
      self.inst:RemoveTag(skillTag)
    end
  end
  self:SyncSkillStatus(idx)
end

function ArkSkill:AddEnergyProgress(idx, value)
  local data = self:GetSkillData(idx)
  local levelConfig = self:GetLevelConfig(idx)
  data.energyProgress = data.energyProgress + value
  local leftEnergy = data.energyProgress - levelConfig.energy
  if leftEnergy >= 0 then
    data.activationStacks = data.activationStacks + 1
    if data.activationStacks < levelConfig.maxActivationStacks then
      data.energyProgress = leftEnergy
    else -- 超出最大充能量
      self:StopTimeEnergy(idx)
      data.energyProgress = 0
    end
    self:SyncSkillStatus(idx)
  end
  return leftEnergy
end


function ArkSkill:AddBuffProgress(idx, value)
  local data = self:GetSkillData(idx)
  local levelConfig = self:GetLevelConfig(idx)
  data.buffProgress = data.buffProgress + value
  local leftBuff = data.buffProgress - levelConfig.buffTime
  if leftBuff >= 0 then
    data.buffProgress = leftBuff
    self:GoEnergyRecovering(idx)
    self:StopTimeBuff(idx)
  end
  return leftBuff
end

function ArkSkill:ActivateSkill(idx, force)
  local data = self:GetSkillData(idx)
  if data.status == CONSTANTS.SKILL_STATUS.LOCKED then
    return false
  end
  if data.activationStacks <= 0 then
    return false
  end
  data.activationStacks = data.activationStacks - 1
  local config = self:GetConfig(idx)
  if config.bullet then
    local levelConfig = self:GetLevelConfig(idx)
    data.bullet = levelConfig.bullet
  else
    data.buffProgress = 0
  end
  data.force = force
  if config.bullet then
    self:GoBulleting(idx)
  else
    self:GoBuffing(idx)
  end
  return true
end



function ArkSkill:CancelSkill(idx)
  local data = self:GetSkillData(idx)
  data.force = false
  self:GoEnergyRecovering(idx)
end

function ArkSkill:ManualCancelSkill(idx)
  self:CancelSkill(idx)
end

function ArkSkill:ManualActivateSkill(idx)
  local config = self:GetConfig(idx)
  if config.activationMode ~= CONSTANTS.ACTIVATION_MODE.MANUAL then
    return
  end
  self:ActivateSkill(idx)
end

function ArkSkill:CutBullet(idx, value)
  if value == nil then
    value = 1
  end
  local data = self:GetSkillData(idx)
  data.bullet = data.bullet - value
  if data.bullet < 0 then
    data.bullet = 0
  end
  self:SyncSkillStatus(idx)
  if data.bullet == 0 then
    self:GoEnergyRecovering(idx)
  end
end

return ArkSkill
