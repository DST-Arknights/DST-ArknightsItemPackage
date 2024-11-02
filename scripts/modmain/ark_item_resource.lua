local common = require('ark_common')
local arkItemDeclare = common.getAllArkItemDeclare()

for _, item in ipairs(arkItemDeclare) do
    local assetsCode = common.getPrefabAssetsCode(item.prefab)
    RegisterInventoryItemAtlas(assetsCode.atlas, assetsCode.image)
end
RegisterInventoryItemAtlas('images/ark_item/ark_gold.xml', 'ark_gold.tex')
RegisterInventoryItemAtlas('images/ark_item/ark_item_pack.xml', 'ark_item_pack.tex')