local CONSTANTS = require "ark_constants"
local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"

local ark_skill_desc = require "widgets/ark_skill_desc"

local ArkSkill = Class(Widget, function(self, owner, config, idx)
  Widget._ctor(self, "ArkSkill")
  self.owner = owner
  self.idx = idx
  self.size = {128, 128}

  local skill = self:AddChild(Image(config.atlas, config.image))
  self.skill = skill
  skill:SetSize(self.size)

  local handEmitShadow = self:AddChild(Image("images/ui.xml", "black.tex"))
  self.handEmitShadow = handEmitShadow
  -- 设置底部对齐
  handEmitShadow:SetPosition(0, -self.size[2] / 2, 0)
  handEmitShadow:SetVRegPoint(ANCHOR_BOTTOM)
  handEmitShadow:SetSize(self.size)
  -- 设置黑色半透明
  handEmitShadow:SetTint(1, 1, 1, 0.6)

  local chargeShadow = self:AddChild(Image("images/ui.xml", "white.tex"))
  self.chargeShadow = chargeShadow
  chargeShadow:SetPosition(0, -self.size[2] / 2, 0)
  chargeShadow:SetVRegPoint(ANCHOR_BOTTOM)
  chargeShadow:SetSize(self.size)
  -- 设置绿色半透明
  chargeShadow:SetTint(0, 1, 0, 0.4)

  local buffShadow = self:AddChild(Image("images/ui.xml", "white.tex"))
  self.buffShadow = buffShadow
  buffShadow:SetPosition(0, -self.size[2] / 2, 0)
  buffShadow:SetVRegPoint(ANCHOR_BOTTOM)
  buffShadow:SetSize(self.size)
  -- 设置橘黄色半透明
  buffShadow:SetTint(1, 0.5, 0, 0.3)

  local stop = self:AddChild(Image("images/ark_skill.xml", "stop.tex"))
  self.stop = stop
  stop:SetSize(self.size)

  local lock = self:AddChild(Image("images/ark_skill.xml", "lock.tex"))
  self.lock = lock
  lock:SetSize(self.size)

  local autoEmit = self:AddChild(Image("images/ark_skill.xml", "auto_emit.tex"))
  self.autoEmit = autoEmit
  autoEmit:Hide()

  local frame = self:AddChild(Image("images/ark_skill.xml", "frame.tex"))
  frame:SetSize(self.size)
  local status = self:AddChild(Widget("ark_skill_status"))
  status:SetPosition(0, -self.size[2] / 2 - 20, 0)
  local statusImg = status:AddChild(Image("images/ark_skill.xml", "sprite_skill_ready.tex"))
  self.statusImg = statusImg
  statusImg:SetPosition(0, -12, 0)
  local statusText = status:AddChild(Text(FALLBACK_FONT_OUTLINE, 32))
  self.statusText = statusText
  statusText:SetPosition(10, 0, 0)
  statusText:SetFont(CODEFONT)

  -- 加一个文本框, 用来展示emitCharge
  local emitChargeWidget = self:AddChild(Widget("emitChargeWidget"))
  self.emitChargeWidget = emitChargeWidget
  -- 放左上角
  emitChargeWidget:SetPosition(-self.size[1] / 2, self.size[2] / 2, 0)
  -- 加一个圆黑透明背景
  local emitChargeBg = emitChargeWidget:AddChild(Image("images/ui.xml", "black.tex"))
  emitChargeBg:SetSize(40, 40)
  emitChargeBg:SetTint(0, 0, 0, 0.8)
  local emitChargeText = emitChargeWidget:AddChild(Text(FALLBACK_FONT_OUTLINE, 32))
  self.emitChargeText = emitChargeText

  self.config = config
  self.levelConfig = config.levels[1]
  self.emitCharge = 0
  self:SetChargeProgress(0)
  self:SetBuffProgress(0)
  self.owner:StartUpdatingComponent(self)
  self.initComplete = false
end)

local function CaseShadowScale(scale)
  local paddingScale = 0.08
  return paddingScale + (1 - 2 * paddingScale) * scale
end

local function UpdateTimeCharge(self, dt)
  if self.timeCharge == nil then
    return nil
  end
  self.timeCharge = self.timeCharge + dt
  local leftTime = self:SetChargeProgress(self.timeCharge)
  if leftTime <= 0 then
    self:StopTimeCharge()
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

local function isAutoEmit(emitType)
  return emitType == CONSTANTS.EMIT_TYPE.AUTO or emitType == CONSTANTS.EMIT_TYPE.ATTACK
    or emitType == CONSTANTS.EMIT_TYPE.UNDER_ATTACK
end

function ArkSkill:SetChargeProgress(current)
  local total = self.levelConfig.charge
  self.statusText:SetString(string.format("%d/%d", math.floor(math.min(current, total - 1)), total))
  self.chargeShadow:SetScale(1, CaseShadowScale(current / total))
  return total - current
end

function ArkSkill:SetBullet(bullet)
  local total = self.levelConfig.bullet
  self.statusText:SetString(string.format("%d/%d", bullet, total))
  self.buffShadow:SetScale(1, CaseShadowScale(bullet / total))
end

function ArkSkill:StartTimeCharge(from)
  self.timeCharge = from
end

function ArkSkill:StopTimeCharge()
  self.timeCharge = nil
end

function ArkSkill:SetBuffProgress(current)
  local total = self.levelConfig.shadowBuffTime
  self.buffShadow:SetScale(1, 1 - CaseShadowScale(current / total))
  return total - current
end

function ArkSkill:StartTimeBuff(from)
  self.timeBuff = from
end

function ArkSkill:StopTimeBuff()
  self.timeBuff = nil
end

function ArkSkill:SyncSkillStatus(status, level, chargeProgress, buffProgress, bullet, emitCharge)
  self.status = status
  self.initComplete = true
  self.level = level
  self.levelConfig = self.config.levels[level]
  self.emitCharge = emitCharge
  if emitCharge > 1 then
    self.emitChargeWidget:Show()
    self.emitChargeText:SetString(tostring(emitCharge))
  else
    self.emitChargeWidget:Hide()
  end

  -- 自动触发图案
  if isAutoEmit(self.config.emitType) then
    if status == CONSTANTS.SKILL_STATUS.LOCKED then
      self.autoEmit:Hide()
    else
      self.autoEmit:Show()
    end
  end
  -- 充能遮罩只在充能状态且充能没满时展示, 其余隐藏
  if status == CONSTANTS.SKILL_STATUS.CHARGING then
    self.chargeShadow:Show()
  else
    self.chargeShadow:Hide()
  end
  -- 状态栏, 弹药模式固定展示弹药
  if status == CONSTANTS.SKILL_STATUS.BULLETING then
    self.statusImg:SetTexture("images/ark_skill.xml", "sprite_skill_bullet.tex")
    self.statusText:SetColour(1, 1, 1, 1)
    self:SetBullet(bullet, self.levelConfig.bullet)
    self.stop:Show()
  else
    self.stop:Hide()
  end
  -- buff遮罩只在buff状态且buff没满时展示, 其余隐藏
  if status == CONSTANTS.SKILL_STATUS.BUFFING then
    self.statusImg:SetTexture("images/ark_skill.xml", "sprite_skill_notready.tex")
    self.statusText:SetColour(1, 1, 1, 1)
    self:StartTimeBuff(buffProgress)
    self.buffShadow:Show()
  else
    self:StopTimeBuff()
    self.buffShadow:Hide()
  end
  if status == CONSTANTS.SKILL_STATUS.LOCKED then
    self.lock:Show()
  else
    self.lock:Hide()
  end

  -- 手动触发的遮罩
  if (self.config.emitType == CONSTANTS.EMIT_TYPE.PASSIVE) or (self.emitCharge > 0 and not isAutoEmit(self.config.emitType) and status ~= CONSTANTS.SKILL_STATUS.BUFFING) then
    self.handEmitShadow:Hide()
  else
    self.handEmitShadow:Show()
  end

  -- 充能计时器只在类型为时间充能且充能状态且充能没满时启动, 其余停止

  self:SetChargeProgress(chargeProgress)
  if self.config.chargeType == CONSTANTS.CHARGE_TYPE.AUTO and status == CONSTANTS.SKILL_STATUS.CHARGING
    and self.emitCharge < self.levelConfig.maxEmitCharge then
    self:StartTimeCharge(chargeProgress)
  else
    self:StopTimeCharge()
  end
  if status == CONSTANTS.SKILL_STATUS.LOCKED then
    self.statusImg:SetTexture("images/ark_skill.xml", "sprite_skill_notready.tex")
    self.statusText:SetColour(1, 1, 1, 1)
    self.statusText:SetString("LOCK")
  elseif status == CONSTANTS.SKILL_STATUS.CHARGING then
    if isAutoEmit(self.config.emitType) then
      self.statusImg:SetTexture("images/ark_skill.xml", "sprite_skill_notready.tex")
      if self.emitCharge >= self.levelConfig.maxEmitCharge then
        self.statusText:SetString("")
      end
    else
      if self.emitCharge >= 1 then
        self.statusImg:SetTexture("images/ark_skill.xml", "sprite_skill_ready.tex")
        self.statusText:SetColour(0, 0, 0, 1)
      else
        self.statusImg:SetTexture("images/ark_skill.xml", "sprite_skill_notready.tex")
        self.statusText:SetColour(1, 1, 1, 1)
      end
      if self.emitCharge >= self.levelConfig.maxEmitCharge then
        self.statusText:SetString("READY")
      end
    end
  end
end

local function OnUpdate(self, dt)
  -- auto emit 旋转
  if self.autoEmit:IsVisible() then
    self.autoEmit:SetRotation(self.autoEmit:GetRotation() - 360 * dt / 10)
  end
  -- buff期间技能停止充能
  local leftBuffTime = UpdateTimeBuff(self, dt)
  if leftBuffTime == nil then
    UpdateTimeCharge(self, dt)
  elseif leftBuffTime > 0 then
    UpdateTimeCharge(self, dt + leftBuffTime)
  end
end

-- OnUpdate 需要第一帧检测, 第一帧要作点事情
function ArkSkill:OnUpdate(dt)
  SendModRPCToServer(GetModRPC("arkSkill", "RequestSyncSkillStatus"), self.idx)
  self.OnUpdate = OnUpdate
end

function ArkSkill:OnGainFocus()
  if not self.initComplete then
    return
  end
  ArkSkill._base.OnGainFocus(self)
  if not self.skillDesc then
    local descConfig = {
      locked = self.status == CONSTANTS.SKILL_STATUS.LOCKED,
      lockedDesc = self.config.lockedDesc,
      name = self.config.name,
      chargeType = self.config.chargeType,
      emitType = self.config.emitType,
      charge = self.levelConfig.charge,
      buffTime = self.levelConfig.buffTime,
      hotKey = self.config.hotKey,
      level = self.level,
      desc = self.levelConfig.desc,
    }
    self.skillDesc = self:AddChild(ark_skill_desc(self.owner, descConfig, self.idx))
    self.skillDesc:SetScale(1, 1, 1)
    local size = self.skillDesc:GetSize()
    self.skillDesc:SetPosition(-self.size[1] / 2 + size.x / 2, self.size[2] / 2 + size.y + 20, 0)
  end
  self.skillDesc:Show()
end

function ArkSkill:OnLoseFocus()
  ArkSkill._base.OnLoseFocus(self)
  if self.skillDesc then
    self.skillDesc:Kill()
    self.skillDesc = nil
  end
end

function ArkSkill:TryEmitSkill()
  if not self.initComplete then
    return
  end
  SendModRPCToServer(GetModRPC("arkSkill", "HandEmitSkill"), self.idx, TheInput:IsKeyDown(KEY_CTRL) or TheInput:IsKeyDown(KEY_RCTRL))
end

function ArkSkill:OnControl(control, down)
  if ArkSkill._base.OnControl(self, control, down) then
    return true
  end
  if control == CONTROL_ACCEPT then
    if down then
      self:TryEmitSkill()
      return true
    end
  end
end

return ArkSkill
