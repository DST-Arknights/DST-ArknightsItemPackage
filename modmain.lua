GLOBAL.setmetatable(env, {
  __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end
})
local common = require('ark_common')
PrefabFiles = {"ark_item", "ark_processing_station", 'ark_item_pack', 'ark_gold'}

Assets = {
  Asset("ATLAS", "images/ark_item_prototyper.xml"),
}
TUNING.ARK_ITEM_CONFIG = {
  language = locale or 'zh',
}
-- 初始化配置
modimport('scripts/modmain/ark_item_config')
modimport('scripts/modmain/ark_item_i18n_init')
modimport('scripts/modmain/ark_item_resource')
modimport('scripts/modmain/ark_item_drop')
modimport('scripts/modmain/ark_currency')
modimport('scripts/modmain/ark_item_ui')
modimport('scripts/modmain/ark_item_tech')
modimport('scripts/modmain/ark_gold')
modimport('scripts/modmain/ark_item_recipes2')
modimport('scripts/modmain/ark_item_container')
