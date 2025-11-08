GLOBAL.setmetatable(env, {
  __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end
})
local common = require('ark_common')
local utils = require('ark_utils')
local TechTree = require('techtree')

PrefabFiles = {"ark_item", "ark_workshop", 'ark_backpack', 'ark_training_room'}

Assets = {
  Asset("SHADER", "shaders/border_radius.ksh"),
  Asset("ATLAS", "images/ark_item_prototyper.xml"),
  Asset("ANIM", "anim/ark_backpack_bg.zip"),
  Asset("ANIM", "anim/ark_backpack_slot.zip"),
  Asset("ATLAS", "images/ark_skill.xml"),
  Asset("ATLAS", "images/ark_training_room.xml"),
  Asset("ATLAS", "images/map_icons/ark_training_room.xml"),
  Asset("ANIM", "anim/ark_training_room.zip"),
}

GLOBAL.ARK_GLOBAL = {}
TUNING.ARK_SKILL = TUNING.ARK_SKILL or {}

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

TUNING.PROTOTYPER_TREES.ARK_WORKSHOP_ONE = TechTree.Create({
  ARK_ITEM_TECH = 1,
})
TUNING.PROTOTYPER_TREES.ARK_TRAINING_ROOM_ONE = TechTree.Create({
  ARK_TRAINING_TECH = 1,
})

for i, v in pairs(AllRecipes) do
	v.level.ARK_ITEM_TECH = v.level.ARK_ITEM_TECH or 0
  v.level.ARK_TRAINING_TECH = v.level.ARK_TRAINING_TECH or 0
end

-- 初始化配置
modimport('scripts/modmain/ark_config')
modimport('scripts/modmain/ark_i18n')
GLOBAL.ARK_GLOBAL.LoadPOFile('scripts/languages/ark_chinese_s.po', LOC.GetLocaleCode(LANGUAGE.CHINESE_S))
modimport('scripts/modmain/ark_currency')
modimport('scripts/modmain/ark_item')
modimport('scripts/modmain/ark_item_container')
modimport('scripts/modmain/ark_skill')
modimport('scripts/modmain/ark_exp')

AddReplicableComponent("ark_currency")
