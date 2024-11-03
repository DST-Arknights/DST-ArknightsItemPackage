local Widget = require "widgets/widget"
local Badge = require "widgets/badge"
local UIAnim = require "widgets/uianim"
local Text = require "widgets/text"
local Image = require "widgets/image"
local common = require "ark_common"

local function addCurrency(widget, iconAtlas, iconImg)
    local currency = widget:AddChild(Widget("currency"))
    currency.icon = currency:AddChild(Image(iconAtlas, iconImg))
    currency.icon:SetPosition(-80, 0, 0)
    currency.text = currency:AddChild(Text(BODYTEXTFONT, 30))
    currency.text:SetPosition(0, 0, 0)
    currency.text:SetString("0")
    currency.bg = currency:AddChild(Image("images/ui.xml", "blank.tex"))
    currency.bg:SetSize(160, 50)
    return currency
end

local UIArkCurrency = Class(Widget, function(self, owner)
    Widget._ctor(self, "ArkCurrencyUi")
    self.owner = owner
    self.bg = self:AddChild(Image("images/ark_ui/ark_currency_bg.xml", "ark_currency_bg.tex"))
   
    self.gold = addCurrency(self, "images/ark_ui/icon_gold.xml", "icon_gold.tex")
    self.gold.bg:SetHoverText(common.getCommonI18n("ark_currency_gold"))
    self.gold:SetPosition(-160, 0, 0)

    self.diamondShd = addCurrency(self, "images/ark_ui/icon_diamond_shd.xml", "icon_diamond_shd.tex")
    self.diamondShd:SetPosition(0, 0, 0)
    self.diamondShd.bg:SetHoverText(common.getCommonI18n("ark_currency_diamond_shd"))

    self.diamond = addCurrency(self, "images/ark_ui/icon_diamond.xml", "icon_diamond.tex")
    self.diamond:SetPosition(160, 0, 0)
    self.diamond.bg:SetHoverText(common.getCommonI18n("ark_currency_diamond"))

end)

function UIArkCurrency:Refresh()
    self.gold.text:SetString(tostring(self.owner.replica.ark_currency:GetArkGold()))
    self.diamondShd.text:SetString(tostring(self.owner.replica.ark_currency:GetArkDiamondShd()))
    self.diamond.text:SetString(tostring(self.owner.replica.ark_currency:GetArkDiamond()))
end
return UIArkCurrency
