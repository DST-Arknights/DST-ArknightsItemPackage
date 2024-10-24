
local common = require "ark_common"
local arkItemDeclare = common.getAllArkItemDeclare()

local FILTER_NAME = 'ARK_PROCESSING_STATION'

AddPrototyperDef('ark_processing_station', {
  icon_atlas = "images/ark_item_prototyper.xml",
  icon_image = "ark_item_prototyper.tex",
  is_crafting_station = true,
  action_str = FILTER_NAME,
  filter_text = STRINGS.UI.CRAFTING_FILTERS[FILTER_NAME]
})

-- test
for i = 1, #arkItemDeclare do
  local item = arkItemDeclare[i]
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
      local recipeDesc = common.getI18n(item.i18n, 'recipeDescription') or common.getI18n(item.i18n, 'description')
      STRINGS.RECIPE_DESC[string.upper(recipeCode)] = recipeDesc
      AddRecipe2(recipeCode, ingredients, TECH.ARK_PROCESSING_ONE, {
        nounlock = true,
        atlas = assetsCode.atlas,
        image = assetsCode.image
      })
    end
  end
end

-- 制造站
AddRecipe2('ark_processing_station', {
  Ingredient('goldnugget', 2),
}, TECH.SCIENCE_TWO, {
  placer = 'ark_processing_station_placer',
  atlas = "images/ark_item/ark_item_pack.xml",
  image = "ark_item_pack.tex",
})
AddRecipeToFilter("ark_processing_station", "PROTOTYPERS")

-- 背包
AddRecipe2('ark_item_pack', {
  Ingredient('goldnugget', 1),
}, TECH.SCIENCE_ONE, {
  atlas = "images/ark_item/ark_item_pack.xml",
  image = "ark_item_pack.tex",
})
AddRecipeToFilter("ark_item_pack", "CLOTHING")
