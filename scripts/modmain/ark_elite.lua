local common = require "ark_common"

function GLOBAL.AddEliteLevelUpRecipes(characterPrefab,elites)
  for currentElite, eliteConfig in ipairs(elites) do
    local nextElite = currentElite + 1
    local prefabName = common.genArkEliteLevelUpPrefabName(characterPrefab, nextElite)
    local builder_tag = common.genArkEliteLevelUpPrefabName(characterPrefab, currentElite)
    ArkLogger:Debug("ark_elite add recipe", prefabName, builder_tag)
    AddCharacterRecipe(prefabName, eliteConfig.ingredients, TECH.ARK_TRAINING_ONE, {
      nounlock = true,
      atlas = eliteConfig.atlas,
      image = eliteConfig.image,
      actionstr = "ARK_ELITE_UPDATE",
      builder_tag = builder_tag,
      manufactured = true,
    }, { "CRAFTING_STATION" })
    local upperName = string.upper(prefabName)
    STRINGS.NAMES[upperName] = STRINGS.UI.ARK_ELITE.ELITE .. " " .. nextElite - 1
    STRINGS.RECIPE_DESC[upperName] = STRINGS.UI.ARK_ELITE.ELITE .. " " .. nextElite - 1
  end
end
