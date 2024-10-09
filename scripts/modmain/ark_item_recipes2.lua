local i18n = require "modmain/ark_item_i18n"
local common = require "ark_common"
local ark_item_prefabs = require "ark_item_prefabs"

local FILTER_NAME = 'ARK_PROCESSING_STATION'
STRINGS.UI.CRAFTING_FILTERS[FILTER_NAME] = i18n.getOtherI18n('ark_processing_station_prototype')

AddPrototyperDef('ark_processing_station', {
  icon_atlas = "images/hud.xml",
  icon_image = "tab_celestial.tex",
  is_crafting_station = true,
  action_str = FILTER_NAME,
  filter_text = STRINGS.UI.CRAFTING_FILTERS[FILTER_NAME]
})

-- test
for i = 1, #ark_item_prefabs do
  local item = ark_item_prefabs[i]
  if item.recipe then
    for j = 1, #item.recipe do
      local recipe = item.recipe[j]
      local ingredients = {}
      for k = 1, #recipe do
        local ingredient = recipe[k]
        table.insert(ingredients, Ingredient(ingredient.prefab, ingredient.count))
      end
      local assetsCode = common.getPrefabAssetsCode(item.prefab)
      AddRecipe2(common.genArkItemPrefabCode(item.prefab), ingredients, TECH.ARK_PROCESSING_STATION, {
        nounlock = true,
        atlas = assetsCode.atlas,
        images = assetsCode.image
      })
    end
  end
end
