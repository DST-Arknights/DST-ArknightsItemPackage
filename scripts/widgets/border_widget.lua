local Widget = require "widgets/widget"
local Image = require "widgets/image"

local function ResolveColor(defaultColor, ...)
    local first = ...
    if type(first) == "table" then
        return {
            first[1] or defaultColor[1],
            first[2] or defaultColor[2],
            first[3] or defaultColor[3],
            first[4] or defaultColor[4],
        }
    end

    local r, g, b, a = ...
    return {
        r or defaultColor[1],
        g or defaultColor[2],
        b or defaultColor[3],
        a or defaultColor[4],
    }
end

local function ResolveSize(width, height, defaultWidth, defaultHeight)
    if type(width) == "table" then
        local size = width
        if size.x ~= nil and size.y ~= nil then
            return size.x, size.y
        end
        return size[1] or defaultWidth or 0, size[2] or defaultHeight or 0
    end

    return width or defaultWidth or 0, height or defaultHeight or 0
end

local BorderWidget = Class(Widget, function(self, width, height, options)
    Widget._ctor(self, "ArkInsetPanel")

    options = options or {}
    self.width, self.height = ResolveSize(width, height, 0, 0)
    self.borderWidth = math.max(0, options.borderWidth or 0)
    self.backgroundColor = ResolveColor({ 0, 0, 0, 0.5 }, options.backgroundColor)
    self.borderColor = ResolveColor({ 0.23, 0.23, 0.23, 1 }, options.borderColor)
    self.showBorder = options.showBorder ~= false

    self.borderImage = self:AddChild(Image("images/ui.xml", "white.tex"))
    self.innerImage = self:AddChild(Image("images/ui.xml", "white.tex"))

    self:_Refresh()
end)

function BorderWidget:_Refresh()
    self.borderImage:SetSize(self.width, self.height)
    self.borderImage:SetTint(unpack(self.borderColor))

    local innerWidth = self.width
    local innerHeight = self.height
    if self.showBorder and self.borderWidth > 0 then
        innerWidth = math.max(0, self.width - self.borderWidth * 2)
        innerHeight = math.max(0, self.height - self.borderWidth * 2)
    end

    self.innerImage:SetSize(innerWidth, innerHeight)
    self.innerImage:SetTint(unpack(self.backgroundColor))

    if self.showBorder and self.borderWidth > 0 then
        self.borderImage:Show()
    else
        self.borderImage:Hide()
    end
end

function BorderWidget:SetSize(width, height)
    self.width, self.height = ResolveSize(width, height, self.width, self.height)
    self:_Refresh()
end

function BorderWidget:SetBackgroundColor(...)
    self.backgroundColor = ResolveColor(self.backgroundColor, ...)
    self:_Refresh()
end

function BorderWidget:SetBorderColor(...)
    self.borderColor = ResolveColor(self.borderColor, ...)
    self:_Refresh()
end

function BorderWidget:SetBorderWidth(width)
    self.borderWidth = math.max(0, width or 0)
    self:_Refresh()
end

function BorderWidget:SetBorderEnabled(enabled)
    self.showBorder = enabled == true
    self:_Refresh()
end

function BorderWidget:GetSize()
    return self.width, self.height
end

return BorderWidget