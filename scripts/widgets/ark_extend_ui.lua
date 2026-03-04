local ArkEliteUI = require "widgets/ark_elite_ui"
local ArkSkills = require "widgets/ark_skills"
local Widget = require "widgets/widget"
local UIArkCurrency = require "widgets/ui_ark_currency"
local ExpBar = require "widgets/ark_exp_bar"
local ArkBuffIcons = require "widgets/ark_buff_icons"

local ArkExtendUi =Class(Widget, function(self, owner, controls)
  Widget._ctor(self, "ArkExtendUi")
  self.owner = owner
  self.controls = controls
  self.handBase = controls.bottom_root:AddChild(Widget("arkExtendUiHandBase"))
  self.toprightBase = controls.topright_root:AddChild(Widget("arkExtendUiToprightBase"))
  self.setup_task = owner:DoTaskInTime(0, function()
    if owner.replica.ark_skill then
      self:SetupSkill()
    end
    if owner.replica.ark_elite then
      self:SetupElite()
      self:SetupExpBar()
    end
    if owner.replica.ark_currency then
      self:SetupCurrency()
    end
    self.setup_task = nil
  end)
  self:SetupBuffIcons()
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
  self.skills = self.handBase:AddChild(ArkSkills(self.owner, self.owner.replica.ark_skill and self.owner.replica.ark_skill.configs))
  self.skills.updatedLayout = function()
    self:UpdateLayout()
  end
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
    local miniMap = self.controls.minimap_small
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
  self:UpdateLayout()
end

function ArkExtendUi:RemoveExpBar()
  if self.expBar then
    self.expBar:Kill()
    self.expBar = nil
  end
  self:UpdateLayout()
end

function ArkExtendUi:SetupBuffIcons()
  if self.buffIcons then
    return
  end
  local buffIcons = self.handBase:AddChild(ArkBuffIcons(self.owner))
  self.buffIcons = buffIcons
  self:UpdateLayout()
end

function ArkExtendUi:RemoveBuffIcons()
  if self.buffIcons then
    self.buffIcons:Kill()
    self.buffIcons = nil
  end
  self:UpdateLayout()
end
function ArkExtendUi:UpdateLayout()
  ArkLogger:Debug('ark_extend_ui UpdateLayout')
  self.handBase:SetPosition(-486, 130, 0)

  local ELITE_X = 20
  local CONTENT_X = 50
  local SKILLS_Y = 18
  local BUFF_Y = -16
  local EXP_Y = -40
  local BUFF_GAP_AFTER_SKILLS = 16

  local hasElite = self.elite ~= nil
  local hasSkills = self.skills ~= nil
  local hasExpBar = self.expBar ~= nil

  if hasElite then
    self.elite:SetPosition(ELITE_X, 0, 0)
  end

  local contentX = CONTENT_X
  if not hasElite then
    contentX = contentX - (CONTENT_X - ELITE_X)
  end

  local collapseDownY = hasExpBar and 0 or (EXP_Y - BUFF_Y)
  local skillsY = SKILLS_Y + collapseDownY
  local buffY = BUFF_Y + collapseDownY

  local skillsW = hasSkills and self.skills:GetSize() or 0
  if hasSkills then
    self.skills:SetPosition(contentX, skillsY, 0)
  end
  if hasExpBar then
    self.expBar:SetPosition(contentX, EXP_Y, 0)
  end
  if self.buffIcons then
    local buffX = contentX
    if hasSkills then
      buffX = contentX + skillsW + BUFF_GAP_AFTER_SKILLS
    end
    self.buffIcons:SetPosition(buffX, buffY, 0)
  end
end

return ArkExtendUi
