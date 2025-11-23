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


local function genArkSkillLevelUpPrefabNameById(id, level)
  return 'ark_skill_level_up_' .. normalizeSkillId(id) .. '_' .. level
end


local function genArkSkillLevelTagById(id, level)
  return 'ark_skill_level_' .. normalizeSkillId(id) .. '_' .. level
end

local function parseArkSkillLevelUpPrefabName(prefabName)
  -- 匹配格式: ark_skill_level_up_<id>_<level>，其中 id 为字符串（可含下划线），level 为数字
  local id, level = string.match(prefabName, "^ark_skill_level_up_(.+)_(%d+)$")
  if id and level then
    return normalizeSkillId(id), tonumber(level)
  end
  return nil, nil
end

local function canNextElite(rarity, elite, level)
  -- 要当前等级满级, 并且当前精英化等级小于最大精英化等级
  return level >= CONSTANTS.EXP_CONFIG.maxLevel[rarity][elite] and elite < #CONSTANTS.EXP_CONFIG.maxLevel[rarity]
end

local function getNextLevelExp(elite, level)
  return CONSTANTS.EXP_CONFIG.exp[elite][level][1]
end

-- 新增配置计算相关函数
local function getMaxLevel(rarity, elite)
  return CONSTANTS.EXP_CONFIG.maxLevel[rarity][elite]
end

local function getExpAndGoldCost(elite, level)
  if not CONSTANTS.EXP_CONFIG.exp[elite] or not CONSTANTS.EXP_CONFIG.exp[elite][level] then
    return nil, nil
  end
  return CONSTANTS.EXP_CONFIG.exp[elite][level][1], CONSTANTS.EXP_CONFIG.exp[elite][level][2]
end

local function getMaxPotential()
  return CONSTANTS.EXP_CONFIG.maxPotential
end

return {
    getPrefabAssetsCode = getPrefabAssetsCode,
    normalizeSkillId = normalizeSkillId,
    genArkSkillLevelTagById = genArkSkillLevelTagById,
    genArkSkillLevelUpPrefabNameById = genArkSkillLevelUpPrefabNameById,
    parseArkSkillLevelUpPrefabName = parseArkSkillLevelUpPrefabName,
    canNextElite = canNextElite,
    getMaxLevel = getMaxLevel,
    getExpAndGoldCost = getExpAndGoldCost,
    getMaxPotential = getMaxPotential,
    getNextLevelExp = getNextLevelExp,
}
