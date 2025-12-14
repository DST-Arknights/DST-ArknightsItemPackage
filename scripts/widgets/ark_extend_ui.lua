local ArkEliteUI = require "widgets/ark_elite_ui"
local ArkSkills = require "widgets/ark_skills"
local Widget = require "widgets/widget"
local UIArkCurrency = require "widgets/ui_ark_currency"
local ExpBar = require "widgets/ark_exp_bar"
local common = require "ark_common"

local ArkExtendUi =Class(Widget, function(self, owner)
  Widget._ctor(self, "ArkExtendUi")
  self.owner = owner
  self.handBase = ThePlayer.HUD.controls.bottom_root:AddChild(Widget("arkExtendUiHandBase"))
  self.toprightBase = ThePlayer.HUD.controls.topright_root:AddChild(Widget("arkExtendUiToprightBase"))
  self.setup_task = owner:DoTaskInTime(0, function()
    if owner.replica.ark_skill then
      self:SetupSkill()
    end
    if owner.replica.ark_elite then
      self:SetupElite()
      self:SetupExpBar()
      self:OnEliteDirty(owner.replica.ark_elite.state)
    end
    if owner.replica.ark_currency then
      self:SetupCurrency()
    end
    self.setup_task = nil
  end)
end)

function ArkExtendUi:Kill()
  if self.setup_task then
    self.setup_task:Cancel()
    self.setup_task = nil
  end
  if self.handBase then
    self.handBase:Kill()
    self.handBase = nil
  end
  if self.toprightBase then
    self.toprightBase:Kill()
    self.toprightBase = nil
  end
  ArkExtendUi._base.Kill(self)
end

function ArkExtendUi:Show()
  self.handBase:Show()
end

function ArkExtendUi:Hide()
  self.handBase:Hide()
end

function ArkExtendUi:SetupSkill()
  if self.skills then
    return
  end
  self.skills = self.handBase:AddChild(ArkSkills(self.owner, self.owner.replica.ark_skill.configs))
  self:UpdateLayout()
end

function ArkExtendUi:RemoveSkill()
  if self.skills then
    self.skills:Kill()
    self.skills = nil
  end
  self:UpdateLayout()
end
function ArkExtendUi:SetupElite()
  if self.elite then
    return
  end
  local elite = self.handBase:AddChild(ArkEliteUI(self.owner))
  self.elite = elite
  self:UpdateLayout()
end

function ArkExtendUi:RemoveElite()
  if self.elite then
    self.elite:Kill()
    self.elite = nil
  end
  self:UpdateLayout()
end

function ArkExtendUi:SetupCurrency()
  if self.currency then
    return
  end
  local TOP_PADDING = 14;
  local RIGHT_PADDING = 240;
  local currency = self.toprightBase:AddChild(UIArkCurrency(self.owner))
  self.currency = currency
  local originUiW, originUiH = currency:GetSize()
  currency:SetPosition(-originUiW / 2 - RIGHT_PADDING, -originUiH / 2 - TOP_PADDING, 0)
  self._currency_map_task = self.owner:DoTaskInTime(0.1, function()
    local miniMap = ThePlayer.HUD.controls.minimap_small
    if not miniMap then
      return
    end
    local nowPosition = miniMap:GetPosition()
    local _SetPosition = miniMap.SetPosition
    local offset_y = - TOP_PADDING - originUiH + 15
    function miniMap:SetPosition(pos, y, z)
      _SetPosition(miniMap, pos, y + offset_y, z)
    end
    miniMap:SetPosition(nowPosition.x, nowPosition.y, nowPosition.z)
    self._currency_map_task = nil
  end)
end

function ArkExtendUi:RemoveCurrency()
  if self.currency then
    self.currency:Kill()
    self.currency = nil
  end
  if self._currency_map_task then
    self._currency_map_task:Cancel()
    self._currency_map_task = nil
  end
end

function ArkExtendUi:SetupExpBar()
  if self.expBar then
    return
  end
  local expBar = self.handBase:AddChild(ExpBar(self.owner))
  self.expBar = expBar

  -- 注册升级完成回调
  expBar:SetOnLevelUpComplete(function(level)
    if self.elite then
      local state = self.owner.replica.ark_elite.state
      self.elite:SetData(state.elite, level, state.potential)
    end
  end)
  self:UpdateLayout()
end

function ArkExtendUi:RemoveExpBar()
  if self.expBar then
    self.expBar:Kill()
    self.expBar = nil
  end
  self:UpdateLayout()
end

function ArkExtendUi:OnEliteDirty(state)
  if state.level == 0 then
    return
  end
  -- 计算升级队列
  local oldLevel = self.lastLevel or state.level
  local newLevel = state.level

  if oldLevel ~= newLevel then
    -- 有等级变化，计算升级队列
    local levelUpQueue = self:_CalculateLevelUpQueue(oldLevel, newLevel)

    -- 启动 ExpBar 的升级序列
    if self.expBar then
      local needExp = self.owner.replica.ark_elite:GetLevelUpExp(newLevel)
      self.expBar:PlayLevelUpSequence(levelUpQueue, state.currentExp, needExp)
    end
  else
    -- 没有等级变化，只更新经验
    if self.expBar then
      local rep = self.owner.replica.ark_elite
      local needExp = rep:GetLevelUpExp(state.level)
      if rep.IsAtLevelCap and rep:IsAtLevelCap() then
        -- 满级：经验条应保持满格
        self.expBar:SetFullAtCap()
      else
        self.expBar:UpdateExp(state.currentExp, needExp)
      end
    end
  end

  self.lastLevel = newLevel
end

function ArkExtendUi:_CalculateLevelUpQueue(oldLevel, newLevel)
  local queue = {}
  for level = oldLevel + 1, newLevel do
    table.insert(queue, {level = level})
  end
  return queue
end
function ArkExtendUi:UpdateLayout()
  ArkLogger:Debug('ark_extend_ui UpdateLayout')
  self.handBase:SetPosition(-480, 130, 0)
  if self.elite then
    self.elite:SetPosition(20, 0, 0)
  end
  if self.skills then
  self.skills:SetPosition(50, 18, 0)
  end
  if self.expBar then
    self.expBar:SetPosition(50, -40, 0)
  end
end

return ArkExtendUi
