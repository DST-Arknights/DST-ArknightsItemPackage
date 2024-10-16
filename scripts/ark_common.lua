local utils = require('ark_utils')

local function getI18n(source, path)
    local lang = TUNING.ARK_ITEM_CONFIG.language
    local data = utils.get(source, lang .. '.' .. path)
    if not data then
        print('[Ark Item] [waring] i18n not found:', lang, path)
    end
    return data
end

local function getPrefabAssetsCode(prefab, withTex)
    -- 默认为true
    withTex = withTex == nil and true or withTex
    local image = prefab
    if withTex then
        image = image .. '.tex'
    end
    return {
        anim = 'anim/ark_item.zip',
        animBank = 'ark_item',
        animBuild = 'ark_item',
        atlas = 'images/ark_item/' .. prefab .. '.xml',
        image = image, 
    }
end

return {
    getPrefabAssetsCode = getPrefabAssetsCode,
    getI18n = getI18n
}
