local UIArkCurrency = require("widgets/ui_ark_currency")

table.insert(Assets, Asset("ATLAS", "images/ark_item_ui.xml"))

local TOP_PADDING = 14;
local RIGHT_PADDING = 240;

AddClassPostConstruct("widgets/controls", function(controls)
    local arkCurrency = controls.topright_root:AddChild(UIArkCurrency(controls.owner))
    controls.arkCurrency = arkCurrency
    local originUiW, originUiH = arkCurrency.bg:GetSize()
    arkCurrency:SetPosition(-originUiW / 2 - RIGHT_PADDING, -originUiH / 2 - TOP_PADDING, 0)
    -- 如果有小地图, 要重置小地图的位置, 以及修改小地图定位方法. 把它往下移动一点.
    -- 移动的不多, 所以不用管小地图在哪个位置了, 不然浪费计算
    controls.owner:DoTaskInTime(0.1, function()
        local miniMap = controls.minimap_small
        if not miniMap then
            return
        end
        local nowPosition = miniMap:GetPosition()
        local _SetPosition = miniMap.SetPosition
        local offset_y = - TOP_PADDING - originUiH + 15
        function miniMap:SetPosition(pos, y, z)
            -- 节省性能,地图应该没用过Vector3传参, 等有用到vector3 的时候再解开
            -- if type(pos) == "table" then
            --     pos, y, z = pos.x, pos.y, pos.z
            -- end
            _SetPosition(miniMap, pos, y + offset_y, z)
        end
        miniMap:SetPosition(nowPosition.x, nowPosition.y, nowPosition.z)
    end)
end)
