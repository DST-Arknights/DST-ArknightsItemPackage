local common = require('ark_common')
local utils = require('ark_utils')
local arkItemDeclare = common.getAllArkItemDeclare()

for i = 1, #arkItemDeclare do
  local item = arkItemDeclare[i]
  if item.i18n then
      local prefab = string.upper(item.prefab)
      local name = common.getI18n(item.i18n, 'name')
      STRINGS.NAMES[prefab] = name
      local description = common.getI18n(item.i18n, 'description')
      STRINGS.CHARACTERS.GENERIC.DESCRIBE[prefab] = description
      local itemStrings = common.getI18n(item.i18n, 'STRINGS')
      if (itemStrings) then
          utils.mergeTable(STRINGS, itemStrings)
      end
  end
end

-- 合并 STRINGS
local otherStrings = common.getCommonI18n('STRINGS')
if (otherStrings) then
  utils.mergeTable(STRINGS, otherStrings)
end