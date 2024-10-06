local Widget = require "widgets/widget"
local Badge = require "widgets/badge"
local UIAnim = require "widgets/uianim"
local Text = require "widgets/text"
local Image = require "widgets/image"

local UIArkCurrency = Class(Widget, function(self, owner)
    Widget._ctor(self, "ArkCurrencyUi")
    self.owner = owner
    self:SetScale(1, 1, 1)
    self:SetPosition(0, 0, 0)

    self.bg = self:AddChild(Image("images/ark_ui/ark_gray.xml", "ark_gray.tex"))
    self.bg:SetScale(5, 1.5, 1.5)
    self.bg:SetPosition(0, 0, 0)
    local goldIcon = self:AddChild(Image("images/ark_ui/ark_gold.xml", "ark_gold.tex"))
    goldIcon:SetScale(1.5, 1.5, 1.5)
    goldIcon:SetPosition(-50, 0, 0)
    self.goldIcon = goldIcon
    -- 添加一个文字展示金币
    local goldText = self:AddChild(Text(TALKINGFONT, 30))
    goldText:SetScale(1.5, 1.5, 1.5)
    goldText:SetPosition(0, 0, 0)
    goldText:SetString("0")
    self.goldText = goldText

end)

function UIArkCurrency:SetCurrency(currency)
    self.goldText:SetString(tostring(currency.gold))
end

return UIArkCurrency
