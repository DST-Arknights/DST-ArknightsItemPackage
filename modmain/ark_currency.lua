local utils = require("ark_utils")

TUNING.ARK_CURRENCY_TYPES = {"ark_gold", "ark_diamond_shd", "ark_diamond", "ark_exgg_shd", "ark_hgg_shd", "ark_lgg_shd"}

for _, type in pairs(TUNING.ARK_CURRENCY_TYPES) do
  CHARACTER_INGREDIENT[string.upper(type)] = type
end

local _IsCharacterIngredient = GLOBAL.IsCharacterIngredient
local is_ark_currency_ingredient = nil
function GLOBAL.IsCharacterIngredient(ingredient)
  if is_ark_currency_ingredient == nil then
    is_ark_currency_ingredient = {}
    for _, type in pairs(TUNING.ARK_CURRENCY_TYPES) do
      is_ark_currency_ingredient[type] = true
    end
  end
  if ingredient ~= nil and is_ark_currency_ingredient[ingredient] then
    return true
  end
  return _IsCharacterIngredient(ingredient)
end

AddPrefabPostInit("world", function(inst)
  if TheNet:GetIsServer() then
    inst:AddComponent("ark_currency_data")
  end
end)

AddComponentPostInit("builder", function(self)
  local _HasCharacterIngredient = self.HasCharacterIngredient
  function self:HasCharacterIngredient(ingredient)
    if self.inst.components.ark_currency ~= nil then
      if is_ark_currency_ingredient[ingredient.type] then
        local has = self.inst.components.ark_currency:GetArkCurrencyByType(ingredient.type)
        if has ~= nil and has >= ingredient.amount then
          return true, has
        else
          return false, 0
        end
      end
    end
    return _HasCharacterIngredient(self, ingredient)
  end
  local _RemoveIngredients = self.RemoveIngredients
  self.RemoveIngredients = function(self, ingredients, recname, discounted)
    if self.freebuildmode then
      return
    end
    if self.inst.components.ark_currency ~= nil then
      local recipe = AllRecipes[recname]
      if recipe then
        for _, v in pairs(recipe.character_ingredients) do
          if is_ark_currency_ingredient[v.type] then
            self.inst.components.ark_currency:AddArkCurrencyByType(v.type, -v.amount)
          end
        end
      end
    end
    return _RemoveIngredients(self, ingredients, recname, discounted)
  end
end)

AddClassPostConstruct('components/builder_replica', function(self)
  local _HasCharacterIngredient = self.HasCharacterIngredient
  self.HasCharacterIngredient = function(self, ingredient, ...)
    if self.inst.replica.ark_currency ~= nil then
      if is_ark_currency_ingredient[ingredient.type] then
        local has = self.inst.replica.ark_currency:GetArkCurrencyByType(ingredient.type)
        if has ~= nil and has >= ingredient.amount then
          return true, has
        else
          return false, 0
        end
      end
    end
    return _HasCharacterIngredient(self, ingredient, ...)
  end
end)

-- 使用货币
AddAction("USE_ARK_CURRENCY", STRINGS.ACTIONS.USE_ARK_CURRENCY.GENERIC, function(act)
  local target = act.target or act.invobject
  if target.components.ark_currency_item and act.doer.components.ark_currency then
    local prices = target.components.ark_currency_item:GetAllPrices()
    for _, v in pairs(prices) do
      act.doer.components.ark_currency:AddArkCurrencyByType(v.currencyType, v.value)
    end
    target.components.stackable:Get():Remove()
    return true
  end
  return false
end)

AddComponentAction('INVENTORY', 'ark_currency_item', function(inst, doer, actions, right)
  table.insert(actions, ACTIONS.USE_ARK_CURRENCY)
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
    inst:PerformBufferedAction()
  end)},
  events = {EventHandler("animover", function(inst) inst.sg:GoToState("idle") end)}
}

AddStategraphState("wilson", useArkCurrencyState)
AddStategraphState("wilson_client", useArkCurrencyState)

-- 货币系统ui
table.insert(Assets, Asset("ATLAS", "images/ark_item_ui.xml"))
