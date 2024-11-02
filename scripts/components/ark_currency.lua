local ArkCurrency = Class(function(self, inst)
  self.inst = inst
  self.prices = {}
end)

function ArkCurrency:AddPrice(price)
  table.insert(self.prices, price)
end

function ArkCurrency:GetAllPrices()
  return self.prices
end

function ArkCurrency:CanUse(doer)
  return doer:HasTag('ark_currency_user')
end

return ArkCurrency