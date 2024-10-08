local utils = require('ark_utils')
local function genArkItemPrefabCode(prefab)
    return "ark_item_" .. prefab
end

local function getI18n(source, path)
    local lang = TUNING.ARK_ITEM_CONFIG.language
    local result = utils.get(source, lang .. '.' .. path)
    -- 第二个参数返回是否成功
    return result or 'undefined path ' .. path, result ~= nil
end

return {
    genArkItemPrefabCode = genArkItemPrefabCode,
    getI18n = getI18n
}
