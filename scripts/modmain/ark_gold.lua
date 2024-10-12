AddComponentPostInit("inventory", function(self)
  local _Has = self.Has
  self.Has = function(self, item, amount, checkallcontainers, ...)
    print('has test:', item, amount)
    if item == "ark_gold" then
      print('has ark_gold')
      local left = self.inst:GetCurrency();
      local leftGold = left.gold or 0
      return leftGold >= amount, leftGold
    end
    return _Has(self, item, amount, ...)
  end
end)

local inventory_replica = require('components/inventory_replica')

local _InventoryReplicaHas = inventory_replica.Has

inventory_replica.Has = function(self, item, amount, ...)
  if item == "ark_gold" then
    print('replica has ark_gold')
    local left = self.inst:GetCurrency();
    print('left:', left.gold)
    local leftGold = left.gold or 0
    return leftGold >= amount, leftGold
  end
  return _InventoryReplicaHas(self, item, amount, ...)
end