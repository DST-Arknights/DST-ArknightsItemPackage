local utils = require('ark_utils')
local i18nDeclare = require('ark_item_i18n_declare')
local arkItemDeclare = require('ark_item_declare')

local function getI18n(source, path)
    local lang = TUNING.ARK_ITEM_CONFIG.language
    local data = utils.get(source, lang .. '.' .. path)
    if not data then
        print('[Ark Item] [waring] i18n not found:', lang, path)
    end
    return data
end

local function getCommonI18n(path)
    return getI18n(i18nDeclare, path)
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
        slotbgatlas = 'images/ark_item/' .. prefab .. '_slotbg.xml',
        slotbgimage = prefab .. '_slotbg.tex'
    }
end

local declareCache = nil
local function getAllArkItemDeclare()
    if declareCache then
        return declareCache
    end
    declareCache = {}
    for _, group in ipairs(arkItemDeclare) do
        for _, item in ipairs(group.items) do
            table.insert(declareCache, item)
        end
    end
    return declareCache
end

return {
    getPrefabAssetsCode = getPrefabAssetsCode,
    getI18n = getI18n,
    getCommonI18n = getCommonI18n,
    getAllArkItemDeclare = getAllArkItemDeclare
}
