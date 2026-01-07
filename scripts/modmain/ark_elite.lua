local common = require "ark_common"

function GLOBAL.AddEliteLevelUpRecipes(characterPrefab,elites)
  for i, elite in ipairs(elites) do
    local prefabName = common.genArkEliteLevelUpPrefabName(characterPrefab, i)
    local tag = common.genArkEliteLevelUpPrefabName(characterPrefab, i)
    ArkLogger:Debug("ark_elite add recipe", prefabName, tag)
    AddCharacterRecipe(prefabName, elite.ingredients, TECH.ARK_TRAINING_ONE, {
      nounlock = true,
      atlas = elite.atlas,
      image = elite.image,
      actionstr = "ARK_ELITE_UPDATE",
      builder_tag = tag,
      manufactured = true,
    })
    AddRecipeToFilter(prefabName, CRAFTING_FILTERS.CRAFTING_STATION.name)
    local upperName = string.upper(prefabName)
    STRINGS.NAMES[upperName] = STRINGS.UI.ARK_ELITE.ELITE .. " " .. i
    STRINGS.RECIPE_DESC[upperName] = STRINGS.UI.ARK_ELITE.ELITE .. " " .. i
  end
end