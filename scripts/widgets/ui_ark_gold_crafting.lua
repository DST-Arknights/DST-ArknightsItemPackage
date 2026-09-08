-- 制作栏货币显示 Widget
-- 上下结构：图标在上，数字在下，hover 显示千分位完整数字

local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"

-- 简短格式（正常显示）：<10000 原样，>=10000 用 k/m
local function FormatShort(amount)
    if amount < 10000 then
        return tostring(amount)
    elseif amount < 1000000 then
        return string.format("%.1fk", amount / 1000)
    else
        return string.format("%.1fm", amount / 1000000)
    end
end

-- 千分位逗号格式化（hover 展示）
local function FormatFull(amount)
    local s = tostring(amount)
    return s:reverse():gsub("(%d%d%d)", "%1,"):gsub(",$", ""):reverse()
end

local function AddCurrency(widget, x, icon)
    local currency = widget:AddChild(Widget("currency"))
    currency:SetPosition(x, 0, 0)

    currency.icon = currency:AddChild(Image("images/ark_item_ui.xml", icon))
    currency.icon:SetScale(0.45, 0.45)
    currency.icon:SetPosition(0, 8, 0)

    currency.text = currency:AddChild(Text(NUMBERFONT, 18))
    currency.text:SetPosition(0, -12, 0)
    currency.text:SetString("0")
    currency.text:SetVAlign(ANCHOR_MIDDLE)

    return currency
end

local function RefreshCurrency(currency, amount, name)
    local full_str = name .. ": " .. FormatFull(amount)
    currency.text:SetString(FormatShort(amount))
    currency:SetHoverText(full_str, { offset_y = 40 })
    currency.icon:SetHoverText(full_str, { offset_y = 40 })
end

local UIArkGoldCrafting = Class(Widget, function(self, owner, spacing)
    Widget._ctor(self, "UIArkGoldCrafting")
    self.owner = owner

    self.diamond_shd = AddCurrency(self, -spacing / 2, "icon_diamond_shd.tex")
    self.gold = AddCurrency(self, spacing / 2, "icon_gold.tex")

    -- 初始刷新 & 监听轻量货币变动事件
    self.owner:DoTaskInTime(0, function()
        self:Refresh()
    end)
    self.owner:ListenForEvent("ark_currency_changed", function()
        self:Refresh()
    end)
end)

function UIArkGoldCrafting:Refresh()
    local diamond_shd = 0
    local gold = 0
    if self.owner
        and self.owner.replica
        and self.owner.replica.ark_currency
    then
        diamond_shd = self.owner.replica.ark_currency:GetArkDiamondShd()
        gold = self.owner.replica.ark_currency:GetArkGold()
    end

    RefreshCurrency(self.diamond_shd, diamond_shd, STRINGS.NAMES.ARK_DIAMOND_SHD)
    RefreshCurrency(self.gold, gold, STRINGS.NAMES.ARK_GOLD)
end

return UIArkGoldCrafting
