local UIArkCurrency = require("widgets/ui_ark_currency")

table.insert(Assets, Asset("ATLAS", "images/ark_item_ui.xml"))

local PADDING = 6;
local RIGHT_PADDING = 280;

local screenSize = nil
local function positionCurrencyUI(controls)
    local curScreenSize = {TheSim:GetScreenSize()}
    if screenSize and screenSize[1] == curScreenSize[1] and screenSize[2] == curScreenSize[2] then
        return
    end
    screenSize = curScreenSize
    local hudScale = controls.top_root:GetScale()
    local screenW = curScreenSize[1] / hudScale.x
    local screenH = curScreenSize[2] / hudScale.y

    local originUiW, originUiH = controls.arkCurrency.bg:GetSize()
    local positionX = screenW / 2 - RIGHT_PADDING - originUiW / 2 - PADDING
    local positionY = - originUiH / 2 - PADDING
    controls.arkCurrency:SetPosition(positionX, positionY, 0)
    local miniMap = controls.minimap_small
    if miniMap then
        local x, y, z = miniMap:GetPosition():Get()
        local mapH = miniMap.mapsize.h
        local mapW = miniMap.mapsize.w
        local maxMapY = - originUiH - 2 * PADDING - mapH / 2
        local minMapX = positionX - originUiW / 2 - PADDING - mapW / 2
        local maxMapX = positionX + originUiW / 2 + PADDING + mapW / 2
        if maxMapY < y and minMapX < x and maxMapX > x then
            miniMap:SetPosition(x, maxMapY, z)
        end
    end
end

AddClassPostConstruct("widgets/controls", function(controls)
    controls.inst:DoTaskInTime(.1, function()
        local arkCurrency = controls.top_root:AddChild(UIArkCurrency(controls.owner))
        controls.arkCurrency = arkCurrency
        arkCurrency:Refresh()
        positionCurrencyUI(controls)
        local _OnUpdate = controls.OnUpdate
        controls.OnUpdate = function(self, dt, ...)
            local returnValues = {_OnUpdate(self, dt, ...)}
            positionCurrencyUI(self)
            return unpack(returnValues)
        end
    end)
end)
