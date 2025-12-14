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

local function normalizeSkillId(id)
  id = string.lower(tostring(id))
  id = string.gsub(id, "%s+", "_")
  id = string.gsub(id, "[^%w_]", "")
  return id
end


local function genArkSkillLevelUpPrefabNameById(prefab,id, level)
  return 'ark_skill_level_up_' .. prefab .. '_' .. normalizeSkillId(id) .. '_' .. level
end

local function parseArkSkillLevelUpPrefabName(prefabName)
  -- 匹配格式: ark_skill_level_up_<id>_<level>，其中 id 为字符串（可含下划线），level 为数字
  local id, level = string.match(prefabName, "^ark_skill_level_up_(.+)_(%d+)$")
  if id and level then
    return normalizeSkillId(id), tonumber(level)
  end
  return nil, nil
end


return {
    getPrefabAssetsCode = getPrefabAssetsCode,
    normalizeSkillId = normalizeSkillId,
    genArkSkillLevelUpPrefabNameById = genArkSkillLevelUpPrefabNameById,
    parseArkSkillLevelUpPrefabName = parseArkSkillLevelUpPrefabName,
}
