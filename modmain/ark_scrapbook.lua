local GLOBAL = GLOBAL
local require = GLOBAL.require

local Widget = require("widgets/widget")
local Text = require("widgets/text")
local Image = require("widgets/image")
local ImageButton = require("widgets/imagebutton")
local UIAnim = require("widgets/uianim")

local PANEL_HEIGHT = 530
local BUTTON_W = 252 / 2.2
local BUTTON_H = 112 / 2.2
local BUTTON_X = 522 + BUTTON_W / 2

local CUSTOM_CATEGORIES = {
    {
        filter = "akr_item",              -- dataset[i].type 要对应这个
        name_key = "ARK_ITEM",            -- STRINGS.SCRAPBOOK.CATS[name_key]
        display = "Arknights Items",            -- 没有 strings 时兜底显示
        color = { 0.45, 0.35, 0.60 },  -- 按钮底色
    },
}

local function EnsureCategory(filter)
    for _, v in ipairs(GLOBAL.SCRAPBOOK_CATS) do
        if v == filter then
            return
        end
    end
    table.insert(GLOBAL.SCRAPBOOK_CATS, filter)
end

local function EnsureCategoryString(name_key, display)
    GLOBAL.STRINGS.SCRAPBOOK = GLOBAL.STRINGS.SCRAPBOOK or {}
    GLOBAL.STRINGS.SCRAPBOOK.CATS = GLOBAL.STRINGS.SCRAPBOOK.CATS or {}
    if GLOBAL.STRINGS.SCRAPBOOK.CATS[name_key] == nil then
        GLOBAL.STRINGS.SCRAPBOOK.CATS[name_key] = display
    end
end

local function CountCategoryProgress(dataset, filter)
    local total, count = 0, 0
    for _, data in pairs(dataset) do
        if data.type == filter then
            total = total + 1
            if (data.knownlevel or 0) > 0 then
                count = count + 1
            end
        end
    end
    return count, total
end

local function CreateCategoryButton(self, data)
    local buttonwidget = self.root:AddChild(Widget("mod_scrapbook_tab_" .. data.filter))

    local button = buttonwidget:AddChild(ImageButton("images/scrapbook.xml", "tab.tex"))
    button:ForceImageSize(BUTTON_W, BUTTON_H)
    button.scale_on_focus = false
    button.basecolor = { data.color[1], data.color[2], data.color[3] }
    button:SetImageFocusColour(math.min(1, data.color[1] * 1.2), math.min(1, data.color[2] * 1.2), math.min(1, data.color[3] * 1.2), 1)
    button:SetImageNormalColour(data.color[1], data.color[2], data.color[3], 1)
    button:SetImageSelectedColour(data.color[1], data.color[2], data.color[3], 1)
    button:SetImageDisabledColour(data.color[1], data.color[2], data.color[3], 1)
    button:SetOnClick(function()
        self:SelectSideButton(data.filter)
        self.current_dataset = self:CollectType(self._mod_dataset, data.filter)
        self.current_view_data = self:CollectType(self._mod_dataset, data.filter)
        self:SetGrid()
    end)

    buttonwidget.focusimg = button:AddChild(Image("images/scrapbook.xml", "tab_over.tex"))
    buttonwidget.focusimg:ScaleToSize(BUTTON_W, BUTTON_H)
    buttonwidget.focusimg:SetClickable(false)
    buttonwidget.focusimg:Hide()

    buttonwidget.selectimg = button:AddChild(Image("images/scrapbook.xml", "tab_selected.tex"))
    buttonwidget.selectimg:ScaleToSize(BUTTON_W, BUTTON_H)
    buttonwidget.selectimg:SetClickable(false)
    buttonwidget.selectimg:Hide()

    buttonwidget:SetOnGainFocus(function() buttonwidget.focusimg:Show() end)
    buttonwidget:SetOnLoseFocus(function() buttonwidget.focusimg:Hide() end)

    local label = GLOBAL.STRINGS.SCRAPBOOK.CATS[data.name_key] or data.display
    local text = button:AddChild(Text(GLOBAL.HEADERFONT, 12, label, GLOBAL.UICOLOURS.WHITE))
    text:SetPosition(10, -8)

    local known, total = CountCategoryProgress(self._mod_dataset, data.filter)
    if total > 0 then
        local percent = (known / total) * 100
        percent = percent < 1 and (math.floor(percent * 100) / 100) or math.floor(percent)
        local progress = buttonwidget:AddChild(Text(GLOBAL.HEADERFONT, 18, tostring(percent) .. "%", GLOBAL.UICOLOURS.GOLD))
        progress:SetPosition(15, 17)
    end

    buttonwidget.newcreatures = {}

    buttonwidget.flash = buttonwidget:AddChild(UIAnim())
    buttonwidget.flash:GetAnimState():SetBank("cookbook_newrecipe")
    buttonwidget.flash:GetAnimState():SetBuild("cookbook_newrecipe")
    buttonwidget.flash:GetAnimState():PlayAnimation("anim", true)
    buttonwidget.flash:GetAnimState():SetDeltaTimeMultiplier(1.25)
    buttonwidget.flash:SetScale(.8, .8, .8)
    buttonwidget.flash:SetPosition(40, 0, 0)
    buttonwidget.flash:Hide()
    buttonwidget.flash:SetClickable(false)

    buttonwidget.filter = data.filter
    buttonwidget.focus_forward = button

    return buttonwidget
end

local function RelayoutSideBar(self)
    local total = #self.menubuttons
    if total <= 0 then
        return
    end

    local totalheight = PANEL_HEIGHT - 100
    local step = totalheight / (total + 1)

    for i, w in ipairs(self.menubuttons) do
        local y = totalheight / 2 - ((step * i) - 1) + 50
        w:SetPosition(BUTTON_X, y)
    end
end

AddClassPostConstruct("screens/redux/scrapbookscreen", function(self)
    self._mod_dataset = require("screens/redux/scrapbookdata")

    local oldMakeSideBar = self.MakeSideBar
    self.MakeSideBar = function(screen_self)
        oldMakeSideBar(screen_self)

        local exists = {}
        for _, w in ipairs(screen_self.menubuttons) do
            exists[w.filter] = true
        end

        for _, cat in ipairs(CUSTOM_CATEGORIES) do
            EnsureCategory(cat.filter)
            EnsureCategoryString(cat.name_key, cat.display)

            if not exists[cat.filter] then
                table.insert(screen_self.menubuttons, CreateCategoryButton(screen_self, cat))
                exists[cat.filter] = true
            end
        end

        RelayoutSideBar(screen_self)
    end
end)