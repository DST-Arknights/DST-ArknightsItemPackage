local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"
local CONSTANTS = require "ark_constants"
local TextButton = require "widgets/textbutton"
local utils = require "ark_utils"
local common = require "ark_common"

local PADDING = 60
local TAG_PADDING = 10

local ArkSkillDescText = Class(Widget, function(self, text, maxWidth, maxHeight)
  Widget._ctor(self, "ArkSkillDescText")
  self.h = 0
  self.w = 0
  self.maxWidth = maxWidth or 1000
  self.maxHeight = maxHeight
  self.defaultLineMax = 40
  local H_OFFSET = 30
  local lines = string.split(text, '\n')
  local exceededHeight = false
  for i, line in ipairs(lines) do
    if i ~= 1 then
      self.h = self.h + H_OFFSET
    end
    local currentLineMax = self.defaultLineMax + 1
    while currentLineMax > 0 do
      currentLineMax = currentLineMax - 1
      local innerLines = utils.splitStringByLength(line, currentLineMax)
      local currentWidth = 0
      local currentHeight = 0
      local success = true
      for j, innerLine in ipairs(innerLines) do
        local text = self:AddChild(Text(FALLBACK_FONT_FULL, 80, innerLine))
        local w, h = text:GetRegionSize()
        if w > self.maxWidth then
          text:Kill()
          success = false
          break
        end
        text:SetPosition(-self.maxWidth / 2 + w / 2, -self.h - currentHeight, 0)
        currentWidth = math.max(currentWidth, w)
        currentHeight = currentHeight + h
        if j ~= #innerLines then
          currentHeight = currentHeight + H_OFFSET
        end
        if self.maxHeight and currentHeight >= self.maxHeight then
          exceededHeight = true
          break
        end
      end
      if success then
        self.w = math.max(self.w, currentWidth)
        self.h = self.h + currentHeight
        break
      end
    end
    if exceededHeight then
      break
    end
  end
end)

function ArkSkillDescText:GetSize()
  return self.w, self.h
end

local ArkSkillDesc = Class(Widget, function(self, owner, descConfig, idx)
  Widget._ctor(self, "ArkSkillDesc")
  self.owner = owner
  self.size = {1000, 0} -- 初始时高度为0
  self.hotKey = descConfig.hotKey
  self.idx = idx
  local bg = self:AddChild(Image("images/ui.xml", "white.tex"))
  bg:SetTint(0.23, 0.23, 0.23, 0.7)
  local leftOffset = -self.size[1] / 2 + PADDING
  local topOffset = -PADDING -- 初始时从顶部开始布局

  -- 技能名称
  local skillName = self:AddChild(Text(FALLBACK_FONT_FULL, 100, descConfig.name))
  local skillNameSizeX, skillNameSizeY = skillName:GetRegionSize()
  skillName:SetPosition(leftOffset + skillNameSizeX / 2, topOffset - skillNameSizeY / 2, 0)
  topOffset = topOffset - skillNameSizeY -- 更新 topOffset

  topOffset = topOffset - 80
  local tagLeftOffset = leftOffset
  -- 小标题
  -- 被动, 没有充能方式, 没有触发方式, 没有充能值, 没有buff持续时间
  if descConfig.emitType == CONSTANTS.EMIT_TYPE.PASSIVE then
    local tag = self:AddChild(Widget("tag"))
    local tagBg = tag:AddChild(Image("images/ark_skill.xml", "skill_desc_bg4.tex"))
    local tagText = tag:AddChild(Text(FALLBACK_FONT_FULL, 70, STRINGS.UI.ARK_SKILL.EMIT_TYPE.PASSIVE))
    local tagSizeX, tagSizeY = tagBg:GetSize()
    tag:SetPosition(tagLeftOffset + tagSizeX / 2, topOffset, 0)
  else
    local tagChargeBg = nil
    if descConfig.chargeType == CONSTANTS.CHARGE_TYPE.AUTO then
      tagChargeBg = Image("images/ark_skill.xml", "skill_desc_bg1.tex")
    elseif descConfig.chargeType == CONSTANTS.CHARGE_TYPE.UNDER_ATTACK then
      tagChargeBg = Image("images/ark_skill.xml", "skill_desc_bg3.tex")
    elseif descConfig.chargeType == CONSTANTS.CHARGE_TYPE.ATTACK then
      tagChargeBg = Image("images/ark_skill.xml", "skill_desc_bg3.tex")
    end
    local tagCharge = self:AddChild(Widget("tagCharge"))
    local tagChargeBg = tagCharge:AddChild(tagChargeBg)
    local tagChargeSizeX, tagChargeSizeY = tagChargeBg:GetSize()
    local tagChargeText = tagCharge:AddChild(Text(FALLBACK_FONT_FULL, 70, STRINGS.UI.ARK_SKILL.CHARGE_TYPE.NONE))
    tagCharge:SetPosition(tagLeftOffset + tagChargeSizeX / 2, topOffset, 0)
    tagLeftOffset = tagLeftOffset + tagChargeSizeX + TAG_PADDING

    local tagEmit = self:AddChild(Widget("tagEmit"))
    local tagEmitBg = tagEmit:AddChild(Image("images/ark_skill.xml", "skill_desc_bg2.tex"))
    local tagEmitText = tagEmit:AddChild(Text(FALLBACK_FONT_FULL, 70, STRINGS.UI.ARK_SKILL.EMIT_TYPE.PASSIVE))
    local tagEmitSizeX, tagEmitSizeY = tagEmitBg:GetSize()
    tagEmit:SetPosition(tagLeftOffset + tagEmitSizeX / 2, topOffset, 0)
    tagLeftOffset = tagLeftOffset + tagEmitSizeX + TAG_PADDING

    local tagChargeNum = self:AddChild(Widget("tagChargeNum"))
    local tagChargeNumBg = tagChargeNum:AddChild(Image("images/ark_skill.xml", "skill_desc_bg4.tex"))
    local tagChargeNumIcon = tagChargeNum:AddChild(Image("images/ark_skill.xml", "skill_desc_icon_charge.tex"))
    tagChargeNumIcon:SetSize(54, 54)
    tagChargeNumIcon:SetPosition(-40, 0, 0)
    local tagChargeNumText = tagChargeNum:AddChild(Text(FALLBACK_FONT_FULL, 70, tostring(descConfig.charge)))
    tagChargeNumText:SetPosition(20, 0, 0)
    local tagChargeNumSizeX, tagChargeNumSizeY = tagChargeNumBg:GetSize()
    tagChargeNum:SetPosition(tagLeftOffset + tagChargeNumSizeX / 2, topOffset, 0)
    tagLeftOffset = tagLeftOffset + tagChargeNumSizeX + TAG_PADDING

    if descConfig.buffTime then
      local tagBuff = self:AddChild(Widget("tagBuff"))
      local tagBuffBg = tagBuff:AddChild(Image("images/ark_skill.xml", "skill_desc_bg6.tex"))
      local tagBuffIcon = tagBuff:AddChild(Image("images/ark_skill.xml", "skill_desc_icon_clock.tex"))
      tagBuffIcon:SetSize(46, 46)
      tagBuffIcon:SetPosition(-60, 0, 0)
      local tagBuffText =
      tagBuff:AddChild(Text(FALLBACK_FONT_FULL, 70, tostring(descConfig.buffTime) .. STRINGS.UI.ARK_SKILL.SECOND))
      tagBuffText:SetPosition(30, 0, 0)
      local tagBuffSizeX, tagBuffSizeY = tagBuffBg:GetSize()
      tagBuff:SetPosition(tagLeftOffset + tagBuffSizeX / 2, topOffset, 0)
      tagLeftOffset = tagLeftOffset + tagBuffSizeX + TAG_PADDING
    end
  end
  topOffset = topOffset - 20 -- 更新 topOffset

  topOffset = topOffset - 80
  if descConfig.desc then
    local descText = self:AddChild(ArkSkillDescText(descConfig.desc, self.size[1] - PADDING * 2))
    local descTextSizeW, descTextSizeH = descText:GetSize()
    descText:SetPosition(leftOffset + descTextSizeW / 2, topOffset, 0)
    topOffset = topOffset -  descTextSizeH -- 更新 topOffset
  end

  topOffset = topOffset - 60
  -- 脚部
  local foot = self:AddChild(Widget("foot"))
  foot:SetPosition(0, topOffset, 0)
  local levelString = "LV: " .. common.formatSkillLevelString(descConfig.level)
  local levelText = foot:AddChild(Text(FALLBACK_FONT_FULL, 80, levelString))
  local levelTextSizeX, levelTextSizeY = levelText:GetRegionSize()
  levelText:SetPosition(leftOffset + levelTextSizeX / 2, 0, 0)
  topOffset = topOffset - levelTextSizeY -- 更新 topOffset

  -- 热键
  if descConfig.emitType == CONSTANTS.EMIT_TYPE.HAND then
    local hotKeyText = foot:AddChild(Text(FALLBACK_FONT_FULL, 80))
    self.hotKeyText = hotKeyText
    hotKeyText:SetPosition(self.size[1] / 2 - 440, 0, 0)
    self:RefreshHotKey()
    local hotKeyButton = foot:AddChild(TextButton("hotkeySetting"))
    hotKeyButton:SetTextSize(80)
    hotKeyButton:SetText("[" .. STRINGS.UI.ARK_SKILL.SETTING .. "]")
    hotKeyButton:SetFont(FALLBACK_FONT_FULL)
    self.hotKeyButton = hotKeyButton
    hotKeyButton:SetPosition(self.size[1] / 2 - 240, 0, 0)
    hotKeyButton:SetOnClick(function()
      self:SettingHotKey()
    end)
    local hotKeyResetButton = foot:AddChild(TextButton("hotkeyReset"))
    hotKeyResetButton:SetTextSize(80)
    hotKeyResetButton:SetText("[" .. STRINGS.UI.ARK_SKILL.RESET .. "]")
    hotKeyResetButton:SetFont(FALLBACK_FONT_FULL)
    hotKeyResetButton:SetPosition(self.size[1] / 2 - 110, 0, 0)
    hotKeyResetButton:SetOnClick(function()
      ThePlayer:SaveArkSkillLocalHotKey(self.idx, nil)
      ThePlayer:RefreshArkSkillLocalHotKey()
      local hotKey = ThePlayer:GetArkSkillLocalHotKey(self.idx)
      self.hotKey = hotKey
      self:RefreshHotKey()
    end)
  end
  -- topOffset = topOffset - PADDING -- 更新 topOffset
  -- 计算最终高度
  self.size[2] = self.size[2] - topOffset
  bg:SetSize(self.size)
  bg:SetPosition(0, -self.size[2] / 2, 0)
end)

function ArkSkillDesc:RefreshHotKey()
  local hotKeyString = nil
  if self.hotKey ~= nil then
    hotKeyString = STRINGS.UI.CONTROLSSCREEN.INPUTS[1][self.hotKey]
  else
    hotKeyString = STRINGS.UI.ARK_SKILL.NONE
  end
  self.hotKeyText:SetString(STRINGS.UI.ARK_SKILL.HOT_KEY .. ": " .. hotKeyString)
end

function ArkSkillDesc:SettingHotKeyCallback(key, conflictIdx)
  if conflictIdx and conflictIdx ~= self.idx then
    self:RefreshHotKey()
    self.hotKeyText:SetString(STRINGS.UI.ARK_SKILL.TIP_SETTING_SKILL_HOT_KEY_CONFLICT)
    return
  end
  self.hotKey = key
  ThePlayer:SaveArkSkillLocalHotKey(self.idx, key)
  self:RefreshHotKey()
  self.hotKeyButton:SetText("[" .. STRINGS.UI.ARK_SKILL.SETTING .. "]")
  ThePlayer:RefreshArkSkillLocalHotKey()
  ThePlayer.HUD._settingSkillHotKeyCallback = nil
end

function ArkSkillDesc:SettingHotKey()
  if ThePlayer.HUD._settingSkillHotKeyCallback then
    self:RefreshHotKey()
    self.hotKeyButton:SetText("[" .. STRINGS.UI.ARK_SKILL.SETTING .. "]")
    ThePlayer.HUD._settingSkillHotKeyCallback = nil
  else
    self.hotKeyText:SetString(STRINGS.UI.ARK_SKILL.TIP_SETTING_SKILL_HOT_KEY)
    self.hotKeyButton:SetText("[" .. STRINGS.UI.ARK_SKILL.CANCEL .. "]")
    ThePlayer.HUD._settingSkillHotKeyCallback = function(key, conflictIdx)
      self:SettingHotKeyCallback(key, conflictIdx)
    end
  end
end

function ArkSkillDesc:GetSize()
  return Vector3(self.size[1], self.size[2], 0)
end

function ArkSkillDesc:Kill()
  ThePlayer.HUD._settingSkillHotKeyCallback = nil
  -- 调用基类的 Kill 方法
  ArkSkillDesc._base.Kill(self)
end

return ArkSkillDesc
