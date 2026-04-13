local SafeCallArkExtendUI = GenSafeCall(function (inst)
  return inst and inst.HUD and inst.HUD.controls and inst.HUD.controls.arkExtendUi or nil
end)

local SafeCallArkCurrencyUI = GenSafeCall(function (inst)
  return SafeCallArkExtendUI(inst).currency
end)
local ArkCurrency = Class(function(self, inst)
  self.inst = inst
  self.state = NetState(self.inst, "ark_currency")
  self.state:Attach(self.inst)
  if not TheNet:IsDedicated() then
    self.state:Watch(TUNING.ARK_CURRENCY_TYPES, function()
      SafeCallArkCurrencyUI(self.inst):Refresh()
      if self.inst.HUD then
        self.inst:PushEvent("refreshcrafting")
      end
    end)
    SafeCallArkExtendUI(self.inst):SetupCurrency()
  end
  if TheWorld.ismastersim then
    self.inst:DoTaskInTime(0, function()
      local wordData = TheWorld.components.ark_currency_data:GetPlayerCurrency(self.inst.userid)
      if wordData then
        self:SetArkCurrency(wordData)
      end
    end)
  end
end)

function ArkCurrency:GetArkCurrency()
  local currency = {}
  for _, currencyType in ipairs(TUNING.ARK_CURRENCY_TYPES) do
    currency[currencyType] = self.state[currencyType]
  end
  return currency
end

function ArkCurrency:SetArkCurrency(currency)
  for currencyType, value in pairs(currency) do
    self:SetArkCurrencyByType(currencyType, value)
  end
end

function ArkCurrency:GetArkCurrencyByType(currencyType)
  return self.state[currencyType]
end

function ArkCurrency:SetArkCurrencyByType(currencyType, value)
  self.state[currencyType] = value
  if TheWorld.ismastersim then
    TheWorld.components.ark_currency_data:SetPlayerCurrency(self.inst.userid, self:GetArkCurrency())
  end
end

function ArkCurrency:AddArkCurrencyByType(currencyType, value)
  ArkLogger:Debug('AddArkCurrencyByType', currencyType, value)
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
