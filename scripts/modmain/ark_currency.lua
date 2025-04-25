local utils = require("ark_utils")
local UIArkCurrency = require("widgets/ui_ark_currency")

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
        local left = self.inst.components.ark_currency:GetArkCurrencyByType(type)
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
  local target = act.target or act.invobject
  if target.components.ark_currency_item then
    return target.components.ark_currency_item:CanUse(act.doer)
  end
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
    local action = inst:GetBufferedAction()
    local target = action.target or action.invobject
    local prices = target.components.ark_currency_item:GetAllPrices()
    for _, v in pairs(prices) do
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


-- 修改ui样式, 与精神或体力等一致的样式
local IngredientUI = require "widgets/ingredientui"
local _IngredientUI_ctor = IngredientUI._ctor
function IngredientUI:_ctor(atlas, image, quantity, on_hand, has_enough, name, owner, recipe_type, quant_text_scale, ingredient_recipe)
  _IngredientUI_ctor(self, atlas, image, quantity, on_hand, has_enough, name, owner, recipe_type, quant_text_scale, ingredient_recipe)
  if utils.findIndex(TUNING.ARK_CURRENCY_TYPES, recipe_type) then
    self.quant:SetString(string.format("-%d", quantity))
  end
end

-- 货币系统ui
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
