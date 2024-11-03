local utils = require("ark_utils")

local ArkCurrencyData = Class(function(self)
    self.currency = {}
    self.defaultUserCurrencyData = {
    }
    for _, currencyType in ipairs(TUNING.ARK_CURRENCY_TYPES) do
      self.defaultUserCurrencyData[currencyType] = 0
    end
end)

function ArkCurrencyData:GetPlayerCurrency(userid)
  if not self.currency[userid] then
    self.currency[userid] = utils.cloneTable(self.defaultUserCurrencyData)
  end
  return self.currency[userid]
end

function ArkCurrencyData:SetPlayerCurrency(userid, currency)
  self.currency[userid] = currency
end

function ArkCurrencyData:OnSave()
  return {
    currency = self.currency
  }
end

function ArkCurrencyData:OnLoad(data)
  if data.currency then
    self.currency = data.currency
  end
end

return ArkCurrencyData