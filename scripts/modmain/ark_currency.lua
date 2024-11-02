local utils = require("ark_utils")

local arkCurrencyData = {}
local defaultUserCurrencyData = {
  ark_gold = 0, -- 龙门币
  ark_diamond_shd = 0, -- 合成玉
  ark_diamond = 0, -- 源石
  ark_exgg_shd = 0, -- 红票
  ark_hgg_shd = 0, -- 黄票
  ark_lgg_shd = 0, -- 绿票
}

local function OnSave()
  -- 只有主机才保存
  if not TheWorld.ismastersim then
    return
  end
  local json_data = json.encode(arkCurrencyData)
  TheSim:SetPersistentString("ark_currency_data", json_data, false,
    function() print("Save Ark Currency Data Successfully!") end)
end

local function OnLoad()
  -- 只有主机才加载
  if not TheWorld.ismastersim then
    return
  end
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
  local oldGold = inst:GetArkGold()
  inst:SetArkGold(oldGold + gold)
end

local function genGetArkCurrencyPartial(currencyType)
  return function(self)
    return self:GetArkCurrency()[currencyType] or 0
  end
end

local function genSetArkCurrencyPartial(currencyType)
  return function(self, value)
    self:SetArkCurrency({
      [currencyType] = value
    })
  end
end

local function addArkCurrency(inst, currencyType, value)
  local old = inst:GetArkCurrency()[currencyType] or 0
  inst:SetArkCurrency({
    [currencyType] = old + value
  })
end

local function genAddArkCurrencyPartial(currencyType)
  return function(self, value)
    addArkCurrency(self, currencyType, value)
  end
end


AddPlayerPostInit(function(self)
  self:AddTag('ark_currency_user')
  function self:GetArkCurrency()
    if not arkCurrencyData[self.userid] then
      arkCurrencyData[self.userid] = utils.cloneTable(defaultUserCurrencyData)
    end
    return arkCurrencyData[self.userid]
  end
  function self:SetArkCurrency(currency)
    local result = utils.mergeTable(self:GetArkCurrency(), currency)
    SendModRPCToClient(GetClientModRPC('ark_item', "ark_currency_dirty"), self.userid, json.encode(result))
    self:PushEvent("refreshcrafting")
  end
  self.GetArkGold = genGetArkCurrencyPartial("ark_gold")
  self.SetArkGold = genSetArkCurrencyPartial("ark_gold")
  self.AddArkGold = genAddArkCurrencyPartial("ark_gold")
  self.GetArkDiamondShd = genGetArkCurrencyPartial("ark_diamond_shd")
  self.SetArkDiamondShd = genSetArkCurrencyPartial("ark_diamond_shd")
  self.AddArkDiamondShd = genAddArkCurrencyPartial("ark_diamond_shd")
  self.GetArkDiamond = genGetArkCurrencyPartial("ark_diamond")
  self.SetArkDiamond = genSetArkCurrencyPartial("ark_diamond")
  self.AddArkDiamond = genAddArkCurrencyPartial("ark_diamond")
  self.GetArkExggShd = genGetArkCurrencyPartial("ark_exgg_shd")
  self.SetArkExggShd = genSetArkCurrencyPartial("ark_exgg_shd")
  self.AddArkExggShd = genAddArkCurrencyPartial("ark_exgg_shd")
  self.GetArkHggShd = genGetArkCurrencyPartial("ark_hgg_shd")
  self.SetArkHggShd = genSetArkCurrencyPartial("ark_hgg_shd")
  self.AddArkHggShd = genAddArkCurrencyPartial("ark_hgg_shd")
  self.AddArkCurrency = addArkCurrency
  self:ListenForEvent("killed", OnKilled)
end)

AddClientModRPCHandler("ark_item", "ark_currency_dirty", function(dataStr)
  local data = json.decode(dataStr)
  if not TheWorld.ismastersim then
    arkCurrencyData[ThePlayer.userid] = data
  end
  ThePlayer.HUD.controls.arkCurrency:SetArkCurrency(data)
end)

-- 用于服务端监听同步金币的 RPC 消息
AddModRPCHandler("ark_item", "ark_currency_sync", function(player)
  SendModRPCToClient(GetClientModRPC('ark_item', "ark_currency_dirty"), player.userid, json.encode(player:GetArkCurrency()))
end)

AddComponentPostInit("inventory", function(self)
  local _Has = self.Has
  self.Has = function(self, item, amount, ...)
    for k, _ in pairs(defaultUserCurrencyData) do
      if item == k then
        local left = self.inst:GetArkCurrency();
        local leftGold = left[k] or 0
        return leftGold >= amount, leftGold
      end
    end
    return _Has(self, item, amount, ...)
  end
end)

AddComponentPostInit("builder", function(self)
  local _RemoveIngredients = self.RemoveIngredients
  self.RemoveIngredients = function(self, ingredients, recname, ...)
    local recipe = AllRecipes[recname]
    if recipe then
      for k, v in pairs(recipe.ingredients) do
        for currencyType, _ in pairs(defaultUserCurrencyData) do
          if v.type == currencyType then
            local amt = math.max(1, RoundBiasedUp(v.amount * self.ingredientmod))
            if self.inst.SetArkCurrency then
              self.inst:SetArkCurrency({
                [currencyType] = self.inst:GetArkCurrency()[currencyType] - amt
              })
            end
          end
        end
      end
    end
    return _RemoveIngredients(self, ingredients, recname, ...)
  end
end)

AddClassPostConstruct('components/inventory_replica' , function(self)
  local _Has = self.Has
  self.Has = function(self, item, amount, ...)
    for k, _ in pairs(defaultUserCurrencyData) do
      if item == k then
        local left = self.inst:GetArkCurrency();
        local leftGold = left[k] or 0
        return leftGold >= amount, leftGold
      end
    end
    return _Has(self, item, amount, ...)
  end
end)

-- 使用货币
AddAction("USE_ARK_CURRENCY", STRINGS.ACTIONS.USE_ARK_CURRENCY.GENERIC, function(act)
  print('USE_ARK_CURRENCY', act)
  local target = act.target or act.invobject
  if target.components.ark_currency then
    return target.components.ark_currency:CanUse(act.doer)
  end
end)

AddComponentAction('INVENTORY', 'ark_currency', function(inst, doer, actions, right)
  if inst.components.ark_currency then
    table.insert(actions, ACTIONS.USE_ARK_CURRENCY)
  end
end)

AddStategraphActionHandler("wilson",ActionHandler(ACTIONS.USE_ARK_CURRENCY, 'useArkCurrency'))
AddStategraphActionHandler("wilson_client",ActionHandler(ACTIONS.USE_ARK_CURRENCY,'useArkCurrency'))

local useArkCurrencyState = State{
  name = "useArkCurrency",
  onenter = function(inst, data)
    local action = inst:GetBufferedAction()
    -- 是否在主世界
		if action ~= nil and not TheWorld.ismastersim then
			inst:PerformPreviewBufferedAction()
		end
    inst.components.locomotor:Stop()
    inst.AnimState:PlayAnimation("give")
  end,
  timeline = {
    TimeEvent(10 * FRAMES, function(inst)
      if not TheWorld.ismastersim then
        return
      end
      local action = inst:GetBufferedAction()
      local target = action.target or action.invobject
      local prices = target.components.ark_currency:GetAllPrices()
      for _, v in pairs(prices) do
        print('useArkCurrency', v, v.currencyType, v.value)
        inst:AddArkCurrency(v.currencyType, v.value)
      end
      -- target 消耗一个
      target.components.stackable:Get():Remove()
      -- test
      inst:ClearBufferedAction()
      local action2 = inst:GetBufferedAction()
      print('sg time event 2', action2) 
    end),
  },
  events = {
    EventHandler("animover", function(inst)
      print('触发了 animover')
      inst.sg:GoToState("idle")
    end),
  }
}

AddStategraphState("wilson", useArkCurrencyState)
AddStategraphState("wilson_client", useArkCurrencyState)