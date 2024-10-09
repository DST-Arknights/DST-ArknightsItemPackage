local ark_item = require('ark_item_prefabs')
local common = require('ark_common')
local utils = require('ark_utils')


local otherI18n = {
  ['zh'] = {
    goldName = '龙门币',
    ark_processing_station_prototype = '罗德岛加工站',
    STRINGS = {
      NAMES = {
        ARK_PROCESSING_STATION = '罗德岛加工站',
      },
      CHARACTERS = {
        GENERIC = {
          DESCRIBE = {
            ARK_PROCESSING_STATION = '加工合成罗德岛材料的设备',
          }
        }
      }
    }
  }
}

local function getOtherI18n(path)
  return common.getI18n(otherI18n, path)
end

for i = 1, #ark_item do
  local item = ark_item[i]
  if item.i18n then
      print('item i18n:', item.prefab)
      local prefab = string.upper(common.genArkItemPrefabCode(item.prefab))
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
local otherStrings = common.getI18n(otherI18n, 'STRINGS')
if (otherStrings) then
  utils.mergeTable(STRINGS, otherStrings)
end

return {
  getOtherI18n = getOtherI18n,
}