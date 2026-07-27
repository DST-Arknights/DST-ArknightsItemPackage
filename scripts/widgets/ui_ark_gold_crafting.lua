-- 制作栏金币显示 Widget
-- 上下结构：图标在上，数字在下，hover 显示千分位完整数字

local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"

-- 简短格式（正常显示）：<10000 原样，>=10000 用 k/m
local function FormatGoldShort(amount)
    if amount < 10000 then
        return tostring(amount)
    elseif amount < 1000000 then
        return string.format("%.1fk", amount / 1000)
    else
        return string.format("%.1fm", amount / 1000000)
    end
end

-- 千分位逗号格式化（hover 展示）
local function FormatGoldFull(amount)
    local s = tostring(amount)
    return s:reverse():gsub("(%d%d%d)", "%1,"):gsub(",$", ""):reverse()
end

local UIArkGoldCrafting = Class(Widget, function(self, owner)
    Widget._ctor(self, "UIArkGoldCrafting")
    self.owner = owner

    -- 金币图标（上方，居中）
    self.icon = self:AddChild(Image("images/ark_item_ui.xml", "icon_gold.tex"))
    self.icon:SetScale(0.45, 0.45)
    self.icon:SetPosition(0, 8, 0)

    -- 金币数量（下方，居中）
    self.text = self:AddChild(Text(NUMBERFONT, 18))
    self.text:SetPosition(0, -12, 0)
    self.text:SetString("0")
    self.text:SetVAlign(ANCHOR_MIDDLE)

    -- 初始刷新 & 监听轻量货币变动事件
    self.owner:DoTaskInTime(0, function()
        self:Refresh()
    end)
    self.owner:ListenForEvent("ark_currency_changed", function()
        self:Refresh()
    end)
end)

function UIArkGoldCrafting:Refresh()
    local amount = 0
    if self.owner
        and self.owner.replica
        and self.owner.replica.ark_currency
    then
        amount = self.owner.replica.ark_currency:GetArkGold()
    end
    local full_str = STRINGS.NAMES.ARK_GOLD .. ": " .. FormatGoldFull(amount)
    self.text:SetString(FormatGoldShort(amount))
    self:SetHoverText(full_str, { offset_y = 40 })
    self.icon:SetHoverText(full_str, { offset_y = 40 })
end

return UIArkGoldCrafting
