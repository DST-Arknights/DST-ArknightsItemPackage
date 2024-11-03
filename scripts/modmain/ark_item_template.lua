local common = require "ark_common"
local arkItemDeclare = common.getAllArkItemDeclare()

local function componentUseableAddArkCurrency(inst, args)
  args = args or {}
  assert(args.currencyType, 'currencyType is required')
  assert(args.value, 'value is required')
  inst:AddComponent('ark_currency_item')
  inst.components.ark_currency_item:AddPrice(args)  
end

local template = {
  componentUseableAddArkCurrency = componentUseableAddArkCurrency
}

for _, item in ipairs(arkItemDeclare) do
  if item.template then
    for k, args in pairs(item.template) do
      if type(template[k]) == 'function' then
        AddPrefabPostInit(item.prefab, function(inst)
          template[k](inst, args)
        end)
      end
    end
  end
end