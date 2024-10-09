local UIArkCurrency = require("widgets/ui_ark_currency")

table.insert(Assets, Asset("ATLAS", "images/ark_ui/ark_currency_bg.xml"))
table.insert(Assets, Asset("ATLAS", "images/ark_ui/ark_currency_gold_icon.xml"))

local PADDING = 4;
local RIGHT_PADDING = 200;

local screenSize = nil
local cacheUiW = nil
local cacheUiH = nil
local function positionCurrencyUI(controls)
    local curScreenSize = {TheSim:GetScreenSize()}
    if screenSize and screenSize[1] == curScreenSize[1] and screenSize[2] == curScreenSize[2] then
        return
    end
    screenSize = curScreenSize
    local hudScale = controls.top_root:GetScale()
    local screenW = curScreenSize[1] / hudScale.x
    local screenH = curScreenSize[2] / hudScale.y
    if not cacheUiW or not cacheUiH then
        local originUiW, originUiH = controls.owner.arkCurrency.bg:GetSize()
        local scale = controls.owner.arkCurrency.bg:GetScale()
        cacheUiW = originUiW * scale.x
        cacheUiH = originUiH * scale.y
    end
    local positionX = screenW / 2 - RIGHT_PADDING - cacheUiW / 2 - PADDING
    local positionY = - cacheUiH / 2 - PADDING
    controls.owner.arkCurrency:SetPosition(positionX, positionY, 0)
    local miniMap = controls.minimap_small
    if miniMap then
        local x, y, z = miniMap:GetPosition():Get()
        local mapH = miniMap.mapsize.h
        local mapW = miniMap.mapsize.w
        local maxMapY = - cacheUiH - 2 * PADDING - mapH / 2
        local minMapX = positionX - cacheUiW / 2 - PADDING - mapW / 2
        local maxMapX = positionX + cacheUiW / 2 + PADDING + mapW / 2
        if maxMapY < y and minMapX < x and maxMapX > x then
            miniMap:SetPosition(x, maxMapY, z)
        end
    end
end

AddClassPostConstruct("widgets/controls", function(controls)
    print('AddClassPostConstruct--------------------------------')
    controls.inst:DoTaskInTime(.1, function()
        local arkCurrency = controls.top_root:AddChild(UIArkCurrency(controls.owner))
        controls.owner.arkCurrency = arkCurrency
        positionCurrencyUI(controls)
        local _OnUpdate = controls.OnUpdate
        controls.OnUpdate = function(self, dt, ...)
            local returnValues = {_OnUpdate(self, dt, ...)}
            positionCurrencyUI(self)
            return unpack(returnValues)
        end
        SendModRPCToServer(GetModRPC("ark_item", "ark_currency_sync"))
    end)
end)
