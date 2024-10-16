local i18n = require "modmain/ark_item_i18n"
local common = require "ark_common"
local ark_item_prefabs = require "ark_item_prefabs"

local FILTER_NAME = 'ARK_PROCESSING_STATION'
STRINGS.UI.CRAFTING_FILTERS[FILTER_NAME] = i18n.getOtherI18n('ark_processing_station_prototype')

AddPrototyperDef('ark_processing_station', {
  icon_atlas = "images/ark_ui/modicon.xml",
  icon_image = "modicon.tex",
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
      local recipeCode = item.prefab
      local recipeDesc = common.getI18n(item.i18n, 'description') or common.getI18n(item.i18n, 'recipeDescription')
      STRINGS.RECIPE_DESC[string.upper(recipeCode)] = recipeDesc
      AddRecipe2(recipeCode, ingredients, TECH.ARK_PROCESSING_ONE, {
        nounlock = true,
        atlas = assetsCode.atlas,
        image = assetsCode.image
      })
    end
  end
end

table.insert(Assets, Asset("ATLAS", "images/ark_ui/modicon.xml"))
-- 制造站
AddRecipe2('ark_processing_station', {
  Ingredient('cutstone', 2),
  Ingredient('boards', 2),
  Ingredient('goldnugget', 2),
  Ingredient('twigs', 2),
}, TECH.SCIENCE_TWO, {
  placer = 'ark_processing_station_placer',
  atlas = "images/ark_ui/modicon.xml",
  image = "modicon.tex",
})
AddRecipeToFilter("ark_processing_station", "PROTOTYPERS")

-- 背包
AddRecipe2('ark_item_pack', {
  Ingredient('goldnugget', 1),
}, TECH.SCIENCE_ONE, {
  atlas = "images/ark_ui/modicon.xml",
  image = "modicon.tex",
})
AddRecipeToFilter("ark_item_pack", "CLOTHING")
