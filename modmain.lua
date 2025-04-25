GLOBAL.setmetatable(env, {
  __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end
})
local common = require('ark_common')
local utils = require('ark_utils')
local TechTree = require('techtree')

PrefabFiles = {"ark_item", "ark_processing_station", 'ark_item_pack', 'ark_training_station'}

Assets = {
  Asset("ATLAS", "images/ark_item_prototyper.xml"),
  Asset("ANIM", "anim/ark_item_pack_bg.zip"),
  Asset("ANIM", "anim/ark_item_pack_slot.zip"),
  Asset("ATLAS", "images/ark_skill.xml"),
  Asset("ATLAS", "images/ark_training_station.xml"),
  Asset("ATLAS", "images/map_icons/ark_training_station.xml"),
  Asset("ANIM", "anim/ark_training_station.zip"),
}
TUNING.ARK_CONFIG = {
  language = locale or 'zh',
}

table.insert(TechTree.AVAILABLE_TECH, 'ARK_ITEM_TECH')
table.insert(TechTree.AVAILABLE_TECH, 'ARK_TRAINING_TECH')

TECH.NONE.ARK_ITEM_TECH = 0
TECH.ARK_ITEM_ONE = { ARK_ITEM_TECH = 1}
TECH.NONE.ARK_TRAINING_TECH = 0
TECH.ARK_TRAINING_ONE = { ARK_TRAINING_TECH = 1}

for k,v in pairs(TUNING.PROTOTYPER_TREES) do
  v.ARK_ITEM_TECH = 0
  v.ARK_TRAINING_TECH = 0
end

TUNING.PROTOTYPER_TREES.ARK_PROCESSING_STATION_ONE = TechTree.Create({
  ARK_ITEM_TECH = 1,
})
TUNING.PROTOTYPER_TREES.ARK_TRAINING_STATION_ONE = TechTree.Create({
  ARK_TRAINING_TECH = 1,
})

for i, v in pairs(AllRecipes) do
	v.level.ARK_ITEM_TECH = v.level.ARK_ITEM_TECH or 0
  v.level.ARK_TRAINING_TECH = v.level.ARK_TRAINING_TECH or 0
end

-- 初始化配置
modimport('scripts/modmain/ark_config')
utils.mergeTable(STRINGS, require('ark_i18n')[TUNING.ARK_CONFIG.language].STRINGS)

local function mergeI18n(item)
  if not item.i18n then return end
  local prefab = string.upper(item.prefab)
  local name = item.i18n[TUNING.ARK_CONFIG.language] and item.i18n[TUNING.ARK_CONFIG.language].name or item.i18n['zh'].name
  STRINGS.NAMES[prefab] = name
  local description = item.i18n[TUNING.ARK_CONFIG.language] and item.i18n[TUNING.ARK_CONFIG.language].description or item.i18n['zh'].description
  STRINGS.CHARACTERS.GENERIC.DESCRIBE[prefab] = description
  local recipeDescription = item.i18n[TUNING.ARK_CONFIG.language] and item.i18n[TUNING.ARK_CONFIG.language].recipeDescription or item.i18n['zh'].recipeDescription
  STRINGS.RECIPE_DESC[prefab] = recipeDescription
end


for _, item in ipairs(require('ark_item_declare')) do
  mergeI18n(item)
end

modimport('scripts/modmain/ark_currency')
modimport('scripts/modmain/ark_item')
modimport('scripts/modmain/ark_item_container')
modimport('scripts/modmain/ark_skill')
modimport('scripts/modmain/ark_exp')

AddReplicableComponent("ark_currency")
