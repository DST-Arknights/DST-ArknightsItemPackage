local ark_item = require('ark_item_prefabs')
local common = require('ark_common')
local utils = require('ark_utils')

for i = 1, #ark_item do
  local item = ark_item[i]
  if item.i18n then
      print('item i18n:', item.prefab)
      local prefab = string.upper(common.genArkItemPrefabCode(item.prefab))
      local name = common.getI18n(item.i18n, 'name')
      STRINGS.NAMES[prefab] = name
      local description = common.getI18n(item.i18n, 'description')
      STRINGS.CHARACTERS.GENERIC.DESCRIBE[prefab] = description
      local itemStrings = common.getI18n(item.i18n, 'strings')
      if (itemStrings) then
          utils.mergeTable(STRINGS, itemStrings)
      end
  end
end