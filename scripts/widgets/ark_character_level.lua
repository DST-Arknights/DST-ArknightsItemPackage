local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"

local ArkCharacterLevel = Class(Widget, function(self, owner)
  Widget._ctor(self, "ArkCharacterLevel")
  self.owner = owner
  self.width = 80
  self.height = 210
  self.borderSize = 2
  self.iconWidth = 50
  local bg1 = self:AddChild(Image("images/ui.xml", "white.tex"))
  bg1:SetSize(self.width, self.height)
  bg1:SetTint(0.23, 0.23, 0.23, 1)
  local bg2 = self:AddChild(Image("images/ui.xml", "white.tex"))
  bg2:SetSize(self.width - self.borderSize * 2, self.height - self.borderSize * 2)
  bg2:SetTint(0, 0, 0, 0.5)

  local potential = self:AddChild(Image("images/ark_item_ui.xml", "potential_0_small.tex"))
  self.potential = potential
  local potentialW = potential:GetSize()
  potential:SetScale(self.iconWidth /potentialW)
  potential:SetPosition(0, 60, 0)


  local elite = self:AddChild(Image("images/ark_item_ui.xml", "elite_2_small.tex"))
  self.elite = elite
  local eliteW = elite:GetSize()
  elite:SetScale(self.iconWidth /eliteW)
  elite:SetPosition(0, -20, 0)

  local levelTipText = self:AddChild(Text(SEGEOUI_ALPHANUM_ITALICFONT, 32, "LV80"))
  levelTipText:SetPosition(0, -80, 0)
end)

function ArkCharacterLevel:GetSize()
  return self.width, self.height
end

return ArkCharacterLevel
