local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"
local CONSTANTS = require "ark_constants"
local TextButton = require "widgets/textbutton"
local utils = require "ark_utils"
local common = require "ark_common"

local PADDING = 60
local TAG_PADDING = 10

local ArkSkillDescText = Class(Widget, function(self, text, maxWidth)
  Widget._ctor(self, "ArkSkillDescText")
  self.h = 0
  self.w = 0
  self.maxWidth = maxWidth or 1000
  local H_OFFSET = 30
  local lines = string.split(text, '\n')

  for i, line in ipairs(lines) do
    if i ~= 1 then
      self.h = self.h + H_OFFSET  -- 添加行间距
    end

    -- 直接为每一行创建文本，不再进行复杂的字符统计和折叠
    local textWidget = self:AddChild(Text(FALLBACK_FONT_FULL, 80, line))
    local w, h = textWidget:GetRegionSize()
    textWidget:SetPosition(-self.maxWidth / 2 + w / 2, -self.h, 0)
    self.h = self.h + h
    self.w = math.max(self.w, w)
  end
end)

function ArkSkillDescText:GetSize()
  return self.maxWidth, self.h
end

local ArkSkillDesc = Class(Widget, function(self, owner, descConfig, id)
  Widget._ctor(self, "ArkSkillDesc")
  self.owner = owner
  self.size = {1000, 0} -- 初始时高度为0
  self.id = id
  
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
  if descConfig.activationMode == CONSTANTS.ACTIVATION_MODE.PASSIVE then
    local tag = self:AddChild(Widget("tag"))
    local tagBg = tag:AddChild(Image("images/ark_skill.xml", "skill_desc_bg4.tex"))
    local tagText = tag:AddChild(Text(FALLBACK_FONT_FULL, 70, STRINGS.UI.ARK_SKILL.EMIT_TYPE.PASSIVE))
    local tagSizeX, tagSizeY = tagBg:GetSize()
    tag:SetPosition(tagLeftOffset + tagSizeX / 2, topOffset, 0)
  else
    local tagEnergyBg = nil
    if descConfig.energyRecoveryMode == CONSTANTS.ENERGY_RECOVERY_MODE.AUTO then
      tagEnergyBg = Image("images/ark_skill.xml", "skill_desc_bg1.tex")
    elseif descConfig.energyRecoveryMode == CONSTANTS.ENERGY_RECOVERY_MODE.DEFENSIVE then
      tagEnergyBg = Image("images/ark_skill.xml", "skill_desc_bg3.tex")
    elseif descConfig.energyRecoveryMode == CONSTANTS.ENERGY_RECOVERY_MODE.ATTACK then
      tagEnergyBg = Image("images/ark_skill.xml", "skill_desc_bg3.tex")
    end
    local tagEnergy = self:AddChild(Widget("tagEnergy"))
    local tagEnergyBg = tagEnergy:AddChild(tagEnergyBg)
    local tagEnergySizeX, tagEnergySizeY = tagEnergyBg:GetSize()
    local tagEnergyText = tagEnergy:AddChild(Text(FALLBACK_FONT_FULL, 70, STRINGS.UI.ARK_SKILL.ENERGY_RECOVERY_MODE[string.upper(descConfig.energyRecoveryMode)]))
    tagEnergy:SetPosition(tagLeftOffset + tagEnergySizeX / 2, topOffset, 0)
    tagLeftOffset = tagLeftOffset + tagEnergySizeX + TAG_PADDING

    local tagEmit = self:AddChild(Widget("tagEmit"))
    local tagEmitBg = tagEmit:AddChild(Image("images/ark_skill.xml", "skill_desc_bg2.tex"))
    local tagEmitText = tagEmit:AddChild(Text(FALLBACK_FONT_FULL, 70, STRINGS.UI.ARK_SKILL.ACTIVATION_MODE[string.upper(descConfig.activationMode)]))
    local tagEmitSizeX, tagEmitSizeY = tagEmitBg:GetSize()
    tagEmit:SetPosition(tagLeftOffset + tagEmitSizeX / 2, topOffset, 0)
    tagLeftOffset = tagLeftOffset + tagEmitSizeX + TAG_PADDING

    local tagEnergyNum = self:AddChild(Widget("tagEnergyNum"))
    local tagEnergyNumBg = tagEnergyNum:AddChild(Image("images/ark_skill.xml", "skill_desc_bg4.tex"))
    local tagEnergyNumIcon = tagEnergyNum:AddChild(Image("images/ark_skill.xml", "skill_desc_icon_energy.tex"))
    tagEnergyNumIcon:SetSize(54, 54)
    tagEnergyNumIcon:SetPosition(-40, 0, 0)
    local tagEnergyNumText = tagEnergyNum:AddChild(Text(FALLBACK_FONT_FULL, 70, tostring(descConfig.activationEnergy)))
    tagEnergyNumText:SetPosition(20, 0, 0)
    local tagEnergyNumSizeX, tagEnergyNumSizeY = tagEnergyNumBg:GetSize()
    tagEnergyNum:SetPosition(tagLeftOffset + tagEnergyNumSizeX / 2, topOffset, 0)
    tagLeftOffset = tagLeftOffset + tagEnergyNumSizeX + TAG_PADDING

    if descConfig.buffDuration then
      local tagBuff = self:AddChild(Widget("tagBuff"))
      local tagBuffBg = tagBuff:AddChild(Image("images/ark_skill.xml", "skill_desc_bg6.tex"))
      local tagBuffIcon = tagBuff:AddChild(Image("images/ark_skill.xml", "skill_desc_icon_clock.tex"))
      tagBuffIcon:SetSize(46, 46)
      tagBuffIcon:SetPosition(-60, 0, 0)
      local tagBuffText =
      tagBuff:AddChild(Text(FALLBACK_FONT_FULL, 70, tostring(descConfig.buffDuration) .. STRINGS.UI.ARK_SKILL.SECONDS))
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
    descText:SetPosition(0, topOffset, 0)
    topOffset = topOffset -  descTextSizeH -- 更新 topOffset
  end

  topOffset = topOffset - 60
  -- 脚部
  local foot = self:AddChild(Widget("foot"))
  foot:SetPosition(0, topOffset, 0)
  local levelStr = tostring(descConfig.level)
  local levelString = "LV: " .. (STRINGS.UI.ARK_SKILL.LEVEL[levelStr] or levelStr)
  local levelText = foot:AddChild(Text(FALLBACK_FONT_FULL, 80, levelString))
  local levelTextSizeX, levelTextSizeY = levelText:GetRegionSize()
  levelText:SetPosition(leftOffset + levelTextSizeX / 2, 0, 0)
  topOffset = topOffset - levelTextSizeY -- 更新 topOffset

  -- 热键
  if descConfig.activationMode == CONSTANTS.ACTIVATION_MODE.MANUAL then
    local hotKeyText = foot:AddChild(Text(FALLBACK_FONT_FULL, 80))
    self.hotKeyText = hotKeyText
    hotKeyText:SetPosition(self.size[1] / 2 - 440, 0, 0)
    self:RefreshHotKey()
    local hotKeyButton = foot:AddChild(TextButton("hotkeySetting"))
    self.hotKeyButton = hotKeyButton
    hotKeyButton:SetTextSize(80)
    hotKeyButton:SetText("[" .. STRINGS.UI.ARK_SKILL.SETTING .. "]")
    hotKeyButton:SetFont(FALLBACK_FONT_FULL)
    hotKeyButton:SetPosition(self.size[1] / 2 - 240, 0, 0)
    hotKeyButton:SetOnClick(function()
      self:SettingHotKey()
    end)
    local cancelHotkeyButton = foot:AddChild(TextButton("cancelHotkey"))
    self.cancelHotkeyButton = cancelHotkeyButton
    cancelHotkeyButton:SetTextSize(80)
    cancelHotkeyButton:SetText("[" .. STRINGS.UI.ARK_SKILL.CANCEL .. "]")
    cancelHotkeyButton:SetFont(FALLBACK_FONT_FULL)
    cancelHotkeyButton:SetPosition(self.size[1] / 2 - 240, 0, 0)
    cancelHotkeyButton:SetOnClick(function()
      self:CancelSettingHotKey()
    end)
    cancelHotkeyButton:Hide()
    local hotKeyResetButton = foot:AddChild(TextButton("hotkeyReset"))
    hotKeyResetButton:SetTextSize(80)
    hotKeyResetButton:SetText("[" .. STRINGS.UI.ARK_SKILL.RESET .. "]")
    hotKeyResetButton:SetFont(FALLBACK_FONT_FULL)
    hotKeyResetButton:SetPosition(self.size[1] / 2 - 110, 0, 0)
    hotKeyResetButton:SetOnClick(function()
      ThePlayer.replica.ark_skill:RestoreDefaultHotkey(self.id)
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
  local hotkey = ThePlayer.replica.ark_skill:GetHotkey(self.id)
  ArkLogger:Debug('ArkSkillDesc:RefreshHotKey', self.id, hotkey)
  local hotKeyString = nil
  if hotkey ~= nil then
    hotKeyString = STRINGS.UI.CONTROLSSCREEN.INPUTS[1][hotkey]
  else
    hotKeyString = STRINGS.UI.ARK_SKILL.NONE
  end
  self.hotKeyText:SetString(STRINGS.UI.ARK_SKILL.HOT_KEY .. ": " .. hotKeyString)
end


function ArkSkillDesc:SettingHotKey()
  self.cancelHotkeyButton:Show()
  self.hotKeyButton:Hide()
  self.hotKeyText:SetString(STRINGS.UI.ARK_SKILL.PRESS_ANY_KEY)
  self._onKey = function(key, down)
    if down then
      -- 不检查冲突, 注册为新的按键
      ThePlayer.replica.ark_skill:SetHotkey(self.id, key)
      self:RefreshHotKey()
      self.cancelHotkeyButton:Hide()
      self.hotKeyButton:Show()
      return true -- 返回true表示消费事件并移除监听器
    end
  end
  local mgr = GetHotKeyManager(ThePlayer)
  mgr:ListenOnce(self._onKey)
end

function ArkSkillDesc:CancelSettingHotKey()
  self.cancelHotkeyButton:Hide()
  self.hotKeyButton:Show()
  local mgr = GetHotKeyManager(ThePlayer)
  mgr:CancelListenOnce(self._onKey)
  self._onKey = nil
  self:RefreshHotKey()
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
