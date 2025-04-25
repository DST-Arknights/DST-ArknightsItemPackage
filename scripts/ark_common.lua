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
        slotbgatlas = 'images/ark_item_slotbg.xml',
        slotbgimage = prefab .. '.tex'
    }
end

local function genArkSkillLevelUpPrefabName(idx, level)
  return 'ark_skill_level_up_' .. idx .. '_' .. level
end

local function parseArkSkillLevelUpPrefabName(prefabName)
  -- 匹配格式: ark_skill_level_up_数字_数字
  local idx, level = string.match(prefabName, "ark_skill_level_up_(%d+)_(%d+)")
  if idx and level then
    return tonumber(idx), tonumber(level)
  end
  return nil, nil
end

local function genArkSkillLevelTag(idx, level)
  return 'ark_skill_level_' .. idx .. '_' .. level
end

local function canNextElite(rarity, elite, level)
  -- 要当前等级满级, 并且当前精英化等级小于最大精英化等级
  return level >= CONSTANTS.EXP_CONFIG.maxLevel[rarity][elite] and elite < #CONSTANTS.EXP_CONFIG.maxLevel[rarity]
end

local function getNextLevelExp(elite, level)
  return CONSTANTS.EXP_CONFIG.exp[elite][level][1]
end

local function formatSkillLevelString(level)
  if level == 8 then
    return "Rank Ⅰ"
  elseif level ==  9 then
    return "Rank Ⅱ"
  elseif level == 10 then
    return "Rank Ⅲ"
  end
  return tostring(level)
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
    genArkSkillLevelUpPrefabName = genArkSkillLevelUpPrefabName,
    parseArkSkillLevelUpPrefabName = parseArkSkillLevelUpPrefabName,
    genArkSkillLevelTag = genArkSkillLevelTag,
    formatSkillLevelString = formatSkillLevelString,
    canNextElite = canNextElite,
    getMaxLevel = getMaxLevel,
    getExpAndGoldCost = getExpAndGoldCost,
    getMaxPotential = getMaxPotential,
    getNextLevelExp = getNextLevelExp,
}
