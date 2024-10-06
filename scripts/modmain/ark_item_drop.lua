local ark_item = require('ark_item_prefabs')
local common = require('ark_common')

local dropMap = {}

for i = 1, #ark_item do
    local item = ark_item[i]
    if item.drop then
        for j = 1, #item.drop do
            local drop = item.drop[j]
            if not dropMap[drop.prefab] then
                dropMap[drop.prefab] = {}
            end
            table.insert(dropMap[drop.prefab], {
                prefab = item.prefab,
                adapter = drop.adapter or 'AddRandomLoot',
                args = drop.args or {1}
            })
        end
    end
end

for k, v in pairs(dropMap) do
    AddPrefabPostInit(k, function(inst)
        for i = 1, #v do
          local adapter = inst.components.lootdropper and inst.components.lootdropper[v[i].adapter]
          if adapter then
            local prefab = common.genArkItemPrefabCode(v[i].prefab)
            adapter(inst.components.lootdropper, prefab, unpack(v[i].args))
          end
        end
    end)
end
