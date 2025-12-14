local Widget = require "widgets/widget"
local Badge = require "widgets/badge"
local Text = require "widgets/text"
local Image = require "widgets/image"
local common = require "ark_common"

local function addCurrency(widget, iconAtlas, iconImg, hoverText)
    local currency = widget:AddChild(Widget("currency"))
    currency.icon = currency:AddChild(Image(iconAtlas, iconImg))
    currency.icon:SetPosition(-80, 4, 0)
    currency.text = currency:AddChild(Text(BODYTEXTFONT, 30))
    currency.text:SetPosition(0, 0, 0)
    currency.text:SetString("0")
    currency.bg = currency:AddChild(Image("images/ui.xml", "blank.tex"))
    currency.bg:SetSize(160, 50)
    currency.bg:SetHoverText(hoverText, { offset_y = -40})
    return currency
end

local UIArkCurrency = Class(Widget, function(self, owner)
    Widget._ctor(self, "ArkCurrencyUi")
    self.owner = owner
    self.bg = self:AddChild(Image("images/ui.xml", "black.tex"))
    self.bg:SetSize(160 * 3, 28)
    self.bg:SetTint(0, 0, 0, 0.5)
   
    self.gold = addCurrency(self, "images/ark_item_ui.xml", "icon_gold.tex", STRINGS.NAMES.ARK_GOLD)
    self.gold:SetPosition(-160, 0, 0)

    self.diamondShd = addCurrency(self, "images/ark_item_ui.xml", "icon_diamond_shd.tex", STRINGS.NAMES.ARK_DIAMOND_SHD)
    self.diamondShd:SetPosition(0, 0, 0)

    self.diamond = addCurrency(self, "images/ark_item_ui.xml", "icon_diamond.tex", STRINGS.NAMES.ARK_DIAMOND)
    self.diamond:SetPosition(160, 0, 0)
    self.owner:DoTaskInTime(0, function()
      self:Refresh()
    end)
end)

function UIArkCurrency:GetSize()
    return self.bg:GetSize()
end

function UIArkCurrency:Refresh()
    self.gold.text:SetString(tostring(self.owner.replica.ark_currency:GetArkGold()))
    self.diamondShd.text:SetString(tostring(self.owner.replica.ark_currency:GetArkDiamondShd()))
    self.diamond.text:SetString(tostring(self.owner.replica.ark_currency:GetArkDiamond()))
end
return UIArkCurrency
