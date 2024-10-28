local common = require('ark_common')
local arkItemDeclare = common.getAllArkItemDeclare()

local dropMap = {}
-- adapter: AddLoot AddRandomLoot, AddRandomHauntedLoot, AddChanceLoot, AddIfNotChanceLoot
for i = 1, #arkItemDeclare do
    local item = arkItemDeclare[i]
    if item.drop then
        for j = 1, #item.drop do
            local drop = item.drop[j]
            if not dropMap[drop.prefab] then
                dropMap[drop.prefab] = {}
            end
            table.insert(dropMap[drop.prefab], {
                prefab = item.prefab,
                adapter = drop.adapter or 'AddChanceLoot',
                value = drop.value or 1
            })
        end
    end
end

AddComponentPostInit("lootdropper", function(self)
    function self:AddLoot(prefab, num)
        if not self.loot then
            self.loot = {}
        end
        for i = 1, num do
            table.insert(self.loot, prefab)
        end
    end
end)

for k, v in pairs(dropMap) do
    AddPrefabPostInit(k, function(inst)
        for i = 1, #v do
          local adapter = inst.components.lootdropper and inst.components.lootdropper[v[i].adapter]
          if adapter then
            adapter(inst.components.lootdropper, v[i].prefab, v[i].value)
          end
        end
    end)
end
