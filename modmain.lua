GLOBAL.setmetatable(env, {
  __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end
})
local ark_items = require('ark_item_prefabs')
local common = require('ark_common')
PrefabFiles = {"ark_item"}

Assets = {
  Asset("ATLAS", "images/ark_ui/ark_gold.xml"),
  Asset("ATLAS", "images/ark_ui/ark_gray.xml"),
}
print('语言:', locale)
TUNING.ARK_ITEM_CONFIG = {
  language = locale or 'zh',
}
-- 初始化配置
modimport('scripts/modmain/ark_item_config')
modimport('scripts/modmain/ark_item_drop')
modimport('scripts/modmain/ark_currency')
modimport('scripts/modmain/ark_item_ui')
modimport('scripts/modmain/ark_item_i18n')
