local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"
local UIAnim = require "widgets/uianim"
local BorderWidget = require "widgets/border_widget"

local EliteHoverTip = Class(Widget, function(self, text)
  Widget._ctor(self, "EliteHoverTip")
  self.paddingX = 8
  self.paddingY = 8
  self.minWidth = 100
  self.minHeight = 36

  self.bg = self:AddChild(BorderWidget(self.minWidth, self.minHeight, {
    borderWidth = 2,
    borderColor = { 0.45, 0.45, 0.45, 0.9 },
    backgroundColor = { 0.23, 0.23, 0.23, 0.7 },
  }))
  self.label = self:AddChild(Text(FALLBACK_FONT_FULL, 30, ""))
  self:SetText(text or "")
end)

function EliteHoverTip:SetText(text)
  self.label:SetString(text or "")
  local textW, textH = self.label:GetRegionSize()
  local width = math.max(self.minWidth, textW + self.paddingX * 2)
  local height = math.max(self.minHeight, textH + self.paddingY * 2)
  self.bg:SetSize(width, height)
  self.label:SetPosition(0, 0, 0)
end

local EliteUI = Class(Widget, function(self, owner)
  Widget._ctor(self, "EliteUI")
  self.owner = owner

  self.width = 40
  self.height = 100
  self.borderSize = 2
  self.iconWidth = 30
  self.blinkInterval = 0.3
  self.blinkTasks = {}

  -- 背景
  self.backgroundPanel = self:AddChild(BorderWidget(self.width, self.height, {
    borderWidth = self.borderSize,
    borderColor = { 0.23, 0.23, 0.23, 1 },
    backgroundColor = { 0, 0, 0, 0.5 },
  }))

  -- 潜能图标
  local potentialWidget = self:AddChild(UIAnim())
  local potentialImg = potentialWidget:AddChild(Image("images/ark_item_ui.xml", "potential_0_small.tex"))
  potentialWidget.potentialImg = potentialImg
  self.potentialImg = potentialImg
  local potentialW = potentialImg:GetSize()
  potentialImg:SetScale(self.iconWidth / potentialW)
  potentialImg:SetPosition(0, 25, 0)
  self.potentialWidget = potentialWidget

  -- 精英化图标
  local eliteWidget = self:AddChild(UIAnim())
  local eliteImg = eliteWidget:AddChild(Image("images/ark_item_ui.xml", "elite_0_small.tex"))
  eliteWidget.eliteImg = eliteImg
  self.eliteImg = eliteImg
  local eliteW, _ = eliteImg:GetSize()
  eliteImg:SetScale(self.iconWidth / eliteW)
  eliteImg:SetPosition(0, -12, 0)
  self.eliteWidget = eliteWidget

  -- 等级文本
  local levelTextWidget = self:AddChild(UIAnim())
  local levelText = levelTextWidget:AddChild(Text(SEGEOUI_ALPHANUM_ITALICFONT, 16, "LV1"))
  levelTextWidget.levelText = levelText
  self.levelText = levelText
  levelText:SetPosition(0, -40, 0)
  self.levelTextWidget = levelTextWidget

  -- 数据状态
  self.currentElite = 0
  self.currentLevel = 0
  self.currentPotential = 0

  self.potentialHoverTip = EliteHoverTip("")
  self.eliteHoverTip = EliteHoverTip("")
  self.levelHoverTip = EliteHoverTip("")

  local hoverCommonParams = {
    attach_to_parent = self,
    offset_x = -80,
    show_delay = 0.08,
    hide_delay = 0.12,
  }

  self.potentialImg:SetHoverWidget(self.potentialHoverTip, {
    attach_to_parent = hoverCommonParams.attach_to_parent,
    offset_x = hoverCommonParams.offset_x,
    offset_y = 0,
    show_delay = hoverCommonParams.show_delay,
    hide_delay = hoverCommonParams.hide_delay,
  })
  self.eliteImg:SetHoverWidget(self.eliteHoverTip, {
    attach_to_parent = hoverCommonParams.attach_to_parent,
    offset_x = hoverCommonParams.offset_x,
    offset_y = 0,
    show_delay = hoverCommonParams.show_delay,
    hide_delay = hoverCommonParams.hide_delay,
  })
  self.levelText:SetHoverWidget(self.levelHoverTip, {
    attach_to_parent = hoverCommonParams.attach_to_parent,
    offset_x = hoverCommonParams.offset_x,
    offset_y = 0,
    show_delay = hoverCommonParams.show_delay,
    hide_delay = hoverCommonParams.hide_delay,
  })
  self:RefreshHoverTips()

  self.initTask = self.inst:DoTaskInTime(0, function() 
    local state = self.owner.replica.ark_elite and self.owner.replica.ark_elite.state
    if state then
      self:SetElite(state.elite)
      self:SetLevel(state.level)
      self:SetPotential(state.potential)
    end
  end)
end)

function EliteUI:GetEliteHoverText(elite)
  local hoverStrings = STRINGS.UI.ARK_ELITE.HOVER.ELITE
  return hoverStrings[elite]
end

function EliteUI:RefreshHoverTips()
  ArkLogger:Debug("RefreshHoverTips", self.currentPotential, self.currentElite, self.currentLevel)
  self.potentialHoverTip:SetText(string.format(STRINGS.UI.ARK_ELITE.HOVER.POTENTIAL, self.currentPotential or 0))
  self.eliteHoverTip:SetText(self:GetEliteHoverText(self.currentElite))
  self.levelHoverTip:SetText(string.format(STRINGS.UI.ARK_ELITE.HOVER.LEVEL, self.currentLevel))
end

function EliteUI:Blink(widget)
  if self.blinkTasks[widget] then
    return
  end
  widget:GetAnimState():SetBloomEffectHandle("shaders/anim.ksh")
  self.blinkTasks[widget] = true
  widget:TintTo({r = 1, g = 1, b = 1, a = 1}, { r = 0, g = 0, b = 0, a = 1 },self.blinkInterval, function() 
    widget:TintTo({ r = 0, g = 0, b = 0, a = 1 }, {r = 1, g = 1, b = 1, a = 1},self.blinkInterval, function() 
      widget:TintTo({r = 1, g = 1, b = 1, a = 1}, { r = 0, g = 0, b = 0, a = 1 },self.blinkInterval, function() 
        widget:TintTo({ r = 0, g = 0, b = 0, a = 1 }, {r = 1, g = 1, b = 1, a = 1},self.blinkInterval, function() 
          widget:GetAnimState():ClearBloomEffectHandle()
          self.blinkTasks[widget] = nil
        end)
      end)
    end)
  end)
end
function EliteUI:Kill()
  if self.initTask then
    self.initTask:Cancel()
    self.initTask = nil
  end
  for widget, _ in pairs(self.blinkTasks) do
    widget:CancelTintTo(true)
  end
  self.blinkTasks = {}
  EliteUI._base.Kill(self)
end

function EliteUI:SetElite(elite)
  if self.currentElite ~= elite then
    self.currentElite = elite
    self.eliteWidget.eliteImg:SetTexture("images/ark_item_ui.xml", "elite_" .. elite - 1 .. "_small.tex")
    self:RefreshHoverTips()
    self:Blink(self.eliteWidget)
  end
end

function EliteUI:SetLevel(level)
  if self.currentLevel ~= level then
    self.currentLevel = level
    -- 获取 UIAnim 中的 Text 子组件
    local levelText = self.levelTextWidget.levelText
    if levelText then
      levelText:SetString("LV" .. level)
    end
    self:RefreshHoverTips()
    self:Blink(self.levelTextWidget)
  end
end

function EliteUI:SetPotential(potential)
  if self.currentPotential ~= potential then
    self.currentPotential = potential
    self.potentialWidget.potentialImg:SetTexture("images/ark_item_ui.xml", "potential_" .. potential - 1 .. "_small.tex")
    self:RefreshHoverTips()
    self:Blink(self.potentialWidget)
  end
end

function EliteUI:GetSize()
  return self.width, self.height
end
return EliteUI

