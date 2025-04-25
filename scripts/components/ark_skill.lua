local CONSTANTS = require "ark_constants"
local common = require "ark_common"

local ArkSkill = Class(function(self, inst)
  self.inst = inst

end)

function ArkSkill:SetSkillConfigByKey(key)
  local config = TUNING.ARK_SKILL_CONFIG[key]
  if not config then
    return
  end
  self:SetupSkillConfig(config)
end

function ArkSkill:SetupSkillConfig(config)
  self.config = config
  -- 搞几个默认值进去
  for _, config in ipairs(config.skills) do
    config.chargeType = config.chargeType or CONSTANTS.CHARGE_TYPE.AUTO
    config.emitType = config.emitType or CONSTANTS.EMIT_TYPE.HAND
    -- 能自动触发的技能关闭快捷键
    if config.emitType ~= CONSTANTS.EMIT_TYPE.HAND then
      config.hotKey = nil
    end
    for _, levelConfig in ipairs(config.levels) do
      levelConfig.charge = levelConfig.charge or 1
      -- levelConfig.buffTime = levelConfig.buffTime or 1
      levelConfig.shadowBuffTime = levelConfig.buffTime or 0.3
      levelConfig.bullet = levelConfig.bullet or 1
      levelConfig.maxEmitCharge = levelConfig.maxEmitCharge or 1
    end
  end
  self.skills = {}
  for i, config in ipairs(config.skills) do
    local level = 1
    self.skills[i] = {
      data = {
        level = level,
        status = CONSTANTS.SKILL_STATUS.LOCKED,
        chargeProgress = 0,
        buffProgress = 0,
        bullet = 0,
        emitCharge = 0
      },
      config = config,
      levelConfig = config.levels[level],
      timeCharge = false,
      timeBuff = false
    }
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
function ArkSkill:StartTimeCharge(idx)
  self:GetSkill(idx).timeCharge = true
end

function ArkSkill:StopTimeCharge(idx)
  self:GetSkill(idx).timeCharge = false
end

function ArkSkill:StartTimeBuff(idx)
  self:GetSkill(idx).timeBuff = true
end

function ArkSkill:StopTimeBuff(idx)
  self:GetSkill(idx).timeBuff = false
end

-- 状态变换

function ArkSkill:UnLock(idx)
  -- 直接去充能状态
  self:GoCharging(idx)
end

function ArkSkill:GoCharging(idx)
  local config = self:GetConfig(idx)
  local levelConfig = self:GetLevelConfig(idx)
  local data = self:GetSkillData(idx)
  data.status = CONSTANTS.SKILL_STATUS.CHARGING
  if config.chargeType == CONSTANTS.CHARGE_TYPE.AUTO then
    if data.emitCharge >= levelConfig.maxEmitCharge then
      self:StopTimeCharge(idx)
      data.chargeProgress = 0
      data.emitCharge = levelConfig.maxEmitCharge
    else
      self:StartTimeCharge(idx)
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

function ArkSkill:SyncSkillStatus(idx)
  local data = self:GetSkillData(idx)
  SendModRPCToClient(GetClientModRPC("arkSkill", "SyncSkillStatus"), self.inst.userid, idx, data.status, data.level,
    data.chargeProgress, data.buffProgress, data.bullet, data.emitCharge)
end

function ArkSkill:RequestSyncSkillStatus(idx)
  self:SyncSkillStatus(idx)
end

function ArkSkill:OnUpdateBuff(idx, dt)
  if not self:GetSkill(idx).timeBuff then
    return nil
  end
  return self:AddBuffProgress(idx, dt)
end

function ArkSkill:OnUpdateTimeCharge(idx, dt)
  if not self:GetSkill(idx).timeCharge then
    return
  end
  self:AddChargeProgress(idx, dt)
end

function ArkSkill:OnUpdate(dt)
  self.OnUpdate = function(self, dt)
    for i = 1, #self.skills do
      -- buff流动期间, 不会自动时间充能
      local leftBuffTime = self:OnUpdateBuff(i, dt)
      if leftBuffTime == nil then
        self:OnUpdateTimeCharge(i, dt)
      elseif leftBuffTime > 0 then
        self:OnUpdateTimeCharge(i, dt + leftBuffTime)
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
    self.skills[i].data = skillData
    self:SetSkillLevel(i, skillData.level)
    -- 根据status 切换到对应状态
    if skillData.status == CONSTANTS.SKILL_STATUS.CHARGING then
      self:GoCharging(i)
    elseif skillData.status == CONSTANTS.SKILL_STATUS.BUFFING then
      self:GoBuffing(i)
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

function ArkSkill:AddChargeProgress(idx, value)
  local data = self:GetSkillData(idx)
  local levelConfig = self:GetLevelConfig(idx)
  data.chargeProgress = data.chargeProgress + value
  local leftCharge = data.chargeProgress - levelConfig.charge
  if leftCharge >= 0 then
    data.emitCharge = data.emitCharge + 1
    if data.emitCharge < levelConfig.maxEmitCharge then
      data.chargeProgress = leftCharge
    else -- 超出最大充能量
      self:StopTimeCharge(idx)
      data.chargeProgress = 0
    end
    self:SyncSkillStatus(idx)
  end
  return leftCharge
end

function ArkSkill:AddBuffProgress(idx, value)
  local data = self:GetSkillData(idx)
  local levelConfig = self:GetLevelConfig(idx)
  data.buffProgress = data.buffProgress + value
  local leftBuff = data.buffProgress - levelConfig.shadowBuffTime
  if leftBuff >= 0 then
    data.buffProgress = leftBuff
    self:GoCharging(idx)
    self:StopTimeBuff(idx)
  end
  return leftBuff
end

function ArkSkill:EmitSkill(idx)
  local data = self:GetSkillData(idx)
  if data.emitCharge <= 0 then
    return
  end
  -- TODO: 真实执行技能接口
  data.emitCharge = data.emitCharge - 1
  data.buffProgress = 0
  self.inst:PushEvent("arkSkillEmit", idx)
  self:GoBuffing(idx)
end

function ArkSkill:HandEmitSkill(idx)
  local config = self:GetConfig(idx)
  if config.emitType ~= CONSTANTS.EMIT_TYPE.HAND then
    return
  end
  self:EmitSkill(idx)
end

return ArkSkill
