local ArkEliteUI = require "widgets/ark_elite_ui"
local ArkSkills = require "widgets/ark_skills"
local ArkTalents = require "widgets/ark_talents"
local Widget = require "widgets/widget"
local UIArkCurrency = require "widgets/ui_ark_currency"
local ExpBar = require "widgets/ark_exp_bar"
local ArkBuffIcons = require "widgets/ark_buff_icons"
local EmoticonBtn = require "widgets/emoticon_btn"

local ArkExtendUi =Class(Widget, function(self, owner, controls)
  Widget._ctor(self, "ArkExtendUi")
  self.owner = owner
  self.controls = controls
  self.handBase = controls.inv.root:AddChild(Widget("arkExtendUiHandBase"))
  self.toprightBase = controls.topright_root:AddChild(Widget("arkExtendUiToprightBase"))
  self.setup_task = owner:DoTaskInTime(0, function()
    if owner.replica.ark_elite then
      self:SetupElite()
      self:SetupExpBar()
    end
    if owner.replica.ark_currency then
      self:SetupCurrency()
    end
    self.setup_task = nil
  end)
  self:SetupSkill()
  self:SetupTalents()
  self:SetupBuffIcons()
  self:SetupEmoticonBtn()
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
    ArkLogger:Debug("ArkExtendUi:SetupSkill already has skills")
    return
  end
  ArkLogger:Debug("ArkExtendUi:SetupSkill")
  self.skills = self.handBase:AddChild(ArkSkills(self.owner))
  self.skills.updatedLayout = function()
    self:UpdateLayout()
  end
  self:UpdateLayout()
end

function ArkExtendUi:SetupEmoticonBtn()
  if self.emoticonBtn then
    return
  end
  self.emoticonBtn = self.handBase:AddChild(EmoticonBtn())
  self:UpdateLayout()
end

function ArkExtendUi:RemoveEmoticonBtn()
  if self.emoticonBtn then
    self.emoticonBtn:Kill()
    self.emoticonBtn = nil
  end
  self:UpdateLayout()
end

function ArkExtendUi:RemoveSkill()
  ArkLogger:Debug("ArkExtendUi:RemoveSkill")
  if self.skills then
    self.skills:Kill()
    self.skills = nil
  end
  self:UpdateLayout()
end

function ArkExtendUi:SetupTalents()
  if self.talents then return end
  local talents = self.handBase:AddChild(ArkTalents(self.owner))
  self.talents = talents
  self.talents.updatedLayout = function()
    self:UpdateLayout()
  end
  self:UpdateLayout()
end

function ArkExtendUi:RemoveTalents()
  if self.talents then
    self.talents:Kill()
    self.talents = nil
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
  local handBaseScale = TUNING.ARK_CONFIG.hand_base_scale
  local BASE_Y = 100
  local y = BASE_Y * handBaseScale
  if self.controls.inv.toprow then
    local pos = self.controls.inv.toprow:GetPosition()
    y = y + pos.y
  end
  self.handBase:SetPosition(-810, y, 0)

  local ELITE_X = 20
  local ELITE_WIDTH = 40
  local ELITE_HEIGHT = 100
  local CONTENT_X = 50
  local SKILLS_Y = 18
  local TALENTS_Y = -8        -- 天赋栏 Y，位于技能与 buff 之间
  local BUFF_Y = -12
  local EXP_Y = -40
  local BUFF_GAP_AFTER_TALENTS = 10
  local TALENT_GAP_AFTER_SKILLS = 16
  local EMOTICON_BUTTON_GAP = 12
  local EMOTICON_PANEL_LEFT = -6
  local EMOTICON_PANEL_GAP = 12

  local hasElite  = self.elite   ~= nil
  local hasSkills = self.skills  ~= nil
  local hasTalents = self.talents ~= nil
  local hasExpBar = self.expBar  ~= nil

  if hasElite then
    self.elite:SetPosition(ELITE_X, 0, 0)
  end

  local contentX = CONTENT_X
  if not hasElite then
    contentX = contentX - (CONTENT_X - ELITE_X)
  end

  local collapseDownY = hasExpBar and 0 or (EXP_Y - BUFF_Y)
  local skillsY  = SKILLS_Y  + collapseDownY
  local talentsY = TALENTS_Y + collapseDownY
  local buffY    = BUFF_Y    + collapseDownY

  local skillsW  = hasSkills  and self.skills:GetSize()  or 0
  local talentsW = hasTalents and self.talents:GetSize() or 0

  if hasSkills then
    self.skills:SetPosition(contentX, skillsY, 0)
  end
  if hasExpBar then
    self.expBar:SetPosition(contentX, EXP_Y, 0)
  end

  -- 天赋栏：紧接在技能后，X 轴延续技能右边缘+间距
  if hasTalents then
    local talentX = contentX
    if hasSkills then
      talentX = contentX + skillsW + TALENT_GAP_AFTER_SKILLS
    end
    self.talents:SetPosition(talentX, talentsY, 0)
  end

  -- buff栏：紧接在天赋后（或技能后）
  if self.buffIcons then
    local buffX = contentX
    if hasTalents and talentsW > 0 then
      local talentStartX = contentX
      if hasSkills then talentStartX = contentX + skillsW + TALENT_GAP_AFTER_SKILLS end
      buffX = talentStartX + talentsW + BUFF_GAP_AFTER_TALENTS
    elseif hasSkills then
      buffX = contentX + skillsW + TALENT_GAP_AFTER_SKILLS
    end
    self.buffIcons:SetPosition(buffX, buffY, 0)
  end

  if self.emoticonBtn then
    local topY = 0
    if hasElite then
      topY = math.max(topY, ELITE_HEIGHT * 0.5)
    end
    if hasSkills then
      local _, skillsH = self.skills:GetSize()
      topY = math.max(topY, skillsY + skillsH * 0.5)
    end
    if hasExpBar then
      local _, expBarH = self.expBar:GetSize()
      topY = math.max(topY, EXP_Y + expBarH * 0.5)
    end

    local panelHeight = self.emoticonBtn:GetPanelHeight()
    local panelX = EMOTICON_PANEL_LEFT + self.emoticonBtn:GetPanelWidth() * 0.5
    local buttonWidth = self.emoticonBtn:GetButtonWidth()
    local buttonX = ELITE_X - ELITE_WIDTH * 0.5 - EMOTICON_BUTTON_GAP - buttonWidth * 0.5
    local buttonHeight = self.emoticonBtn:GetButtonHeight()
    local buttonY = -ELITE_HEIGHT * 0.5 + buttonHeight * 0.5
    local panelBottomY = topY + EMOTICON_PANEL_GAP
    local panelY = panelBottomY + panelHeight * 0.5
    self.emoticonBtn:SetAnchors(buttonX, buttonY, panelX, panelY)
  end
  self.handBase:SetScale(handBaseScale, handBaseScale)
end

return ArkExtendUi
