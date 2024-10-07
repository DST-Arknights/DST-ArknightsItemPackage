local UIArkCurrency = require("widgets/ui_ark_currency")

AddClassPostConstruct("widgets/controls", function(controls)
    controls.inst:DoTaskInTime(.2, function()
        local padding = 20;
        local rightPadding = 400;
        local arkCurrency = controls.top_root:AddChild(UIArkCurrency(controls.owner))
        controls.owner.arkCurrency = arkCurrency
        local hudscale = controls.top_root:GetScale()
        local screenw_full, screenh_full = TheSim:GetScreenSize()

        local ui_w, ui_h = arkCurrency.bg:GetSize()
        local positionX = (screenw_full/2 - ui_w + 2 * padding - rightPadding) / hudscale.x
        local positionY = - (ui_h / 2 + padding) / hudscale.y
        arkCurrency:SetPosition(positionX, positionY, 0)
        print('龙门币 positionx', positionX, positionY)
        local miniMap = controls.minimap_small
        if miniMap then
            local x, y, z = miniMap:GetPosition():Get()
            local map_h = miniMap.mapsize.h
            local maxMapY = - (ui_h + 2* padding + map_h / 2)/ hudscale.y
            if  maxMapY < y then
                -- 往下移动点
                miniMap:SetPosition(
                    x,
                    maxMapY,
                    z
                )
            end
        end
        SendModRPCToServer(GetModRPC("ark_item", "ark_currency_sync"))
    end)
end)
