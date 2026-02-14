GLOBAL.setmetatable(env, {
  __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end
})

PrefabFiles = {"ark_item", "ark_workshop", 'ark_backpack', 'ark_training_room', 'container_silent_opener'}

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
AddReplicableComponent("ark_buff_icon")
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
-- 精英化
modimport('scripts/modmain/ark_elite')
-- 扩展ui
modimport('scripts/modmain/ark_extend_ui')
-- 武器扩展
modimport('scripts/modmain/combat_extension')
-- 特效生成器
modimport('scripts/modmain/ark_make_fx')

-- widget 扩展
modimport('scripts/modmain/widget_extension')


-- 定义 elite NetState
DefineNetState("ark_elite", {
  rarity = "int:classified",
  potential = "int:classified",
  elite = "int:classified",
  level = "int:classified",
  currentExp = "int:classified",
  overflowExp = "int:classified",
})

DefineNetState("ark_skill", {
  status = "int:classified",
  level = "int:classified",
  energyProgress = "float:classified",
  buffProgress = "float:classified",
  bulletCount = "int:classified",
  activationStacks = "int:classified",
})

-- 定义货币 NetState
DefineNetState("ark_currency", (function()
  local stateDef = {}
  for _, currencyType in ipairs(TUNING.ARK_CURRENCY_TYPES) do
    stateDef[currencyType] = "int:classified"
  end
  return stateDef
end)())

DefineNetState("ark_buff_icon", {
  atlas = "string:classified",
  tex = "string:classified",
  totalTime = "float:classified",
  remainingTime = "float:classified",
})