local ark_item = require('ark_item_prefabs')
local common = require('ark_common')
local utils = require('ark_utils')


local otherI18n = {
  ['zh'] = {
    goldName = '龙门币',
    STRINGS = {
      UI = {
        CRAFTING_FILTERS = {
          ARK_PROCESSING_STATION = '罗德岛加工站',
        }
      },
      RECIPE_DESC = {
        ARK_PROCESSING_STATION = '用于加工合成罗德岛材料的设备',
        ARK_ITEM_PACK = '罗德岛背包',
      },
      NAMES = {
        ARK_PROCESSING_STATION = '罗德岛加工站',
        ARK_GOLD = '龙门币',
        ARK_ITEM_PACK = '罗德岛背包',
      },
      CHARACTERS = {
        GENERIC = {
          ACTIONFAIL = {
            GENERIC = {
              ARK_ITEM_PACK = '承受不了更多的源石空间',
            },
          },
          DESCRIBE = {
            ARK_PROCESSING_STATION = '加工合成罗德岛材料的设备',
            ARK_GOLD = '龙门币',
            ARK_ITEM_PACK = '罗德岛背包',
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
local otherStrings = common.getI18n(otherI18n, 'STRINGS')
if (otherStrings) then
  utils.mergeTable(STRINGS, otherStrings)
end

return {
  getOtherI18n = getOtherI18n,
}