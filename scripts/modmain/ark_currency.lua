local utils = require("ark_utils")

local arkCurrencyData
local defaultUserCurrencyData = {
  gold = 0
}

local function OnSave()
  local json_data = json.encode(arkCurrencyData)
  TheSim:SetPersistentString("ark_currency_data", json_data, false,
    function() print("Save Ark Currency Data Successfully!") end)
end

local function OnLoad()
  TheSim:GetPersistentString("ark_currency_data", function(load_success, data)
    if load_success and data ~= nil then
      local status, saved_data = pcall(function() return json.decode(data) end)
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
  local gold = math.floor(health / 1)
  local userCurrencyData = inst:GetArkCurrency()
  userCurrencyData.gold = userCurrencyData.gold + gold
  inst:SetArkCurrency(userCurrencyData)
end

local function playerPostInit(inst)
  function inst:GetArkCurrency()
    if not arkCurrencyData[inst.userid] then
      arkCurrencyData[inst.userid] = defaultUserCurrencyData
    end
    return arkCurrencyData[inst.userid]
  end
  function inst:SetArkCurrency(currency)
    local result = utils.mergeTable(inst:GetArkCurrency(), currency)
    SendModRPCToClient(GetClientModRPC('ark_item', "ark_currency_dirty"), inst.userid, inst, json.encode(result))
    inst:PushEvent("refreshcrafting")
  end
  if inst ~= nil and inst:HasTag("player") then
    inst:ListenForEvent("killed", OnKilled)
  end
end

AddPlayerPostInit(playerPostInit)

AddClientModRPCHandler("ark_item", "ark_currency_dirty", function(player, dataStr)
  local data = json.decode(dataStr)
  if not TheWorld.ismastersim then
    arkCurrencyData[player.userid] = data
  end
  if player.arkCurrency then
    player.arkCurrency:SetArkCurrency(data)
  end
end)

-- 用于服务端监听同步金币的 RPC 消息
AddModRPCHandler("ark_item", "ark_currency_sync", function(player)
  SendModRPCToClient(GetClientModRPC('ark_item', "ark_currency_dirty"), player.userid, player,
    json.encode(player:GetArkCurrency()))
end)
