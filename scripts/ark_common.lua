local utils = require('ark_utils')
local function genArkItemPrefabCode(prefab)
    return "ark_item_" .. prefab
end

local function getI18n(source, path)
    local lang = TUNING.ARK_ITEM_CONFIG.language
    local result = utils.get(source, lang .. '.' .. path)
    if not result then
        print('[Ark Item] i18n not found:', lang, path)
    end
    return result
end

return {
    genArkItemPrefabCode = genArkItemPrefabCode,
    getI18n = getI18n
}
