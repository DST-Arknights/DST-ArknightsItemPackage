local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"
local UIAnim = require "widgets/uianim"
local BorderWidget = require "widgets/border_widget"

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
  self.bg1 = self.backgroundPanel.borderImage
  self.bg2 = self.backgroundPanel.innerImage

  -- 潜能图标
  local potentialWidget = self:AddChild(UIAnim())
  local potentialImg = potentialWidget:AddChild(Image("images/ark_item_ui.xml", "potential_0_small.tex"))
  potentialWidget.potentialImg = potentialImg
  local potentialW = potentialImg:GetSize()
  potentialImg:SetScale(self.iconWidth / potentialW)
  potentialImg:SetPosition(0, 25, 0)
  self.potentialWidget = potentialWidget

  -- 精英化图标
  local eliteWidget = self:AddChild(UIAnim())
  local eliteImg = eliteWidget:AddChild(Image("images/ark_item_ui.xml", "elite_0_small.tex"))
  eliteWidget.eliteImg = eliteImg
  local eliteW, _ = eliteImg:GetSize()
  eliteImg:SetScale(self.iconWidth / eliteW)
  eliteImg:SetPosition(0, -12, 0)
  self.eliteWidget = eliteWidget

  -- 等级文本
  local levelTextWidget = self:AddChild(UIAnim())
  local levelText = levelTextWidget:AddChild(Text(SEGEOUI_ALPHANUM_ITALICFONT, 16, "LV1"))
  levelTextWidget.levelText = levelText
  levelText:SetPosition(0, -40, 0)
  self.levelTextWidget = levelTextWidget

  -- 数据状态
  self.currentElite = 0
  self.currentLevel = 0
  self.currentPotential = 0

  self.initTask = self.inst:DoTaskInTime(0, function() 
    local state = self.owner.replica.ark_elite and self.owner.replica.ark_elite.state
    if state then
      self:SetElite(state.elite)
      self:SetLevel(state.level)
      self:SetPotential(state.potential)
    end
  end)
end)

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
    self:Blink(self.levelTextWidget)
  end
end

function EliteUI:SetPotential(potential)
  if self.currentPotential ~= potential then
    self.currentPotential = potential
    self.potentialWidget.potentialImg:SetTexture("images/ark_item_ui.xml", "potential_" .. potential - 1 .. "_small.tex")
    self:Blink(self.potentialWidget)
  end
end

function EliteUI:GetSize()
  return self.width, self.height
end
return EliteUI

