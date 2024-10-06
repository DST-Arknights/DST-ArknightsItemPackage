local utils = require("ark_utils")

local arkCurrnencyData
local defaultUserCurrnencyDdata = {
    gold = 0
}

local function getUserCurrencyData(userid)
    if not arkCurrnencyData[userid] then
        arkCurrnencyData[userid] = defaultUserCurrnencyDdata
    end
    return arkCurrnencyData[userid]
end
local function setUserCurrencyData(userid, data)
    arkCurrnencyData[userid] = data
end

local function OnSave()
    local json_data = json.encode(arkCurrnencyData)
    TheSim:SetPersistentString("ark_currnency_data", json_data, false, function()
        print("Save Ark Currency Data Successfully!")
    end)
end

local function OnLoad()
    TheSim:GetPersistentString("ark_currnency_data", function(load_success, data)
        if load_success and data ~= nil then
            local status, saved_data = pcall(function()
                return json.decode(data)
            end)
            if status and saved_data then
                arkCurrnencyData = saved_data
                print("Load Ark Currency Data Successfully!")
                return
            end
        end
        arkCurrnencyData = {}
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
    SendModRPCToClient(GetClientModRPC('ark_item', "ark_currency_dirty"), inst.userid, inst, json.encode(userCurrencyData))

end

local function AddKillListener(inst)
    if inst ~= nil and inst:HasTag("player") then
        inst:ListenForEvent("killed", OnKilled)
    end
end

AddPlayerPostInit(AddKillListener)

AddClientModRPCHandler("ark_item", "ark_currency_dirty", function(player, dataStr)
    print("接收到金币变化的消息", player, dataStr)
    local data = json.decode(dataStr)
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
