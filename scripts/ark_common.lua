local function getPrefabAssetsCode(prefab, withTex)
    -- 默认为true
    withTex = withTex == nil and true or withTex
    local image = prefab
    if withTex then
        image = image .. '.tex'
    end
    return {
        anim = 'anim/ark_item.zip',
        animBank = 'ark_item',
        animBuild = 'ark_item',
        atlas = 'images/ark_item.xml',
        image = image,
        slotbgatlas = 'images/ark_backpack_slotbg.xml',
        slotbgimage = prefab .. '.tex'
    }
end

local function genArkSkillLevelUpPrefabNameById(id, level)
  return 'ark_skill_level_up_' .. id .. '_' .. level .. '_level'
end

local function genArkSkillInstallPrefabNameById(id)
  return 'ark_skill_install_' .. id
end

local function genArkSkillInstalledTagById(id)
  return 'ark_skill_installed_' .. id
end

-- 精英化等级tag
local function genArkEliteLevelUpPrefabName(prefab, level)
  return 'ark_elite_level_up_' .. prefab .. '_' .. level
end

local function genArkTalentPrefabNameById(id)
  return 'ark_talent_' .. id
end

local function parseArkEliteLevelUpPrefabName(prefabName)
  -- 匹配格式: ark_elite_level_up_<level>，其中 level 为数字
  local _, level = string.match(prefabName, "^ark_elite_level_up_(.+)_(%d+)$")
  if level then
    return tonumber(level)
  end
  return nil
end



local ArkCommon = {
    getPrefabAssetsCode = getPrefabAssetsCode,
    genArkSkillLevelUpPrefabNameById = genArkSkillLevelUpPrefabNameById,
    genArkSkillInstallPrefabNameById = genArkSkillInstallPrefabNameById,
    genArkSkillInstalledTagById = genArkSkillInstalledTagById,
    genArkEliteLevelUpPrefabName = genArkEliteLevelUpPrefabName,
    parseArkEliteLevelUpPrefabName = parseArkEliteLevelUpPrefabName,
    genArkTalentPrefabNameById = genArkTalentPrefabNameById,
}
return ArkCommon
