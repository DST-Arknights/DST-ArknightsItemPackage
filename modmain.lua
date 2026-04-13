GLOBAL.setmetatable(env, {
  __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end
})

PrefabFiles = {"ark_item", "ark_workshop", 'ark_backpack', 'ark_training_room', 'container_silent_opener'}

Assets = {
  Asset("SHADER", "shaders/border_radius.ksh"),
  Asset("ATLAS", "images/ark_workshop.xml"),
  Asset("ATLAS", "images/ark_item_prototyper.xml"),
  Asset("ATLAS", "images/ark_skill.xml"),
  Asset("ATLAS", "images/ark_training_room.xml"),
  Asset("ATLAS", "images/ark_training_room_prototyper.xml"),
  Asset("ATLAS", "images/map_icons/ark_training_room.xml"),
  Asset("ATLAS", "images/emoticon_btn.xml"),
  Asset("ATLAS", "images/ark_emoticon.xml"),
  Asset("ANIM", "anim/ark_backpack_slot.zip"),
  Asset("ANIM", "anim/ark_backpack_bg.zip"),
  Asset("SOUNDPACKAGE", "sound/ark_item.fev"),
  Asset("FILE", "sound/ark_item.fsb"),
}

AddReplicableComponent("ark_skill")
AddReplicableComponent("ark_currency")
AddReplicableComponent("ark_elite")
AddReplicableComponent("ark_buff_icon")

TUNING.ARK_CONFIG = {}

-- 阻止滚轮缩放游戏视角，仅让面板滚动生效
function GLOBAL.PreventScrollZoom()
  if ThePlayer and ThePlayer.components.playercontroller then
    local currentTime = GetStaticTime()
    ThePlayer.components.playercontroller.lastzoomtime = currentTime
  end
end
-- 加载日志
-- 导出全局变量ArkLogger
modimport('scripts/ark_logger')
ArkLogger:DeclareLogger('DEBUG', 'ARK-ITEM')
-- 加载符号
modimport('modmain/symbol')
-- 加载 NetState
modimport('modmain/net_state')
-- 加载安全调用
modimport('modmain/safe_call')
-- 加载热键管理器
modimport('scripts/ark_hotkey')
-- 加载语言
-- 导出全局变量MergePOFile
modimport('modmain/ark_i18n')
-- 脚本扩展
modimport('modmain/entityscript_extension')
-- 加载中文语言包
MergePOFile('languages/ark_chinese_s.po', LOC.GetLocaleCode(LANGUAGE.CHINESE_S), true)
-- 加载字体
modimport('modmain/ark_fonts')
-- 初始化配置
modimport('modmain/ark_config')
-- 科技
modimport('modmain/ark_tech')
-- 货币
modimport('modmain/ark_currency')
-- 物品
modimport('modmain/ark_item')
-- 背包
modimport('modmain/ark_item_container')
-- 技能
-- 导出全局变量AddSkillLevelUpRecipes
modimport('modmain/ark_skill')
-- 精英化
modimport('modmain/ark_elite')
-- 扩展ui
modimport('modmain/ark_buff_icon')
modimport('modmain/ark_extend_ui')
-- 武器扩展
modimport('modmain/combat_extension')
-- 护甲扩展
modimport('modmain/armor_extension')
-- 生命值扩展
modimport('modmain/health_extension')
-- 事件回调优先级
modimport('modmain/priority_event_callback')
-- 特效生成器
modimport('modmain/ark_make_fx')
-- 聊天表情
modimport('modmain/richchat_emoticons')
-- widget 扩展
modimport('modmain/widget_extension')
-- 其他模组兼容
modimport('modmain/mods_compatibility/amiya')

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
  id = "string:classified",
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
  title = "string:classified",
  desc = "string:classified",
})