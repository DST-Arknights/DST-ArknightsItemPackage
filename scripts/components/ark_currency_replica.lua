local utils = require("ark_utils")

local function getVarName(currencyType) return '_currency_' .. currencyType end

local ArkCurrency = Class(function(self, inst)
  self.inst = inst
  for _, currencyType in ipairs(TUNING.ARK_CURRENCY_TYPES) do
    local varName = getVarName(currencyType)
    local varNetName = 'ark_currency.' .. varName
    local varDirtyName = 'ark_currency_dirty_' .. currencyType
    self[varName] = net_int(inst.GUID, varNetName, varDirtyName)
    if not TheWorld.ismastersim then
      self.inst:ListenForEvent(varDirtyName, function()
        if self.inst.HUD and self.inst.HUD.controls.arkCurrency then
          self.inst.HUD.controls.arkCurrency:Refresh()
        end
      end)
    end
  end
end)

function ArkCurrency:GetArkCurrency()
  local currency = {}
  for _, currencyType in ipairs(TUNING.ARK_CURRENCY_TYPES) do
    local varName = getVarName(currencyType)
    currency[currencyType] = self[varName]:value()
  end
  return currency
end

function ArkCurrency:SetArkCurrency(currency)
  for currencyType, value in pairs(currency) do
    self:SetArkCurrencyByType(currencyType, value)
  end
end

function ArkCurrency:GetArkCurrencyByType(currencyType)
  local varName = getVarName(currencyType)
  return self[varName]:value()
end

function ArkCurrency:SetArkCurrencyByType(currencyType, value)
  local varName = getVarName(currencyType)
  self[varName]:set(value)
  if TheWorld.ismastersim then
    TheWorld.components.ark_currency_data:SetPlayerCurrency(self.inst.userid, self:GetArkCurrency())
  end
end

function ArkCurrency:AddArkCurrencyByType(currencyType, value)
  local old = self:GetArkCurrencyByType(currencyType)
  self:SetArkCurrencyByType(currencyType, old + value)
end

function ArkCurrency:GetArkGold() return self:GetArkCurrencyByType("ark_gold") end

function ArkCurrency:SetArkGold(value) self:SetArkCurrencyByType("ark_gold", value) end

function ArkCurrency:AddArkGold(value) self:AddArkCurrencyByType("ark_gold", value) end

function ArkCurrency:GetArkDiamondShd() return self:GetArkCurrencyByType("ark_diamond_shd") end

function ArkCurrency:SetArkDiamondShd(value) self:SetArkCurrencyByType("ark_diamond_shd", value) end

function ArkCurrency:AddArkDiamondShd(value) self:AddArkCurrencyByType("ark_diamond_shd", value) end

function ArkCurrency:GetArkDiamond() return self:GetArkCurrencyByType("ark_diamond") end

function ArkCurrency:SetArkDiamond(value) self:SetArkCurrencyByType("ark_diamond", value) end

function ArkCurrency:AddArkDiamond(value) self:AddArkCurrencyByType("ark_diamond", value) end

function ArkCurrency:GetArkExggShd() return self:GetArkCurrencyByType("ark_exgg_shd") end

function ArkCurrency:SetArkExggShd(value) self:SetArkCurrencyByType("ark_exgg_shd", value) end

function ArkCurrency:AddArkExggShd(value) self:AddArkCurrencyByType("ark_exgg_shd", value) end

function ArkCurrency:GetArkHggShd() return self:GetArkCurrencyByType("ark_hgg_shd") end

function ArkCurrency:SetArkHggShd(value) self:SetArkCurrencyByType("ark_hgg_shd", value) end

function ArkCurrency:AddArkHggShd(value) self:AddArkCurrencyByType("ark_hgg_shd", value) end

return ArkCurrency
