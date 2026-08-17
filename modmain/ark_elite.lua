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

-- 精英阶段显示名：1-10 用数字词（中文"一"…英文"one"…），超出退化阿拉伯数字
local function GetEliteStageName(stage)
  local word = STRINGS.UI.NUMBERS and STRINGS.UI.NUMBERS[stage] or nil
  if word ~= nil then
    -- 中文无空格拼接（精英化一），其他语言空格拼接（Elite one）
    local isZh = LOC.GetLocaleCode() ~= nil and LOC.GetLocaleCode():match("^zh") ~= nil
    return STRINGS.UI.ARK_ELITE.ELITE .. (isZh and "" or " ") .. word
  end
  return STRINGS.UI.ARK_ELITE.ELITE .. " " .. stage
end

function GLOBAL.AddEliteLevelUpRecipes(characterPrefab,elites)
  for currentElite, eliteConfig in ipairs(elites) do
    local nextElite = currentElite + 1
    local prefabName = 'ark_elite_level_up_' .. characterPrefab .. '_' .. nextElite
    local rep = AddCharacterRecipe(prefabName, eliteConfig.ingredients, TECH.NONE, {
      -- force_hint = true,
      -- nameoverride/description 是 STRINGS.NAMES/RECIPE_DESC 的索引 key，非直接文本；
      -- 描述设为本配方名，避免 UI 落到共享 product 上
      description = prefabName,
      nounlock = true,
      atlas = eliteConfig.atlas,
      image = eliteConfig.image,
      actionstr = "ARK_ELITE_UPDATE",
      builder_tag = characterPrefab,
      product = "ark_craft_callback",
      dropitem = true,
      canbuild = CanBuild
    })
    rep._targetElite = nextElite
    -- 制造回调：由隐形回调预制体 ark_craft_callback 在 OnBuiltFn 阶段触发（无科技/无建筑直接制作）
    rep.OnBuiltFn = function(ghost, builder)
      if builder and builder.components.ark_elite and CanBuild(rep, builder) then
        builder.components.ark_elite:SetElite(rep._targetElite)
      end
    end
    -- 配方显示名/描述：UI 以 recipe.name 为 key 查 STRINGS.NAMES / STRINGS.RECIPE_DESC
    local upperName = string.upper(prefabName)
    STRINGS.NAMES[upperName] = eliteConfig.name or GetEliteStageName(nextElite - 1)
    STRINGS.RECIPE_DESC[upperName] = eliteConfig.desc or GetEliteStageName(nextElite - 1)
  end
end
