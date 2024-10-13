local Widget = require "widgets/widget"
local Badge = require "widgets/badge"
local UIAnim = require "widgets/uianim"
local Text = require "widgets/text"
local Image = require "widgets/image"
local i18n = require "modmain/ark_item_i18n"

local UIArkCurrency = Class(Widget, function(self, owner)
    Widget._ctor(self, "ArkCurrencyUi")
    self.owner = owner
    self:SetHoverText(i18n.getOtherI18n('goldName'))
    self.bg = self:AddChild(Image("images/ark_ui/ark_currency_bg.xml", "ark_currency_bg.tex"))
    local goldIcon = self:AddChild(Image("images/ark_ui/ark_currency_gold_icon.xml", "ark_currency_gold_icon.tex"))
    goldIcon:SetPosition(-54, 4, 0)
    self.goldIcon = goldIcon
    -- 添加一个文字展示金币
    local goldText = self:AddChild(Text(TALKINGFONT, 30))
    goldText:SetScale(1, .8, 1)
    goldText:SetPosition(20, 0, 0)
    goldText:SetString("0")
    self.goldText = goldText

end)

function UIArkCurrency:SetArkCurrency(currency)
    self.goldText:SetString(tostring(currency.gold))
end

return UIArkCurrency
