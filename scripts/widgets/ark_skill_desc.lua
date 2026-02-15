local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"
local BorderWidget = require "widgets/border_widget"
local CONSTANTS = require "ark_constants"
local TextButton = require "widgets/textbutton"

local PADDING = 24
local TAG_PADDING = 4

local ENERGY_RECOVERY_MODE_TO_TAG_BG_TEX = {
  [CONSTANTS.ENERGY_RECOVERY_MODE.AUTO] = "skill_desc_bg1.tex",
  [CONSTANTS.ENERGY_RECOVERY_MODE.DEFENSIVE] = "skill_desc_bg3.tex",
  [CONSTANTS.ENERGY_RECOVERY_MODE.ATTACK] = "skill_desc_bg3.tex",
}

local function GetEnergyRecoveryTagBgTex(energyRecoveryMode)
  return ENERGY_RECOVERY_MODE_TO_TAG_BG_TEX[energyRecoveryMode] or "skill_desc_bg1.tex"
end

local ArkSkillDescText = Class(Widget, function(self, text, maxWidth)
  Widget._ctor(self, "ArkSkillDescText")
  self.h = 0
  self.w = 0
  self.maxWidth = maxWidth or 400
  local fontSize = 32
  local maxLines = 20
  local lineHeight = fontSize * 1.0

  local textWidget = self:AddChild(Text(FALLBACK_FONT_FULL, fontSize, ""))
  local numLines = textWidget:SetMultilineTruncatedString(
    text or "",
    maxLines,
    self.maxWidth,
    nil,
    true,
    true,
    fontSize
  )

  numLines = math.max(1, numLines or 1)
  self.h = numLines * lineHeight
  self.w = self.maxWidth

  textWidget:SetRegionSize(self.maxWidth, self.h)
  textWidget:SetHAlign(ANCHOR_LEFT)
  textWidget:SetVAlign(ANCHOR_TOP)
  textWidget:SetPosition(0, -self.h / 2, 0)
end)

function ArkSkillDescText:GetSize()
  return self.maxWidth, self.h
end

local ArkSkillDescTag = Class(Widget, function(self, cfg) 
  Widget._ctor(self, "ArkSkillDescTag")
  self.size = {80, 20}
  self.fontSize = 28
  -- 统一tag图标尺寸（不再区分大小）
  self.iconSize = {18, 18}
  self.gap = 5
  self:AddChild(Image(cfg.bg.atlas, cfg.bg.tex)):SetSize(self.size)
  
  local icon
  if cfg.icon then
    icon = self:AddChild(Image(cfg.icon.atlas, cfg.icon.tex))
    icon:SetSize(self.iconSize)
  end
  
  local text = self:AddChild(Text(FALLBACK_FONT_FULL, self.fontSize, cfg.text))
  local textW, textH = text:GetRegionSize()
  
  -- 计算icon和text的总宽度
  local totalWidth = textW
  if icon then
    totalWidth = totalWidth + self.iconSize[1] + self.gap
  end

  -- 设置位置
  local startX = -totalWidth / 2
  if icon then
    icon:SetPosition(startX + self.iconSize[1] / 2, 0, 0)
    startX = startX + self.iconSize[1] + self.gap
  end
  text:SetPosition(startX + textW / 2, 0, 0)
end)

function ArkSkillDescTag:GetSize()
  return self.size[1], self.size[2]
end


local ArkSkillDesc = Class(Widget, function(self, owner, descConfig, id)
  Widget._ctor(self, "ArkSkillDesc")
  self.owner = owner
  self.size = {400, 0} -- 初始时高度为0
  self.id = id
  
  local bg = self:AddChild(BorderWidget(self.size[1], 0, {
    borderWidth = 2,
    borderColor = { 0.45, 0.45, 0.45, 0.9 },
    backgroundColor = { 0.23, 0.23, 0.23, 0.7 },
  }))
  local leftOffset = -self.size[1] / 2 + PADDING
  local topOffset = -PADDING -- 初始时从顶部开始布局

    -- 技能名称
  local skillName = self:AddChild(Text(FALLBACK_FONT_FULL, 40, descConfig.name))
  local skillNameSizeX, skillNameSizeY = skillName:GetRegionSize()
  skillName:SetPosition(leftOffset + skillNameSizeX / 2, topOffset - skillNameSizeY / 2, 0)
  topOffset = topOffset - skillNameSizeY -- 更新 topOffset

  topOffset = topOffset - 32
  local tagLeftOffset = leftOffset
  -- 小标题
  -- 被动, 没有充能方式, 没有触发方式, 没有充能值, 没有buff持续时间
  local tags = {}
  if descConfig.activationMode == CONSTANTS.ACTIVATION_MODE.PASSIVE then
    tags = {
      {
        bg = { atlas = "images/ark_skill.xml", tex = "skill_desc_bg4.tex" },
        text = STRINGS.UI.ARK_SKILL.EMIT_TYPE.PASSIVE,
      },
    }
  else
    local tagEnergyBgTex = GetEnergyRecoveryTagBgTex(descConfig.energyRecoveryMode)
    tags = {
      {
        bg = { atlas = "images/ark_skill.xml", tex = tagEnergyBgTex },
        text = STRINGS.UI.ARK_SKILL.ENERGY_RECOVERY_MODE[string.upper(descConfig.energyRecoveryMode)],
      },
      {
        bg = { atlas = "images/ark_skill.xml", tex = "skill_desc_bg2.tex" },
        text = STRINGS.UI.ARK_SKILL.ACTIVATION_MODE[string.upper(descConfig.activationMode)],
      },
      {
        bg = { atlas = "images/ark_skill.xml", tex = "skill_desc_bg4.tex" },
        icon = { atlas = "images/ark_skill.xml", tex = "skill_desc_icon_energy.tex" },
        text = tostring(descConfig.activationEnergy),
      },
    }

    if descConfig.buffDuration then
      table.insert(tags, {
        bg = { atlas = "images/ark_skill.xml", tex = "skill_desc_bg6.tex" },
        icon = { atlas = "images/ark_skill.xml", tex = "skill_desc_icon_clock.tex" },
        text = tostring(descConfig.buffDuration) .. STRINGS.UI.ARK_SKILL.SECONDS,
      })
    end
  end

  -- 统一计算与布局tag，减少冗余
  for _, tagCfg in ipairs(tags) do
    local tag = self:AddChild(ArkSkillDescTag(tagCfg))
    local tagW = select(1, tag:GetSize())
    tag:SetPosition(tagLeftOffset + tagW / 2, topOffset, 0)
    tagLeftOffset = tagLeftOffset + tagW + TAG_PADDING
  end
  topOffset = topOffset - 8 -- 更新 topOffset

  topOffset = topOffset - 32
  if descConfig.desc then
    local descText = self:AddChild(ArkSkillDescText(descConfig.desc, self.size[1] - PADDING * 2))
    local descTextSizeW, descTextSizeH = descText:GetSize()
    descText:SetPosition(0, topOffset, 0)
    topOffset = topOffset -  descTextSizeH -- 更新 topOffset
  end

  topOffset = topOffset - 24
  -- 脚部
  local foot = self:AddChild(Widget("foot"))
  foot:SetPosition(0, topOffset, 0)
  local levelStr = tostring(descConfig.level)
  local levelString = "LV: " .. (STRINGS.UI.ARK_SKILL.LEVEL[levelStr] or levelStr)
  local levelText = foot:AddChild(Text(FALLBACK_FONT_FULL, 32, levelString))
  local levelTextSizeX, levelTextSizeY = levelText:GetRegionSize()
  levelText:SetPosition(leftOffset + levelTextSizeX / 2, 0, 0)
  topOffset = topOffset - levelTextSizeY -- 更新 topOffset

  -- 热键
  if descConfig.activationMode == CONSTANTS.ACTIVATION_MODE.MANUAL then
    local hotKeyText = foot:AddChild(Text(FALLBACK_FONT_FULL, 32))
    self.hotKeyText = hotKeyText
    hotKeyText:SetPosition(self.size[1] / 2 - 176, 0, 0)
    self:RefreshHotKey()
    local hotKeyButton = foot:AddChild(TextButton("hotkeySetting"))
    self.hotKeyButton = hotKeyButton
    hotKeyButton:SetTextSize(32)
    hotKeyButton:SetText("[" .. STRINGS.UI.ARK_SKILL.SETTING .. "]")
    hotKeyButton:SetFont(FALLBACK_FONT_FULL)
    hotKeyButton:SetPosition(self.size[1] / 2 - 96, 0, 0)
    hotKeyButton:SetOnClick(function()
      self:SettingHotKey()
    end)
    local cancelHotkeyButton = foot:AddChild(TextButton("cancelHotkey"))
    self.cancelHotkeyButton = cancelHotkeyButton
    cancelHotkeyButton:SetTextSize(32)
    cancelHotkeyButton:SetText("[" .. STRINGS.UI.ARK_SKILL.CANCEL .. "]")
    cancelHotkeyButton:SetFont(FALLBACK_FONT_FULL)
    cancelHotkeyButton:SetPosition(self.size[1] / 2 - 96, 0, 0)
    cancelHotkeyButton:SetOnClick(function()
      self:CancelSettingHotKey()
    end)
    cancelHotkeyButton:Hide()
    local hotKeyResetButton = foot:AddChild(TextButton("hotkeyReset"))
    hotKeyResetButton:SetTextSize(32)
    hotKeyResetButton:SetText("[" .. STRINGS.UI.ARK_SKILL.RESET .. "]")
    hotKeyResetButton:SetFont(FALLBACK_FONT_FULL)
    hotKeyResetButton:SetPosition(self.size[1] / 2 - 44, 0, 0)
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
