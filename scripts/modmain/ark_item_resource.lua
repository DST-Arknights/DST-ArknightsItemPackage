local ark_item = require('ark_item_prefabs')
local common = require('ark_common')

for i = 1, #ark_item do
    local item = ark_item[i]
    local assetsCode = common.getPrefabAssetsCode(item.prefab)
    RegisterInventoryItemAtlas(assetsCode.atlas, assetsCode.image)
end
RegisterInventoryItemAtlas('images/ark_item/ark_gold.xml', 'ark_gold.tex')