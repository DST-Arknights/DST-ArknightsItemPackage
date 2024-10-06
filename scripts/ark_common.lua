local utils = require('ark_utils')
local function genArkItemPrefabCode(prefab)
    return "ark_item_" .. prefab
end

local function getI18n(source, path)
    local lang = TUNING.ARK_ITEM_CONFIG.language
    return utils.get(source, lang .. '.' .. path) or 'undefined path ' .. path
end

return {
    genArkItemPrefabCode = genArkItemPrefabCode,
    getI18n = getI18n
}
