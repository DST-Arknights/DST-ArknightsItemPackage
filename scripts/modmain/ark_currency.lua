local utils = require("ark_utils")

TUNING.ARK_CURRENCY_TYPES = {"ark_gold", "ark_diamond_shd", "ark_diamond", "ark_exgg_shd", "ark_hgg_shd", "ark_lgg_shd"}

AddPrefabPostInit("world", function(inst)
  if TheNet:GetIsServer() then
    inst:AddComponent("ark_currency_data")
  end
end)

AddPlayerPostInit(function(self)
  if TheWorld.ismastersim then
    self:AddComponent("ark_currency")
    self:ListenForEvent("killed", function(inst, data)
      if not inst:HasTag("player") then
        return
      end
      local target = data.victim
      if not target then
        return
      end
      if not inst.components.ark_currency then
        return
      end
      -- 获取目标血量, 指定用户增加被击杀生物的最大血量数量的金币
      local health = target.components.health.maxhealth
      local gold = math.floor(health / 1)
      inst.components.ark_currency:AddArkGold(gold)
    end)
  end
  self:AddTag('ark_currency_user')
end)

AddComponentPostInit("inventory", function(self)
  local _Has = self.Has
  self.Has = function(self, item, amount, ...)
    for _, type in pairs(TUNING.ARK_CURRENCY_TYPES) do
      if item == type then
        local left = self.components.ark_currency:GetArkCurrencyByType(type)
        return left >= amount, left
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
        for _, currencyType in pairs(TUNING.ARK_CURRENCY_TYPES) do
          if v.type == currencyType then
            local amt = math.max(1, RoundBiasedUp(v.amount * self.ingredientmod))
            self.inst.components.ark_currency:AddArkCurrencyByType(currencyType, -amt)
          end
        end
      end
    end
    return _RemoveIngredients(self, ingredients, recname, ...)
  end
end)

AddClassPostConstruct('components/inventory_replica', function(self)
  local _Has = self.Has
  self.Has = function(self, item, amount, ...)
    for _, type in pairs(TUNING.ARK_CURRENCY_TYPES) do
      if item == type then
        local left = self.inst.replica.ark_currency:GetArkCurrencyByType(type)
        return left >= amount, left
      end
    end
    return _Has(self, item, amount, ...)
  end
end)

-- 使用货币
AddAction("USE_ARK_CURRENCY", STRINGS.ACTIONS.USE_ARK_CURRENCY.GENERIC, function(act)
  print('USE_ARK_CURRENCY', act)
  local target = act.target or act.invobject
  if target.components.ark_currency_item then
    return target.components.ark_currency_item:CanUse(act.doer)
  end
end)

AddComponentAction('INVENTORY', 'ark_currency_item', function(inst, doer, actions, right)
  if inst.components.ark_currency_item then
    table.insert(actions, ACTIONS.USE_ARK_CURRENCY)
  end
end)

AddStategraphActionHandler("wilson", ActionHandler(ACTIONS.USE_ARK_CURRENCY, 'useArkCurrency'))
AddStategraphActionHandler("wilson_client", ActionHandler(ACTIONS.USE_ARK_CURRENCY, 'useArkCurrency'))

local useArkCurrencyState = State {
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
  timeline = {TimeEvent(10 * FRAMES, function(inst)
    if not TheWorld.ismastersim then
      return
    end
    local action = inst:GetBufferedAction()
    local target = action.target or action.invobject
    local prices = target.components.ark_currency_item:GetAllPrices()
    for _, v in pairs(prices) do
      print('useArkCurrency', v, v.currencyType, v.value)
      inst.components.ark_currency:AddArkCurrencyByType(v.currencyType, v.value)
    end
    -- target 消耗一个
    target.components.stackable:Get():Remove()
    inst:ClearBufferedAction()
  end)},
  events = {EventHandler("animover", function(inst) inst.sg:GoToState("idle") end)}
}

AddStategraphState("wilson", useArkCurrencyState)
AddStategraphState("wilson_client", useArkCurrencyState)
