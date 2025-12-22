GLOBAL.setmetatable(env, {
  __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end
})

PrefabFiles = {"net_state_classified", "ark_item", "ark_workshop", 'ark_backpack', 'ark_training_room' }

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

AddReplicableComponent("ark_skill")
AddReplicableComponent("ark_currency")
AddReplicableComponent("ark_elite")
-- 加载日志
-- 导出全局变量ArkLogger
modimport('scripts/ark_logger')
ArkLogger:DeclareLogger('TRACE', 'ARK-ITEM')
-- 加载符号
modimport('scripts/modmain/symbol')
-- 加载 NetState
modimport('scripts/modmain/net_state')
-- 加载安全调用
modimport('scripts/modmain/safe_call')
-- 加载热键管理器
modimport('scripts/ark_hotkey')
-- 加载语言
-- 导出全局变量MergePOFile
modimport('scripts/modmain/ark_i18n')
-- 加载中文语言包
MergePOFile('languages/ark_chinese_s.po', LOC.GetLocaleCode(LANGUAGE.CHINESE_S), true)
-- 加载字体
modimport('scripts/modmain/ark_fonts')
-- 初始化配置
modimport('scripts/modmain/ark_config')
-- 科技
modimport('scripts/modmain/ark_tech')
-- 货币
modimport('scripts/modmain/ark_currency')
-- 物品
modimport('scripts/modmain/ark_item')
-- 背包
modimport('scripts/modmain/ark_item_container')
-- 技能
-- 导出全局变量AddSkillLevelUpRecipes
modimport('scripts/modmain/ark_skill')
-- 扩展ui
modimport('scripts/modmain/ark_extend_ui')

modimport('scripts/modmain/combat_extension')
