local CONSTANTS = require "ark_constants"
local common = require "ark_common"
local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"

local ArkSkillDesc = require "widgets/ark_skill_desc"

local function ShallowCopyMap(source)
  local copy = {}
  for key, value in pairs(source or {}) do
    copy[key] = value
  end
  return copy
end

local function MergeSkillConfig(baseConfig, configPatch)
  local merged = ShallowCopyMap(baseConfig)
  for key, value in pairs(configPatch or {}) do
    merged[key] = value
  end
  return merged
end

-- 闪烁效果配置
local BLINK_DURATION = 0.3  -- 单次闪烁持续时间（秒）

local ArkSkill = Class(Widget, function(self, owner, config)
  Widget._ctor(self, "ArkSkill")
  self.owner = owner
  self.baseConfig = config
  self.configPatch = {}
  self.config = MergeSkillConfig(self.baseConfig, self.configPatch)

  self.id = config.id -- 服务端通信改为按 id
  self.iconSize = {64, 64}
  self.scale = self.iconSize[1] / 64
  self.width = self.iconSize[1]
  self.height = self.iconSize[2]

  local skillIcon = self:AddChild(Widget("skillIcon"))
  skillIcon:SetPosition(0, 0, 0)
  self.skillIcon = skillIcon

  local skill = skillIcon:AddChild(Image(config.atlas, config.image))
  self.skill = skill
  skill:SetSize(self.iconSize)

  local manualActivationShadow = skillIcon:AddChild(Image("images/ui.xml", "black.tex"))
  self.manualActivationShadow = manualActivationShadow
  -- 设置底部对齐
  manualActivationShadow:SetPosition(0, -self.iconSize[2] / 2, 0)
  manualActivationShadow:SetVRegPoint(ANCHOR_BOTTOM)
  manualActivationShadow:SetSize(self.iconSize)
  -- 设置黑色半透明
  manualActivationShadow:SetTint(1, 1, 1, 0.6)

  local chargeShadow = skillIcon:AddChild(Image("images/ui.xml", "white.tex"))
  self.chargeShadow = chargeShadow
  chargeShadow:SetPosition(0, -self.iconSize[2] / 2, 0)
  chargeShadow:SetVRegPoint(ANCHOR_BOTTOM)
  chargeShadow:SetSize(self.iconSize)
  -- 设置绿色半透明
  chargeShadow:SetTint(0, 1, 0, 0.4)

  local buffShadow = skillIcon:AddChild(Image("images/ui.xml", "white.tex"))
  self.buffShadow = buffShadow
  buffShadow:SetPosition(0, -self.iconSize[2] / 2, 0)
  buffShadow:SetVRegPoint(ANCHOR_BOTTOM)
  buffShadow:SetSize(self.iconSize)
  -- 设置橘黄色半透明
  buffShadow:SetTint(1, 0.5, 0, 0.3)

  local stop = skillIcon:AddChild(Image("images/ark_skill.xml", "stop.tex"))
  self.stop = stop
  stop:SetSize(self.iconSize)

  local lock = skillIcon:AddChild(Image("images/ark_skill.xml", "lock.tex"))
  self.lock = lock
  lock:SetSize(self.iconSize)

  local autoActivation = skillIcon:AddChild(Image("images/ark_skill.xml", "auto_activation.tex"))
  self.autoActivation = autoActivation
  self.autoActivation:SetScale(self.scale / 2)
  autoActivation:Hide()

  -- 闪烁遮罩 - 用于技能充能完成提醒
  local blinkMask = skillIcon:AddChild(Image("images/ui.xml", "white.tex"))
  self.blinkMask = blinkMask
  blinkMask:SetSize(self.iconSize)
  blinkMask:SetTint(1, 1, 1, 0)  -- 初始完全透明
  blinkMask:Hide()  -- 默认隐藏

  local frame = skillIcon:AddChild(Image("images/ark_skill.xml", "frame.tex"))
  frame:SetSize(self.iconSize)

  local status = self:AddChild(Widget("ark_skill_status"))
  status:SetPosition(0, -self.iconSize[2] / 2 - 14, 0)
  local statusImg = status:AddChild(Image("images/ark_skill.xml", "sprite_skill_ready.tex"))
  local originalStatusWidth, originalStatusHeight = statusImg:GetSize()
  self.originalStatusWidth = originalStatusWidth
  self.originalStatusHeight = originalStatusHeight
  self.statusImg = statusImg
  self:RecurrentStatusImageSize()
  self.height = self.height + self.statusHeight / 2
  local statusText = statusImg:AddChild(Text(SEGEOUI_ALPHANUM_ITALICFONT, 14 * self.scale))
  self.statusText = statusText
  statusText:SetPosition(5 * self.scale, 6 * self.scale, 0)

  -- 加一个文本框, 用来展示激活充能
  local activationChargeWidget = self:AddChild(Widget("activationChargeWidget"))
  self.activationStacksWidget = activationChargeWidget
  -- 放左上角
  activationChargeWidget:SetPosition(-self.iconSize[1] / 2, self.iconSize[2] / 2, 0)
  -- 加一个圆黑透明背景
  local activationChargeBg = activationChargeWidget:AddChild(Image("images/ark_item_ui.xml", "circle.tex"))
  activationChargeBg:SetSize(20, 20)
  activationChargeBg:SetTint(0, 0, 0, 0.8)
  local activationChargeText = activationChargeWidget:AddChild(Text(SEGEOUI_ALPHANUM_ITALICFONT, 16))
  self.activationStacksText = activationChargeText

  self.levelConfig = self.config.levels[1]
  self.level = 1
  self.status = CONSTANTS.SKILL_STATUS.LOCKED
  self.energyProgress = 0
  self.buffProgress = 0
  self.bulletCount = 0
  self.activationStacks = 0
  self:SetEnergyProgress(0)
  self:SetBuffProgress(0)

  -- 闪烁效果相关变量
  self.blinkTimer = 0
  self.isBlinking = false

  self:SetHoverWidget(function()
    return self:CreateSkillDescWidget()
  end, {
    attach_to_parent = self,
    offset_x = 0,
    offset_y = 0,
    show_delay = 0.08,
    hide_delay = 0.12,
  })

  self.owner:StartUpdatingComponent(self)
  self.initComplete = false

end)

function ArkSkill:RecurrentStatusImageSize()
  if not self.statusWidth or not self.statusHeight then
    self.statusWidth = self.iconSize[1] * 1.18
    self.statusHeight = self.originalStatusHeight * self.iconSize[1] / self.originalStatusWidth
  end
  self.statusImg:SetSize(self.statusWidth, self.statusHeight)
end

function ArkSkill:GetSize()
  return self.width, self.height
end

local function CaseShadowScale(scale)
  local paddingScale = 0.08
  return paddingScale + (1 - 2 * paddingScale) * scale
end

local function UpdateTimeEnergy(self, dt)
  if self.timeEnergy == nil then
    return nil
  end
  self.timeEnergy = self.timeEnergy + dt
  local leftTime = self:SetEnergyProgress(self.timeEnergy)
  if leftTime <= 0 then
    self:StopTimeEnergy()
  end
  return leftTime
end

local function UpdateTimeBuff(self, dt)
  if self.timeBuff == nil then
    return nil
  end
  self.timeBuff = self.timeBuff + dt
  local leftTime = self:SetBuffProgress(self.timeBuff)
  if leftTime <= 0 then
    self:StopTimeBuff()
  end
  return leftTime
end

local function isAutoActivation(activationMode)
  return activationMode == CONSTANTS.ACTIVATION_MODE.AUTO
end

function ArkSkill:GetSkillDescConfig()
  return {
    locked = self.status == CONSTANTS.SKILL_STATUS.LOCKED,
    lockedDesc = self.config.lockedDesc,
    name = self.config.name,
    energyRecoveryMode = self.config.energyRecoveryMode,
    activationMode = self.config.activationMode,
    activationEnergy = self.levelConfig.activationEnergy,
    buffDuration = self.levelConfig.buffDuration,
    hotkey = self.config.hotkey,
    level = self.level or 1,
    desc = self.levelConfig.desc,
  }
end

function ArkSkill:SyncConfigPatch(configPatch)
  self.configPatch = ShallowCopyMap(configPatch)
  self.config = MergeSkillConfig(self.baseConfig, self.configPatch)
  self.levelConfig = self.config.levels[self.level or 1]
  if self.hoverwidget and self.hoverwidget.RefreshConfig then
    self.hoverwidget:RefreshConfig(self:GetSkillDescConfig())
  end
  if self.initComplete then
    self:RefreshVisualState()
  end
end

function ArkSkill:CreateSkillDescWidget()
  local skillDesc = ArkSkillDesc(self.owner, self:GetSkillDescConfig(), self.id)
  local size = skillDesc:GetSize()
  skillDesc:SetPosition(-self.iconSize[1] / 2 + size.x / 2, self.iconSize[2] / 2 + size.y + 10, 0)
  return skillDesc
end

function ArkSkill:SetEnergyProgress(current)
  local total = self.levelConfig.activationEnergy
  self.statusText:SetString(string.format("%d/%d", math.floor(math.min(current, total - 1)), total))
  self.chargeShadow:SetScale(1, CaseShadowScale(current / total))
  return total - current
end

function ArkSkill:SetBulletCount(bulletCount)
  local total = self.levelConfig.bulletCount
  self.statusText:SetString(string.format("%d/%d", bulletCount, total))
  self.buffShadow:SetScale(1, CaseShadowScale(bulletCount / total))
end

function ArkSkill:StartTimeEnergy(from)
  self.timeEnergy = from
end

function ArkSkill:StopTimeEnergy()
  self.timeEnergy = nil
end

function ArkSkill:SetBuffProgress(current)
  local total = self.levelConfig.buffDuration
  self.buffShadow:SetScale(1, 1 - CaseShadowScale(current / total))
  return total - current
end

function ArkSkill:StartTimeBuff(from)
  self.timeBuff = from
end

function ArkSkill:StopTimeBuff()
  self.timeBuff = nil
end

-- 开始单次闪烁效果
function ArkSkill:StartBlink()
  self.isBlinking = true
  self.blinkTimer = 0
  self.blinkMask:Show()
end

-- 停止闪烁效果
function ArkSkill:StopBlink()
  self.isBlinking = false
  self.blinkTimer = 0
  self.blinkMask:Hide()
end

-- 更新闪烁效果 - 单次从透明到白色再到透明
function ArkSkill:UpdateBlink(dt)
  if not self.isBlinking then
    return
  end

  self.blinkTimer = self.blinkTimer + dt

  -- 闪烁结束
  if self.blinkTimer >= BLINK_DURATION then
    self:StopBlink()
    return
  end

  -- 计算闪烁透明度 - 使用正弦波实现从透明到白色再到透明的单次闪烁
  local progress = self.blinkTimer / BLINK_DURATION  -- 0到1的进度
  local alpha = math.sin(progress * math.pi) * 0.6  -- 透明度在0-0.6之间变化
  self.blinkMask:SetTint(1, 1, 1, alpha)
end

function ArkSkill:UpdateActivationStacks(currentActivationStacks)
  self.activationStacks = currentActivationStacks
  if self.levelConfig.maxActivationStacks > 1 and currentActivationStacks > 0 then
    self.activationStacksWidget:Show()
    self.activationStacksText:SetString(tostring(currentActivationStacks))
  else
    self.activationStacksWidget:Hide()
  end
end

function ArkSkill:UpdateModeIndicators(status, autoActivationMode)
  if autoActivationMode then
    if status == CONSTANTS.SKILL_STATUS.LOCKED then
      self.autoActivation:Hide()
    else
      self.autoActivation:Show()
    end
  else
    self.autoActivation:Hide()
  end

  if status == CONSTANTS.SKILL_STATUS.LOCKED then
    self.lock:Show()
  else
    self.lock:Hide()
  end
end

function ArkSkill:UpdateChargeShadow(status)
  if status == CONSTANTS.SKILL_STATUS.ENERGY_RECOVERING then
    self.chargeShadow:Show()
  else
    self.chargeShadow:Hide()
  end
end

function ArkSkill:UpdateManualActivationShadow(status, activationMode, autoActivationMode, readyStacks)
  -- 自动触发类型始终保留灰色蒙层，避免与旋转环视觉冲突
  local hideManualShadow = activationMode == CONSTANTS.ACTIVATION_MODE.PASSIVE
    or (not autoActivationMode
      and self.activationStacks >= readyStacks
      and status ~= CONSTANTS.SKILL_STATUS.BUFFING
      and status ~= CONSTANTS.SKILL_STATUS.LOCKED)

  if hideManualShadow then
    self.manualActivationShadow:Hide()
  else
    self.manualActivationShadow:Show()
  end
end

function ArkSkill:UpdateBuffShadow(status, buffProgress)
  if status == CONSTANTS.SKILL_STATUS.BUFFING then
    self.statusImg:SetTexture("images/ark_skill.xml", "sprite_skill_notready.tex")
    self.statusText:SetColour(1, 1, 1, 1)
    self:StartTimeBuff(buffProgress)
    self.buffShadow:Show()
  else
    self:StopTimeBuff()
    self.buffShadow:Hide()
  end
end

function ArkSkill:UpdateStateShadows(status, activationMode, autoActivationMode, readyStacks, buffProgress)
  self:UpdateChargeShadow(status)
  self:UpdateManualActivationShadow(status, activationMode, autoActivationMode, readyStacks)
  self:UpdateBuffShadow(status, buffProgress)
end

function ArkSkill:UpdateEnergyTimer(status, energyProgress, currentActivationStacks)
  self:SetEnergyProgress(energyProgress)

  local shouldTickEnergy = self.config.energyRecoveryMode == CONSTANTS.ENERGY_RECOVERY_MODE.AUTO
    and status == CONSTANTS.SKILL_STATUS.ENERGY_RECOVERING
    and currentActivationStacks < self.levelConfig.maxActivationStacks

  if shouldTickEnergy then
    self:StartTimeEnergy(energyProgress)
  else
    self:StopTimeEnergy()
  end
end

function ArkSkill:UpdateStatusBar(status, autoActivationMode, bulletCount)
  if status == CONSTANTS.SKILL_STATUS.BULLETING then
    self.statusImg:SetTexture("images/ark_skill.xml", "sprite_skill_bullet.tex")
    self.statusText:SetColour(1, 1, 1, 1)
    self:SetBulletCount(bulletCount)
    self.stop:Show()
    return
  end
  self.stop:Hide()

  if status == CONSTANTS.SKILL_STATUS.LOCKED then
    self.statusImg:SetTexture("images/ark_skill.xml", "sprite_skill_notready.tex")
    self.statusText:SetColour(1, 1, 1, 1)
    self.statusText:SetString("LOCK")
    return
  end

  if status ~= CONSTANTS.SKILL_STATUS.ENERGY_RECOVERING then
    return
  end

  local fullStacks = self.activationStacks >= self.levelConfig.maxActivationStacks
  local readyForCurrentMode = autoActivationMode and fullStacks or self.activationStacks >= 1

  if readyForCurrentMode then
    self.statusImg:SetTexture("images/ark_skill.xml", "sprite_skill_ready.tex")
    self.statusText:SetColour(0, 0, 0, 1)
  else
    self.statusImg:SetTexture("images/ark_skill.xml", "sprite_skill_notready.tex")
    self.statusText:SetColour(1, 1, 1, 1)
  end

  if fullStacks then
    self.statusText:SetString("READY")
  end
end

function ArkSkill:RefreshVisualState()
  local status = self.status
  local activationMode = self.config.activationMode
  local autoActivationMode = isAutoActivation(activationMode)
  local currentActivationStacks = self.activationStacks or 0
  local readyStacks = autoActivationMode and self.levelConfig.maxActivationStacks or 1

  self:UpdateActivationStacks(currentActivationStacks)
  self:UpdateModeIndicators(status, autoActivationMode)
  self:UpdateStateShadows(status, activationMode, autoActivationMode, readyStacks, self.buffProgress or 0)
  self:UpdateEnergyTimer(status, self.energyProgress or 0, currentActivationStacks)
  self:UpdateStatusBar(status, autoActivationMode, self.bulletCount or 0)
  self:RecurrentStatusImageSize()
end

function ArkSkill:SyncSkillStatus(status, level, energyProgress, buffProgress, bulletCount, activationStacks)
  self.status = status
  local wasInitComplete = self.initComplete
  self.initComplete = true
  self.level = level
  self.energyProgress = energyProgress
  self.buffProgress = buffProgress
  self.bulletCount = bulletCount
  self.levelConfig = self.config.levels[level]

  local previousActivationStacks = self.activationStacks or 0
  local currentActivationStacks = activationStacks or 0

  if wasInitComplete and currentActivationStacks > previousActivationStacks then
    self:StartBlink()
  end

  self.activationStacks = currentActivationStacks
  self:RefreshVisualState()
end

-- OnUpdate 需要第一帧检测, 第一帧要作点事情
function ArkSkill:OnUpdate(dt)
  if not self.inst:IsValid() then
    return
  end
  -- 自动激活模式图标旋转
  if self.autoActivation:IsVisible() then
    self.autoActivation:SetRotation(self.autoActivation:GetRotation() - 360 * dt / 10)
  end
  -- 更新闪烁效果
  self:UpdateBlink(dt)

  -- buff期间技能停止充能
  local leftBuffTime = UpdateTimeBuff(self, dt)
  if leftBuffTime == nil then
    UpdateTimeEnergy(self, dt)
  elseif leftBuffTime > 0 then
    UpdateTimeEnergy(self, dt + leftBuffTime)
  end
end

function ArkSkill:OnGainFocus()
  ArkSkill._base.OnGainFocus(self)
end

function ArkSkill:OnLoseFocus()
  ArkSkill._base.OnLoseFocus(self)
end

function ArkSkill:Kill()
  self:ClearHoverWidget()
  ArkSkill._base.Kill(self)
end

function ArkSkill:OnControl(control, down)
  if ArkSkill._base.OnControl(self, control, down) then
    return true
  end
  if control == CONTROL_ACCEPT then
    if down and self.config.activationMode == CONSTANTS.ACTIVATION_MODE.MANUAL and self.owner.replica.ark_skill then
      self.owner.replica.ark_skill:TryActivateSkill(self.id)
      return true
    end
  end
end

return ArkSkill
