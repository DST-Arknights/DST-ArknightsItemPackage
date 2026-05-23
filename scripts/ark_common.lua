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

local function genArkTalentPrefabNameById(id)
  return 'ark_talent_' .. id
end

local ArkCommon = {
    getPrefabAssetsCode = getPrefabAssetsCode,
    genArkSkillLevelUpPrefabNameById = genArkSkillLevelUpPrefabNameById,
    genArkSkillInstallPrefabNameById = genArkSkillInstallPrefabNameById,
    genArkSkillInstalledTagById = genArkSkillInstalledTagById,
    genArkTalentPrefabNameById = genArkTalentPrefabNameById,
}
return ArkCommon
