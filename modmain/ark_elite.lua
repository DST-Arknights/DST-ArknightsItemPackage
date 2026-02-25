local common = require "ark_common"

function GLOBAL.AddEliteLevelUpRecipes(characterPrefab,elites)
  for currentElite, eliteConfig in ipairs(elites) do
    local nextElite = currentElite + 1
    local prefabName = 'ark_elite_level_up_' .. characterPrefab .. '_' .. nextElite
    local builder_tag = common.genArkEliteLevelUpPrefabName(characterPrefab, currentElite)
    ArkLogger:Debug("ark_elite add recipe", prefabName, builder_tag)
    local rep = AddCharacterRecipe(prefabName, eliteConfig.ingredients, TECH.ARK_TRAINING_ONE, {
      nounlock = true,
      atlas = eliteConfig.atlas,
      image = eliteConfig.image,
      actionstr = "ARK_ELITE_UPDATE",
      builder_tag = builder_tag,
      manufactured = true,
    }, { "CRAFTING_STATION" })
    -- 机器制造回调
    rep.manufacturedfn = function(inst, doer)
      if doer and doer.components.ark_elite then
        doer.components.ark_elite:SetElite(nextElite)
      end
    end
    local upperName = string.upper(prefabName)
    STRINGS.NAMES[upperName] = eliteConfig.name or (STRINGS.UI.ARK_ELITE.ELITE .. " " .. nextElite - 1)
    STRINGS.RECIPE_DESC[upperName] = eliteConfig.desc or (STRINGS.UI.ARK_ELITE.ELITE .. " " .. nextElite - 1)
  end
end
