local utils = require("ark_utils")

local arkCurrencyData
local defaultUserCurrencyData = {
    gold = 0
}

local function getUserCurrencyData(userid)
    if not arkCurrencyData[userid] then
        arkCurrencyData[userid] = defaultUserCurrencyData
    end
    return arkCurrencyData[userid]
end
local function setUserCurrencyData(userid, data)
    arkCurrencyData[userid] = data
end

local function OnSave()
    local json_data = json.encode(arkCurrencyData)
    TheSim:SetPersistentString("ark_currency_data", json_data, false, function()
        print("Save Ark Currency Data Successfully!")
    end)
end

local function OnLoad()
    TheSim:GetPersistentString("ark_currency_data", function(load_success, data)
        if load_success and data ~= nil then
            local status, saved_data = pcall(function()
                return json.decode(data)
            end)
            if status and saved_data then
                arkCurrencyData = saved_data
                print("Load Ark Currency Data Successfully!")
                return
            end
        end
        arkCurrencyData = {}
        print("Failed to load Ark Currency Data!")
    end)
end

AddSimPostInit(function()
    if TheWorld ~= nil then
        TheWorld:ListenForEvent("ms_save", OnSave)
    end
    -- 在游戏加载时触发 OnLoad 函数
    OnLoad()
end)

local function OnKilled(inst, data)
    if not inst:HasTag("player") then
        return
    end
    local target = data.victim
    if not target then
        return
    end
    -- 获取目标血量, 指定用户增加被击杀生物的最大血量数量的金币
    local health = target.components.health.maxhealth
    print('health', health)
    local gold = math.floor(health / 1)
    local userCurrencyData = getUserCurrencyData(inst.userid)
    userCurrencyData.gold = userCurrencyData.gold + gold
    -- 给指定用户的客户端发送金币变化的消息, sendRPCToClient
    inst:PushEvent("refreshcrafting")
    SendModRPCToClient(GetClientModRPC('ark_item', "ark_currency_dirty"), inst.userid, inst, json.encode(userCurrencyData))

end

local function playerPostInit(inst)
    function inst:GetCurrency()
        return getUserCurrencyData(inst.userid)
    end
    if inst ~= nil and inst:HasTag("player") then
        inst:ListenForEvent("killed", OnKilled)
    end
end

AddPlayerPostInit(playerPostInit)

AddClientModRPCHandler("ark_item", "ark_currency_dirty", function(player, dataStr)
    print("接收到金币变化的消息", player, dataStr)
    local data = json.decode(dataStr)
    if not TheWorld.ismastersim then
        arkCurrencyData[player.userid] = data
    end
    if player.arkCurrency then
        player.arkCurrency:SetCurrency(data)
    end
end)

-- 用于服务端监听同步金币的 RPC 消息
AddModRPCHandler("ark_item", "ark_currency_sync", function(player)
    print("客户端申请同步货币", player)
    SendModRPCToClient(GetClientModRPC('ark_item', "ark_currency_dirty"), player.userid, player,
        json.encode(getUserCurrencyData(player.userid)))
end)
