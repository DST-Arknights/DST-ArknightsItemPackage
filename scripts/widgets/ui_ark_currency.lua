local Widget = require "widgets/widget"
local Badge = require "widgets/badge"
local UIAnim = require "widgets/uianim"
local Text = require "widgets/text"
local Image = require "widgets/image"
local i18n = require "modmain/ark_item_i18n"

local UIArkCurrency = Class(Widget, function(self, owner)
    Widget._ctor(self, "ArkCurrencyUi")
    self.owner = owner
    self:SetScale(1, 1, 1)
    self:SetPosition(0, 0, 0)
    self:SetHoverText(i18n.getOtherI18n('goldName'))
    self.bg = self:AddChild(Image("images/ark_ui/ark_gray.xml", "ark_gray.tex"))
    self.bg:SetScale(3, .7, 1)
    self.bg:SetPosition(0, 0, 0)
    local goldIcon = self:AddChild(Image("images/ark_ui/ark_gold.xml", "ark_gold.tex"))
    goldIcon:SetScale(1.2, 1.2, 1.2)
    goldIcon:SetPosition(-60, 4, 0)
    self.goldIcon = goldIcon
    -- 添加一个文字展示金币
    local goldText = self:AddChild(Text(TALKINGFONT, 30))
    goldText:SetScale(1, .8, 1)
    goldText:SetPosition(20, 0, 0)
    goldText:SetString("0")
    self.goldText = goldText

end)

function UIArkCurrency:SetCurrency(currency)
    self.goldText:SetString(tostring(currency.gold))
end

return UIArkCurrency
