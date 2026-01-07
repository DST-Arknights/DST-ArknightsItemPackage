local utils = require('ark_utils')
local CONSTANTS = require "ark_constants"

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

local function genArkSkillLevelUpPrefabNameById(prefab,id, level)
  return 'ark_skill_level_up_' .. prefab .. '_' .. id .. '_' .. level .. '_level'
end

local function parseArkSkillLevelUpPrefabName(prefabName)
  -- 匹配格式: ark_skill_level_up_<id>_<level>_level，其中 id 为字符串（可含下划线），level 为数字
  local _, id, level = string.match(prefabName, "^ark_skill_level_up_(.+)_(.+)_(%d+)_level$")
  if id and level then
    return id, tonumber(level)
  end
  return nil, nil
end

-- 精英化等级tag
local function genArkEliteLevelUpPrefabName(prefab, level)
  return 'ark_elite_level_up_' .. prefab .. '_' .. level
end

local function parseArkEliteLevelUpPrefabName(prefabName)
  -- 匹配格式: ark_elite_level_up_<level>，其中 level 为数字
  local _, level = string.match(prefabName, "^ark_elite_level_up_(.+)_(%d+)$")
  if level then
    return tonumber(level)
  end
  return nil
end


return {
    getPrefabAssetsCode = getPrefabAssetsCode,
    genArkSkillLevelUpPrefabNameById = genArkSkillLevelUpPrefabNameById,
    parseArkSkillLevelUpPrefabName = parseArkSkillLevelUpPrefabName,
    genArkEliteLevelUpPrefabName = genArkEliteLevelUpPrefabName,
    parseArkEliteLevelUpPrefabName = parseArkEliteLevelUpPrefabName,
}
