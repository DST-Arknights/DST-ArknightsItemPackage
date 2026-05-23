local function GetCurrentElite(inst)
  if inst == nil then
    return nil
  end
  if inst.replica.ark_elite then
    return inst.replica.ark_elite.state.elite or 0
  end
  return nil
end

local function IsAtEliteLevelCap(inst)
  if inst == nil then
    return false
  end
  if inst.replica.ark_elite then
    return inst.replica.ark_elite:IsAtLevelCap()
  end
  if inst.components.ark_elite then
    return inst.components.ark_elite:CanEliteUp()
  end
  return false
end

local function CanBuild(recipe, inst, pt, rotation, prototyper, skin)
  local targetElite = recipe and recipe._targetElite or nil
  local currentElite = GetCurrentElite(inst)
  if targetElite == nil or currentElite == nil then
    return false, "ARK_ELITE_CANNOT_UPGRADE"
  end
  if currentElite >= targetElite then
    return false, "ARK_ELITE_ALREADY_REACHED"
  end
  if currentElite + 1 < targetElite then
    return false, "ARK_ELITE_NEED_PREVIOUS_STAGE"
  end
  if not IsAtEliteLevelCap(inst) then
    return false, "ARK_ELITE_LEVEL_NOT_ENOUGH"
  end
  return true
end

function GLOBAL.AddEliteLevelUpRecipes(characterPrefab,elites)
  for currentElite, eliteConfig in ipairs(elites) do
    local nextElite = currentElite + 1
    local prefabName = 'ark_elite_level_up_' .. characterPrefab .. '_' .. nextElite
    local rep = AddCharacterRecipe(prefabName, eliteConfig.ingredients, TECH.ARK_TRAINING_ONE, {
      -- force_hint = true,
      nounlock = true,
      atlas = eliteConfig.atlas,
      image = eliteConfig.image,
      actionstr = "ARK_ELITE_UPDATE",
      builder_tag = characterPrefab,
      manufactured = true,
      canbuild = CanBuild
    }, { "CRAFTING_STATION" })
    rep._targetElite = nextElite
    -- 机器制造回调
    rep.manufacturedfn = function(inst, doer)
      if doer and doer.components.ark_elite and CanBuild(rep, doer) then
        doer.components.ark_elite:SetElite(nextElite)
      end
    end
    local upperName = string.upper(prefabName)
    STRINGS.NAMES[upperName] = eliteConfig.name or (STRINGS.UI.ARK_ELITE.ELITE .. " " .. (nextElite - 1))
    STRINGS.RECIPE_DESC[upperName] = eliteConfig.desc or (STRINGS.UI.ARK_ELITE.ELITE .. " " .. (nextElite - 1))
  end
end
