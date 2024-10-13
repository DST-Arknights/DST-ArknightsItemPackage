local utils = require('ark_utils')
AddComponentPostInit("inventory", function(self)
  local _Has = self.Has
  self.Has = function(self, item, amount, ...)
    if item == "ark_gold" then
      local left = self.inst:GetArkCurrency();
      local leftGold = left.gold or 0
      return leftGold >= amount, leftGold
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
        if v.type == "ark_gold" then
          local amt = math.max(1, RoundBiasedUp(v.amount * self.ingredientmod))
          if self.inst.SetArkCurrency then
            self.inst:SetArkCurrency({
              gold = self.inst:GetArkCurrency().gold - amt
            })
          end
        end
      end
    end
    return _RemoveIngredients(self, ingredients, recname, ...)
  end
end)

local inventory_replica = require('components/inventory_replica')

local _InventoryReplicaHas = inventory_replica.Has

inventory_replica.Has = function(self, item, amount, ...)
  if item == "ark_gold" then
    local left = self.inst:GetArkCurrency();
    local leftGold = left.gold or 0
    return leftGold >= amount, leftGold
  end
  return _InventoryReplicaHas(self, item, amount, ...)
end
